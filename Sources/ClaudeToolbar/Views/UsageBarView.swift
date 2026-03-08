import SwiftUI
import Foundation

/// Tarjeta de uso de tokens para un periodo.
/// Muestra tokens reales (input + output, sin cache_read),
/// barra de progreso respecto a un limite, y coste de referencia API.
struct UsageCardView: View {
    @EnvironmentObject private var lm: LocalizationManager

    let title: String
    let icon: String
    let usage: PeriodUsage?
    let color: Color
    /// Limite de output_tokens para calcular el porcentaje. nil = no muestra barra.
    let outputLimit: Int?
    /// Burn rate de la sesión activa. nil = no muestra predicción.
    var burnRate: BurnRate? = nil
    /// Total del día (para mostrar como referencia bajo la ventana de 5h). nil = no mostrar.
    var todayTotal: PeriodUsage? = nil
    /// true = el límite fue calibrado automáticamente desde datos de rate limit reales.
    var isCalibrated: Bool = false

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
                if let today = todayTotal {
                    todayNoteRow(today)
                }
                footerRow(usage)
            } else {
                Text(lm.s(.noActivity))
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
            VStack(alignment: .leading, spacing: 1) {
                Text(u.formattedOutputTokens)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(lm.s(.tokensGenerated))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(u.formattedCost)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(lm.s(.refAPI))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func progressRow(_ u: PeriodUsage, limit: Int) -> some View {
        let pct = u.percentOfLimit(limit)
        let usedTokens = u.formattedRealTokens   // realTokens para coincidir con la métrica del límite
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
                Text("\(Int(pct * 100))% \(lm.s(.percentOfLimit))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(colorForPercent(pct))
                if isCalibrated {
                    Text(lm.s(.calibrated))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.green.opacity(0.12), in: Capsule())
                }
                Spacer()
                Text("\(usedTokens) / \(limitStr) \(lm.s(.tok))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func burnRateRow(_ br: BurnRate) -> some View {
        let accent: Color = br.isWindowWarning ? .red : .orange
        return HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 9))
                .foregroundStyle(accent)
            Text(br.formattedRate)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
            Spacer()
            if let timeLeft = br.formattedTimeToWindow {
                Text("\(lm.s(.windowIn)) \(timeLeft)")
                    .font(.system(size: 10))
                    .foregroundStyle(br.isWindowWarning ? Color.red : Color.secondary)
            } else {
                Text(lm.s(.windowExhausted))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
    }

    private func todayNoteRow(_ today: PeriodUsage) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text("\(lm.s(.todayTotal)): \(formatTokens(today.outputTokens)) \(lm.s(.todayTokensGenerated))")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private func footerRow(_ u: PeriodUsage) -> some View {
        HStack(spacing: 10) {
            pill("\(u.messageCount)", icon: "arrow.right.circle.fill", label: lm.s(.calls))
            if u.sessionCount > 1 {
                pill("\(u.sessionCount)", icon: "folder.fill", label: lm.s(.sessions))
            }
            if let model = u.model {
                pill(shortModel(model), icon: "cpu", label: nil)
            }
            Spacer()
            Text("\(formatTokens(u.realTokens)) \(lm.s(.real))")
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
