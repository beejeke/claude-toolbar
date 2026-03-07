import Foundation

// MARK: - Errors

enum ClaudeAPIError: LocalizedError {
    case missingSessionKey
    case noOrganization
    case unauthorized
    case forbidden
    case noUsageData
    case httpError(Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .missingSessionKey:    return "Session key no configurada"
        case .noOrganization:       return "No se encontro ninguna organizacion"
        case .unauthorized:         return "Session key invalida o expirada"
        case .forbidden:            return "Acceso denegado por la API"
        case .noUsageData:          return "No hay datos de uso disponibles"
        case .httpError(let code):  return "Error HTTP \(code)"
        case .decodingError(let m): return "Error de decodificacion: \(m)"
        }
    }
}

// MARK: - Service

actor ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let baseURL = "https://claude.ai"
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: Public API

    func fetchUsageData(sessionKey: String) async throws -> ClaudeUsageData {
        guard !sessionKey.isEmpty else { throw ClaudeAPIError.missingSessionKey }

        let orgs = try await fetchOrganizations(sessionKey: sessionKey)
        guard let org = orgs.first else { throw ClaudeAPIError.noOrganization }

        return try await fetchUsage(orgId: org.id, sessionKey: sessionKey)
    }

    // MARK: Private

    private func fetchOrganizations(sessionKey: String) async throws -> [Organization] {
        let url = try makeURL("/api/organizations")
        let data = try await request(url: url, sessionKey: sessionKey)
        return try decode([Organization].self, from: data)
    }

    private func fetchUsage(orgId: String, sessionKey: String) async throws -> ClaudeUsageData {
        // Intentamos el endpoint principal de usage
        if let data = try? await request(url: try makeURL("/api/organizations/\(orgId)/usage"),
                                         sessionKey: sessionKey),
           let response = try? decode(UsageResponse.self, from: data),
           let parsed = parseUsageResponse(response) {
            return parsed
        }

        // Fallback: endpoint de limits
        if let data = try? await request(url: try makeURL("/api/organizations/\(orgId)/limits"),
                                         sessionKey: sessionKey),
           let response = try? decode(LimitsResponse.self, from: data),
           let parsed = parseLimitsResponse(response) {
            return parsed
        }

        throw ClaudeAPIError.noUsageData
    }

    // MARK: Response Parsing

    private func parseUsageResponse(_ response: UsageResponse) -> ClaudeUsageData? {
        guard let ml = response.messageLimit else { return nil }

        let used = ml.used ?? (ml.limit.map { $0 - (ml.remaining ?? 0) } ?? 0)
        let limit = ml.limit ?? 100
        let resetDate = parseDate(ml.resetAt)
        let metric = UsageMetric(used: used, limit: limit, resetAt: resetDate)

        let isWeekly = ml.windowDuration?.lowercased().contains("week") == true
                    || ml.type?.lowercased().contains("week") == true

        return ClaudeUsageData(
            sessionUsage: isWeekly ? nil : metric,
            weeklyUsage: isWeekly ? metric : nil
        )
    }

    private func parseLimitsResponse(_ response: LimitsResponse) -> ClaudeUsageData? {
        guard let limits = response.limits, !limits.isEmpty else { return nil }

        var sessionMetric: UsageMetric?
        var weeklyMetric: UsageMetric?

        for entry in limits {
            let used = entry.used ?? 0
            let limit = entry.limit ?? 100
            let resetDate = parseDate(entry.resetAt)
            let metric = UsageMetric(used: used, limit: limit, resetAt: resetDate)

            let isWeekly = entry.type?.lowercased().contains("week") == true
            if isWeekly {
                weeklyMetric = metric
            } else {
                sessionMetric = metric
            }
        }

        guard sessionMetric != nil || weeklyMetric != nil else { return nil }
        return ClaudeUsageData(sessionUsage: sessionMetric, weeklyUsage: weeklyMetric)
    }

    // MARK: Helpers

    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else {
            throw ClaudeAPIError.httpError(0)
        }
        return url
    }

    private func request(url: URL, sessionKey: String) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        req.setValue("web", forHTTPHeaderField: "anthropic-client-type")
        req.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeAPIError.httpError(0)
        }

        switch http.statusCode {
        case 200...299: return data
        case 401: throw ClaudeAPIError.unauthorized
        case 403: throw ClaudeAPIError.forbidden
        default: throw ClaudeAPIError.httpError(http.statusCode)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw ClaudeAPIError.decodingError(error.localizedDescription)
        }
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: string) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: string)
    }
}
