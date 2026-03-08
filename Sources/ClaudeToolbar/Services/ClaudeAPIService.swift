import Foundation

// MARK: - Service

/// Lee los archivos .jsonl de ~/.claude/projects/ para extraer uso de tokens del CLI de Claude Code.
/// No requiere autenticacion ni permisos especiales — son archivos locales del usuario.
actor CLIUsageService {
    static let shared = CLIUsageService()

    func fetchUsageData() async -> CLIUsageData {
        let entries = readAllEntries()
        guard !entries.isEmpty else {
            return CLIUsageData(currentSession: nil, todayTotal: nil, weekTotal: nil,
                                dailyHistory: [], sessionTokensPerHour: nil, rateLimitInfo: nil)
        }

        let now = Date.now
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        let startOfWeek  = cal.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday

        // Sesion actual: bloque de actividad continua mas reciente.
        // Se considera "nueva sesion" cuando hay un gap > 30 min entre mensajes consecutivos.
        let sessionBlock  = currentActivityBlock(from: entries)
        let currentSession = sessionBlock.map { aggregate($0) }

        // Burn rate: tokens/hora de la sesión activa.
        // Solo se calcula si la última actividad fue hace < 30 min y hay al menos 5 min de datos.
        let sessionTokensPerHour: Double? = sessionBlock.flatMap { block -> Double? in
            let timestamps = block.compactMap(\.timestamp)
            guard let first = timestamps.min(),
                  let last  = timestamps.max(),
                  now.timeIntervalSince(last) < 30 * 60   // sesion activa
            else { return nil }
            let elapsedHours = last.timeIntervalSince(first) / 3600
            guard elapsedHours >= 5.0 / 60.0 else { return nil }  // mínimo 5 min de datos
            let outputTokens = block.reduce(0) { $0 + $1.outputTokens }
            return Double(outputTokens) / elapsedHours
        }

        let todayEntries = entries.filter { ($0.timestamp ?? .distantPast) >= startOfToday }
        let weekEntries  = entries.filter { ($0.timestamp ?? .distantPast) >= startOfWeek }

        // Historial diario: últimos 7 días calendario, orden ascendente
        let emptyUsage = PeriodUsage(
            inputTokens: 0, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0,
            messageCount: 0, sessionCount: 0, model: nil, startTime: nil, lastActivity: nil
        )
        let dailyHistory: [DailyUsage] = (0..<7).map { offset in
            let dayStart = cal.date(byAdding: .day, value: -(6 - offset), to: startOfToday) ?? startOfToday
            let dayEnd   = cal.date(byAdding: .day, value: 1, to: dayStart) ?? startOfToday
            let dayEntries = entries.filter {
                guard let ts = $0.timestamp else { return false }
                return ts >= dayStart && ts < dayEnd
            }
            return DailyUsage(date: dayStart, usage: dayEntries.isEmpty ? emptyUsage : aggregate(dayEntries))
        }

        return CLIUsageData(
            currentSession:       currentSession,
            todayTotal:           todayEntries.isEmpty ? nil : aggregate(todayEntries),
            weekTotal:            weekEntries.isEmpty  ? nil : aggregate(weekEntries),
            dailyHistory:         dailyHistory,
            sessionTokensPerHour: sessionTokensPerHour,
            rateLimitInfo:        readLatestRateLimitInfo()
        )
    }

    // MARK: - Private types

    private struct Entry: Sendable {
        let sessionId: String
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationTokens: Int
        let cacheReadTokens: Int
        let model: String?
        let timestamp: Date?
    }

    // MARK: - Parsing

    private func readAllEntries() -> [Entry] {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        guard let enumerator = FileManager.default.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var entries: [Entry] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            entries += parseJSONL(at: url, iso: iso)
        }
        return entries
    }

    private func parseJSONL(at url: URL, iso: ISO8601DateFormatter) -> [Entry] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        var entries: [Entry] = []
        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard
                let data    = line.data(using: .utf8),
                let obj     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                obj["type"] as? String == "assistant",
                let sid     = obj["sessionId"] as? String,
                let message = obj["message"] as? [String: Any],
                let usage   = message["usage"] as? [String: Any]
            else { continue }

            let ts    = (obj["timestamp"] as? String).flatMap { iso.date(from: $0) }
            let model = message["model"] as? String

            entries.append(Entry(
                sessionId:           sid,
                inputTokens:         usage["input_tokens"]                as? Int ?? 0,
                outputTokens:        usage["output_tokens"]               as? Int ?? 0,
                cacheCreationTokens: usage["cache_creation_input_tokens"] as? Int ?? 0,
                cacheReadTokens:     usage["cache_read_input_tokens"]     as? Int ?? 0,
                model:     model,
                timestamp: ts
            ))
        }
        return entries
    }

    // MARK: - Session detection

    /// Devuelve las entradas del sessionId mas reciente (por ultimo timestamp).
    /// Cada vez que el usuario hace `exit` y relanza Claude CLI se genera un nuevo sessionId.
    private func currentActivityBlock(from entries: [Entry]) -> [Entry]? {
        let withTimestamp = entries.filter { $0.timestamp != nil }
        guard !withTimestamp.isEmpty else { return nil }

        // Agrupar por sessionId y encontrar el que tiene el timestamp mas reciente
        var latestTime: Date = .distantPast
        var latestSessionId: String = ""

        for entry in withTimestamp {
            if entry.timestamp! > latestTime {
                latestTime = entry.timestamp!
                latestSessionId = entry.sessionId
            }
        }

        let block = withTimestamp.filter { $0.sessionId == latestSessionId }
        return block.isEmpty ? nil : block
    }

    // MARK: - Rate limit detection

    /// Escanea todos los JSONL buscando el entry de rate_limit más reciente.
    private func readLatestRateLimitInfo() -> RateLimitInfo? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        guard let enumerator = FileManager.default.enumerator(
            at: projectsDir, includingPropertiesForKeys: nil
        ) else { return nil }

        var latest: RateLimitInfo? = nil

        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                guard
                    let data = line.data(using: .utf8),
                    let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    obj["error"] as? String == "rate_limit",
                    let tsStr   = obj["timestamp"] as? String,
                    let hitAt   = iso.date(from: tsStr),
                    let message = obj["message"] as? [String: Any],
                    let content = message["content"] as? [[String: Any]],
                    let text    = content.first?["text"] as? String,
                    let range   = text.range(of: "resets ")
                else { continue }

                let resetText = String(text[range.upperBound...])
                let info = RateLimitInfo(hitAt: hitAt, resetText: resetText)
                if latest == nil || hitAt > latest!.hitAt { latest = info }
            }
        }
        return latest
    }

    // MARK: - Aggregation

    private func aggregate(_ entries: [Entry]) -> PeriodUsage {
        let sessionCount = Set(entries.map(\.sessionId)).count
        let timestamps   = entries.compactMap(\.timestamp)
        // Modelo predominante (el mas frecuente)
        let model = entries.compactMap(\.model)
            .reduce(into: [:]) { counts, m in counts[m, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?.key

        return PeriodUsage(
            inputTokens:         entries.reduce(0) { $0 + $1.inputTokens },
            outputTokens:        entries.reduce(0) { $0 + $1.outputTokens },
            cacheCreationTokens: entries.reduce(0) { $0 + $1.cacheCreationTokens },
            cacheReadTokens:     entries.reduce(0) { $0 + $1.cacheReadTokens },
            messageCount:        entries.count,
            sessionCount:        sessionCount,
            model:               model,
            startTime:           timestamps.min(),
            lastActivity:        timestamps.max()
        )
    }
}
