import Foundation

// MARK: - Service

/// Lee los archivos .jsonl de ~/.claude/projects/ para extraer uso de tokens del CLI de Claude Code.
/// No requiere autenticacion ni permisos especiales — son archivos locales del usuario.
actor CLIUsageService {
    static let shared = CLIUsageService()

    func fetchUsageData() async -> CLIUsageData {
        let entries = readAllEntries()
        guard !entries.isEmpty else {
            return CLIUsageData(currentSession: nil, todayTotal: nil, weekTotal: nil)
        }

        let now = Date.now
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        let startOfWeek  = cal.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday

        // Sesion actual: el sessionId mas reciente (por ultimo timestamp)
        let bySession = Dictionary(grouping: entries) { $0.sessionId }
        let mostRecentSession = bySession.max {
            ($0.value.compactMap(\.timestamp).max() ?? .distantPast) <
            ($1.value.compactMap(\.timestamp).max() ?? .distantPast)
        }
        let currentSession = mostRecentSession.map { aggregate($0.value) }

        let todayEntries = entries.filter { ($0.timestamp ?? .distantPast) >= startOfToday }
        let weekEntries  = entries.filter { ($0.timestamp ?? .distantPast) >= startOfWeek }

        return CLIUsageData(
            currentSession: currentSession,
            todayTotal:     todayEntries.isEmpty ? nil : aggregate(todayEntries),
            weekTotal:      weekEntries.isEmpty  ? nil : aggregate(weekEntries)
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
