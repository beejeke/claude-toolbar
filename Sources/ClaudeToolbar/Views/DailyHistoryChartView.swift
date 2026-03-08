import SwiftUI

struct DailyHistoryChartView: View {
    let days: [DailyUsage]
    @State private var selectedIndex: Int? = nil

    private var maxOutput: Int {
        max(1, days.map(\.usage.outputTokens).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow
            barsRow
        }
    }

    private var titleRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 11))
                .foregroundStyle(.purple)
            Text("Historial diario")
                .font(.system(size: 11, weight: .semibold))
            Spacer()
            if let i = selectedIndex {
                selectedLabel(for: days[i])
            }
        }
    }

    private func selectedLabel(for day: DailyUsage) -> some View {
        let tokens = day.usage.formattedOutputTokens
        let cost   = day.usage.formattedCost
        let text   = day.usage.outputTokens > 0 ? "\(tokens) · \(cost)" : "sin actividad"
        return Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .transition(.opacity)
    }

    private var barsRow: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                BarColumnView(
                    day: day,
                    heightFraction: Double(day.usage.outputTokens) / Double(maxOutput),
                    isSelected: selectedIndex == index,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedIndex = selectedIndex == index ? nil : index
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Bar Column

private struct BarColumnView: View {
    let day: DailyUsage
    let heightFraction: Double
    let isSelected: Bool
    let onTap: () -> Void

    private static let maxBarHeight: CGFloat = 48
    private static let minBarHeight: CGFloat = 2

    private var barHeight: CGFloat {
        heightFraction > 0
            ? max(Self.minBarHeight, Self.maxBarHeight * heightFraction)
            : Self.minBarHeight
    }

    private var barColor: Color {
        if isSelected { return .purple }
        if day.isToday { return .purple.opacity(0.75) }
        return .purple.opacity(0.35)
    }

    private var labelColor: Color {
        isSelected || day.isToday ? .primary : .secondary
    }

    private var tooltip: String {
        if day.usage.outputTokens > 0 {
            return "\(day.dayLabel): \(day.usage.formattedOutputTokens) tokens · \(day.usage.formattedCost)"
        }
        return "\(day.dayLabel): sin actividad"
    }

    var body: some View {
        VStack(spacing: 2) {
            VStack {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(height: barHeight)
                    .animation(.easeInOut(duration: 0.3), value: barHeight)
            }
            .frame(height: BarColumnView.maxBarHeight)

            Text(day.dayLabel)
                .font(.system(size: 9))
                .foregroundStyle(labelColor)
                .fontWeight(day.isToday ? .semibold : .regular)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .help(tooltip)
    }
}
