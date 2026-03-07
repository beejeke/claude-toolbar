import SwiftUI

struct UsageBarView: View {
    let title: String
    let icon: String
    let metric: UsageMetric?
    let color: Color

    private var remaining: Double { metric?.remainingPercentage ?? 0 }
    private var used: Double { metric?.percentage ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            titleRow
            progressBar
            infoRow
        }
        .padding(.vertical, 4)
    }

    // MARK: Subviews

    private var titleRow: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            percentageTag
        }
    }

    private var percentageTag: some View {
        Text("\(Int(remaining * 100))% restante")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(tagForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tagBackground)
            .clipShape(Capsule())
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 5)
                    .fill(.quaternary)
                    .frame(height: 10)

                // Fill
                RoundedRectangle(cornerRadius: 5)
                    .fill(barGradient)
                    .frame(width: max(0, geo.size.width * remaining), height: 10)
                    .animation(.easeInOut(duration: 0.6), value: remaining)
            }
        }
        .frame(height: 10)
    }

    private var infoRow: some View {
        HStack {
            if let metric {
                HStack(spacing: 3) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(metric.remaining) de \(metric.limit) mensajes")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Sin datos de uso")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let reset = metric?.timeUntilReset {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("Restaura en \(reset)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Computed colors

    private var barGradient: LinearGradient {
        let base = colorForPercentage(remaining)
        return LinearGradient(
            colors: [base.opacity(0.7), base],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var tagForeground: Color {
        colorForPercentage(remaining)
    }

    private var tagBackground: some ShapeStyle {
        colorForPercentage(remaining).opacity(0.15)
    }

    private func colorForPercentage(_ pct: Double) -> Color {
        switch pct {
        case 0.5...: return color
        case 0.2..<0.5: return .orange
        default: return .red
        }
    }
}

