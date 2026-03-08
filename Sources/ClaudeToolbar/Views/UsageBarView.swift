import SwiftUI

/// Tarjeta de uso de tokens para un periodo.
/// Muestra tokens reales (input + output, sin cache_read),
/// barra de progreso respecto a un limite, y coste de referencia API.
struct UsageCardView: View {
    let title: String
    let icon: String
    let usage: PeriodUsage?
    let color: Color
    /// Limite de output_tokens para calcular el porcentaje. nil = no muestra barra.
    let outputLimit: Int?
    /// Burn rate de la sesión activa. nil = no muestra predicción.
    var burnRate: BurnRate? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            if let usage {
                metricsRow(usage)
                if let limit = outputLimit {
                    progressRow(usage, limit: limit)
                }
                if let br = burnRate {
                    burnRateRow(br)
                }
                footerRow(usage)
            } else {
                Text("Sin actividad")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Subviews

    private var headerRow: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            if let last = usage?.relativeLastActivity {
                Text(last)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func metricsRow(_ u: PeriodUsage) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            // Output tokens (lo que Claude genero — metrica principal)
            VStack(alignment: .leading, spacing: 1) {
                Text(u.formattedOutputTokens)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("tokens generados")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            // Coste API referencia (no es lo que paga el suscriptor)
            VStack(alignment: .trailing, spacing: 1) {
                Text(u.formattedCost)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("ref. API")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func progressRow(_ u: PeriodUsage, limit: Int) -> some View {
        let pct = u.percentOfLimit(limit)
        let usedTokens = u.formattedOutputTokens
        let limitStr   = formatTokens(limit)

        return VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barGradient(pct: pct))
                        .frame(width: max(4, geo.size.width * pct), height: 6)
                        .animation(.easeInOut(duration: 0.5), value: pct)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(Int(pct * 100))% del límite")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(colorForPercent(pct))
                Spacer()
                Text("\(usedTokens) / \(limitStr) tok")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func burnRateRow(_ br: BurnRate) -> some View {
        let accent: Color = br.isDailyWarning ? .red : .orange
        return HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 9))
                .foregroundStyle(accent)
            Text(br.formattedRate)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
            Spacer()
            if let timeLeft = br.formattedTimeToDaily {
                Text("límite en \(timeLeft)")
                    .font(.system(size: 10))
                    .foregroundStyle(br.isDailyWarning ? Color.red : Color.secondary)
            } else {
                Text("límite superado")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
    }

    private func footerRow(_ u: PeriodUsage) -> some View {
        HStack(spacing: 10) {
            pill("\(u.messageCount)", icon: "arrow.right.circle.fill", label: "llamadas")
            if u.sessionCount > 1 {
                pill("\(u.sessionCount)", icon: "folder.fill", label: "sesiones")
            }
            if let model = u.model {
                pill(shortModel(model), icon: "cpu", label: nil)
            }
            Spacer()
            // Tokens totales reales (in + out, sin cache)
            Text("\(formatTokens(u.realTokens)) reales")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
    }

    private func pill(_ value: String, icon: String, label: String?) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 8)).foregroundStyle(.tertiary)
            Text(label.map { "\(value) \($0)" } ?? value)
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }

    // MARK: Helpers

    private func barGradient(pct: Double) -> LinearGradient {
        let c = colorForPercent(pct)
        return LinearGradient(colors: [c.opacity(0.6), c], startPoint: .leading, endPoint: .trailing)
    }

    private func colorForPercent(_ p: Double) -> Color {
        switch p {
        case ..<0.5: return color
        case ..<0.8: return .orange
        default:     return .red
        }
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func shortModel(_ m: String) -> String {
        if m.contains("opus")   { return "Opus" }
        if m.contains("sonnet") { return "Sonnet" }
        if m.contains("haiku")  { return "Haiku" }
        return m
    }
}
