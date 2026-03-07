import Foundation

// MARK: - Errors

enum ClaudeAPIError: LocalizedError {
    case noClaudeTabInSafari
    case notLoggedIn
    case noOrganization
    case noUsageData
    case httpError(Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .noClaudeTabInSafari: return "Abre claude.ai en Safari para ver tus datos"
        case .notLoggedIn:         return "No has iniciado sesion en claude.ai"
        case .noOrganization:      return "No se encontro ninguna organizacion"
        case .noUsageData:         return "No hay datos de uso disponibles"
        case .httpError(let c):    return "Error HTTP \(c)"
        case .decodingError(let m): return "Error de datos: \(m)"
        }
    }
}

// MARK: - Service

/// Obtiene datos de la API de claude.ai abriendo un tab temporal en Safari
/// (sin necesitar "Allow JavaScript from Apple Events").
/// El tab se abre, carga el JSON y se cierra en ~1 segundo.
actor ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: Public

    func fetchUsageData() async throws -> ClaudeUsageData {
        let orgs = try await fetch("/api/organizations", as: [Organization].self)

        // Preferir la org con claude_pro; si no, la primera con chat
        let org = orgs.first(where: { $0.capabilities?.contains("claude_pro") == true })
                ?? orgs.first(where: { $0.capabilities?.contains("chat") == true })
                ?? orgs.first
        guard let org else { throw ClaudeAPIError.noOrganization }

        if let data = try? await fetch("/api/organizations/\(org.uuid)/usage", as: UsageResponse.self),
           let parsed = parseUsageResponse(data) {
            return parsed
        }
        if let data = try? await fetch("/api/organizations/\(org.uuid)/limits", as: LimitsResponse.self),
           let parsed = parseLimitsResponse(data) {
            return parsed
        }
        throw ClaudeAPIError.noUsageData
    }

    func checkLoginStatus() async -> Bool {
        (try? await fetch("/api/organizations", as: [Organization].self)) != nil
    }

    // MARK: Safari tab navigation

    /// Abre un tab en la ventana de Safari que ya tiene claude.ai, navega a la
    /// URL de la API, lee el JSON y cierra el tab. No requiere permisos especiales.
    private func fetch<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        let fullURL = "https://claude.ai\(path)"

        let script = """
        tell application "Safari" without activating
            set claudeWin to missing value
            repeat with w in windows
                if visible of w then
                    repeat with t in tabs of w
                        if URL of t contains "claude.ai" then
                            set claudeWin to w
                            exit repeat
                        end if
                    end repeat
                end if
                if claudeWin is not missing value then exit repeat
            end repeat
            if claudeWin is missing value then return "NO_WINDOW"
            tell claudeWin
                set apiTab to make new tab
                set URL of apiTab to "\(fullURL)"
            end tell
            set i to 0
            repeat while i < 12
                delay 0.4
                set src to source of apiTab
                if src is not "" and src does not contain "<html" and src does not contain "<!DOCTYPE" then
                    close apiTab
                    return src
                end if
                set i to i + 1
            end repeat
            try
                close apiTab
            end try
            return "TIMEOUT"
        end tell
        """

        guard let raw = await runAppleScript(script) else {
            throw ClaudeAPIError.noClaudeTabInSafari
        }
        if raw == "NO_WINDOW" || raw == "TIMEOUT" || raw.isEmpty {
            throw ClaudeAPIError.noClaudeTabInSafari
        }
        // La API devuelve JSON directamente (no HTML)
        // Si empieza con [ o { es JSON valido
        guard raw.hasPrefix("[") || raw.hasPrefix("{") else {
            // Podria ser la pagina de login (redireccion 302)
            throw ClaudeAPIError.notLoggedIn
        }

        guard let data = raw.data(using: .utf8) else {
            throw ClaudeAPIError.decodingError("UTF-8")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ClaudeAPIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: AppleScript

    private func runAppleScript(_ source: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(returning: nil); return
                }
                let result = script.executeAndReturnError(&error)
                guard error == nil else { continuation.resume(returning: nil); return }
                continuation.resume(returning: result.stringValue)
            }
        }
    }

    // MARK: Parsing

    private func parseUsageResponse(_ r: UsageResponse) -> ClaudeUsageData? {
        guard let ml = r.messageLimit else { return nil }
        let used  = ml.used ?? ((ml.limit ?? 0) - (ml.remaining ?? 0))
        let limit = ml.limit ?? 100
        let metric = UsageMetric(used: used, limit: limit, resetAt: parseDate(ml.resetAt))
        let isWeekly = ml.windowDuration?.lowercased().contains("week") == true
                    || ml.type?.lowercased().contains("week") == true
        return ClaudeUsageData(sessionUsage: isWeekly ? nil : metric,
                               weeklyUsage:  isWeekly ? metric : nil)
    }

    private func parseLimitsResponse(_ r: LimitsResponse) -> ClaudeUsageData? {
        guard let limits = r.limits, !limits.isEmpty else { return nil }
        var session: UsageMetric?, weekly: UsageMetric?
        for e in limits {
            let m = UsageMetric(used: e.used ?? 0, limit: e.limit ?? 100, resetAt: parseDate(e.resetAt))
            if e.type?.lowercased().contains("week") == true { weekly = m } else { session = m }
        }
        guard session != nil || weekly != nil else { return nil }
        return ClaudeUsageData(sessionUsage: session, weeklyUsage: weekly)
    }

    private func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: s)
    }
}
