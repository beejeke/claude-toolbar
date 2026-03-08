import Foundation

// MARK: - Domain Models

/// Resumen de uso real de tokens para un periodo (sesion, hoy, semana).
/// Solo se cuentan input + output como "tokens reales" —
/// cache_read son reutilizaciones del mismo contexto cacheado, no trabajo nuevo.
struct PeriodUsage: Sendable {
    // Tokens reales (lo que Claude leyó y generó)
    let inputTokens: Int
    let outputTokens: Int
    // Cache (para calculo de coste, no para display principal)
    let cacheCreationTokens: Int
    let cacheReadTokens: Int

    let messageCount: Int
    let sessionCount: Int
    let model: String?
    let startTime: Date?
    let lastActivity: Date?

    /// Tokens "reales": input + output (excluye cache_read que es reutilizacion de contexto)
    var realTokens: Int { inputTokens + outputTokens }

    /// Coste de referencia API (no es lo que paga el suscriptor, es precio publico Anthropic)
    var apiRefCostUSD: Double {
        let p = ModelPricing.for(model ?? "claude-sonnet-4-6")
        return Double(inputTokens)         * p.inputPerToken
             + Double(outputTokens)        * p.outputPerToken
             + Double(cacheCreationTokens) * p.cacheCreatePerToken
             + Double(cacheReadTokens)     * p.cacheReadPerToken
    }

    func percentOfLimit(_ limit: Int) -> Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(outputTokens) / Double(limit))
    }

    var formattedRealTokens: String {
        formatTokens(realTokens)
    }

    var formattedOutputTokens: String {
        formatTokens(outputTokens)
    }

    var formattedCost: String {
        if apiRefCostUSD < 0.001 { return "<$0.001" }
        return String(format: "$%.2f", apiRefCostUSD)
    }

    var relativeLastActivity: String? {
        guard let last = lastActivity else { return nil }
        let diff = Date.now.timeIntervalSince(last)
        if diff < 60    { return "ahora mismo" }
        if diff < 3600  { return "hace \(Int(diff / 60))m" }
        if diff < 86400 { return "hace \(Int(diff / 3600))h" }
        return "hace \(Int(diff / 86400))d"
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

struct CLIUsageData: Sendable {
    let currentSession: PeriodUsage?
    let todayTotal: PeriodUsage?
    let weekTotal: PeriodUsage?
    let dailyHistory: [DailyUsage]  // últimos 7 días, orden ascendente (index 0 = más antiguo)
    /// Velocidad de la sesión activa (nil si sesión inactiva o < 5 min de datos).
    let sessionTokensPerHour: Double?
}

// MARK: - Burn Rate

struct BurnRate: Sendable {
    let tokensPerHour: Double
    /// Horas hasta agotar el límite diario. nil = límite ya superado.
    let hoursToDaily: Double?
    /// Horas hasta agotar el límite semanal. nil = límite ya superado.
    let hoursToWeekly: Double?

    /// Alerta si el límite diario se alcanza en menos de 2 horas.
    var isDailyWarning: Bool {
        guard let h = hoursToDaily else { return false }
        return h < 2
    }

    var formattedRate: String {
        let t = Int(tokensPerHour)
        if t >= 1_000 { return String(format: "%.1fK/h", Double(t) / 1_000) }
        return "\(t)/h"
    }

    var formattedTimeToDaily: String? {
        guard let h = hoursToDaily, h > 0 else { return nil }
        return formatHours(h)
    }

    var formattedTimeToWeekly: String? {
        guard let h = hoursToWeekly, h > 0 else { return nil }
        return formatHours(h)
    }

    private func formatHours(_ h: Double) -> String {
        let totalMin = Int(h * 60)
        if totalMin < 60 { return "~\(totalMin)m" }
        let hrs  = totalMin / 60
        let mins = totalMin % 60
        return mins > 0 ? "~\(hrs)h \(mins)m" : "~\(hrs)h"
    }
}

// MARK: - Daily History

struct DailyUsage: Sendable, Identifiable {
    let date: Date          // inicio del día (startOfDay)
    let usage: PeriodUsage

    var id: TimeInterval { date.timeIntervalSince1970 }

    var dayLabel: String {
        DailyUsage.dayFormatter.string(from: date)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
}

// MARK: - Subscription Plan

enum SubscriptionPlan: Sendable {
    case pro
    case max5
    case max20

    /// Inicializa desde los campos del Keychain `Claude Code-credentials`.
    init(subscriptionType: String, rateLimitTier: String) {
        let sub  = subscriptionType.lowercased()
        let tier = rateLimitTier.lowercased()
        if sub.contains("max_20") || sub.contains("max20") || tier.contains("max_20") {
            self = .max20
        } else if sub.contains("max_5") || sub.contains("max5") || tier.contains("max_5") {
            self = .max5
        } else {
            self = .pro
        }
    }

    var displayName: String {
        switch self {
        case .pro:   return "Pro"
        case .max5:  return "Max 5×"
        case .max20: return "Max 20×"
        }
    }

    /// Límite diario de output tokens aproximado según el plan.
    var defaultDailyOutputLimit: Int {
        switch self {
        case .pro:   return 150_000
        case .max5:  return 375_000
        case .max20: return 750_000
        }
    }

    /// Límite semanal de output tokens aproximado según el plan.
    var defaultWeeklyOutputLimit: Int {
        switch self {
        case .pro:   return 750_000
        case .max5:  return 1_875_000
        case .max20: return 3_750_000
        }
    }
}

// MARK: - Model Pricing (USD por token, precios publicos API de Anthropic)

struct ModelPricing {
    let inputPerToken: Double
    let outputPerToken: Double
    let cacheCreatePerToken: Double
    let cacheReadPerToken: Double

    static func `for`(_ model: String) -> ModelPricing {
        if model.contains("opus") {
            return ModelPricing(inputPerToken: 15/1e6,   outputPerToken: 75/1e6,
                                cacheCreatePerToken: 18.75/1e6, cacheReadPerToken: 1.5/1e6)
        } else if model.contains("haiku") {
            return ModelPricing(inputPerToken: 0.8/1e6,  outputPerToken: 4/1e6,
                                cacheCreatePerToken: 1/1e6,     cacheReadPerToken: 0.08/1e6)
        } else {
            // Sonnet (default)
            return ModelPricing(inputPerToken: 3/1e6,    outputPerToken: 15/1e6,
                                cacheCreatePerToken: 3.75/1e6,  cacheReadPerToken: 0.3/1e6)
        }
    }
}
