import SwiftUI

@main
struct ClaudeToolbarApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Icono del menu bar con indicador de color segun disponibilidad restante
struct MenuBarLabel: View {
    @ObservedObject var viewModel: UsageViewModel

    private var indicatorColor: Color {
        let minPct = [viewModel.sessionUsage?.remainingPercentage,
                      viewModel.weeklyUsage?.remainingPercentage]
            .compactMap { $0 }
            .min() ?? 1.0

        switch minPct {
        case 0.5...: return .green
        case 0.2..<0.5: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ClaudeLogoView(size: 16, color: .primary)
            Circle()
                .fill(indicatorColor)
                .frame(width: 6, height: 6)
        }
    }
}
