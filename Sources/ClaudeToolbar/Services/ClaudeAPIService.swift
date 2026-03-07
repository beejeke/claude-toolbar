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

/// Hace peticiones a la API de claude.ai ejecutando XHR sincrono dentro de un
/// tab de Safari que ya tiene la sesion activa. No necesita session key.
actor ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: Public

    func fetchUsageData() async throws -> ClaudeUsageData {
        let orgs = try await get("/api/organizations", as: [Organization].self)
        guard let org = orgs.first else { throw ClaudeAPIError.noOrganization }

        if let data = try? await get("/api/organizations/\(org.id)/usage", as: UsageResponse.self),
           let parsed = parseUsageResponse(data) {
            return parsed
        }
        if let data = try? await get("/api/organizations/\(org.id)/limits", as: LimitsResponse.self),
           let parsed = parseLimitsResponse(data) {
            return parsed
        }
        throw ClaudeAPIError.noUsageData
    }

    func checkLoginStatus() async -> Bool {
        (try? await get("/api/organizations", as: [Organization].self)) != nil
    }

    // MARK: XHR via Safari

    private func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        let js = "(function(){try{var x=new XMLHttpRequest();"
               + "x.open('GET','\(path)',false);"
               + "x.setRequestHeader('Accept','application/json');"
               + "x.send(null);"
               + "return ('000'+x.status.toString()).slice(-3)+x.responseText;"
               + "}catch(e){return '000ERROR'}})()"

        let script = """
        tell application "Safari"
            repeat with w in windows
                if visible of w then
                    repeat with t in tabs of w
                        if URL of t contains "claude.ai" and URL of t does not contain "/login" then
                            try
                                return do JavaScript "\(js)" in t
                            end try
                        end if
                    end repeat
                end if
            end repeat
            return ""
        end tell
        """

        guard let raw = await runAppleScript(script), raw.count > 3 else {
            throw ClaudeAPIError.noClaudeTabInSafari
        }

        let statusCode = Int(raw.prefix(3)) ?? 0
        let body = String(raw.dropFirst(3))

        switch statusCode {
        case 200...299:
            guard let data = body.data(using: .utf8) else {
                throw ClaudeAPIError.decodingError("UTF-8")
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw ClaudeAPIError.decodingError(error.localizedDescription)
            }
        case 401, 403:
            throw ClaudeAPIError.notLoggedIn
        default:
            throw ClaudeAPIError.httpError(statusCode)
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
