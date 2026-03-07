import Foundation

// MARK: - Domain Models

struct UsageMetric: Sendable {
    let used: Int
    let limit: Int
    let resetAt: Date?

    var percentage: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(used) / Double(limit))
    }

    var remainingPercentage: Double {
        max(0, 1.0 - percentage)
    }

    var remaining: Int {
        max(0, limit - used)
    }

    var timeUntilReset: String? {
        guard let resetAt else { return nil }
        let diff = resetAt.timeIntervalSince(.now)
        guard diff > 0 else { return "Disponible ahora" }

        let hours = Int(diff / 3600)
        let minutes = Int(diff.truncatingRemainder(dividingBy: 3600) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }
}

struct ClaudeUsageData: Sendable {
    let sessionUsage: UsageMetric?
    let weeklyUsage: UsageMetric?
}

// MARK: - API Response Models

struct Organization: Codable, Sendable {
    let uuid: String
    let name: String?
    let capabilities: [String]?
}

/// Respuesta de /api/organizations/{id}/usage
struct UsageResponse: Codable, Sendable {
    let messageLimit: MessageLimit?

    enum CodingKeys: String, CodingKey {
        case messageLimit = "message_limit"
    }

    struct MessageLimit: Codable, Sendable {
        let type: String?
        let remaining: Int?
        let used: Int?
        let limit: Int?
        let resetAt: String?
        let windowDuration: String?

        enum CodingKeys: String, CodingKey {
            case type
            case remaining
            case used
            case limit
            case resetAt = "reset_at"
            case windowDuration = "window_duration"
        }
    }
}

/// Respuesta alternativa de /api/organizations/{id}/limits
struct LimitsResponse: Codable, Sendable {
    let limits: [LimitEntry]?

    struct LimitEntry: Codable, Sendable {
        let type: String?
        let used: Int?
        let limit: Int?
        let resetAt: String?

        enum CodingKeys: String, CodingKey {
            case type
            case used
            case limit
            case resetAt = "reset_at"
        }
    }
}
