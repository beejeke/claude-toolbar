import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: UsageViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            scrollContent
        }
        .frame(width: 340)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: Header

    private var headerView: some View {
        HStack(spacing: 8) {
            ClaudeLogoView(size: 18, color: .orange)
            Text("Claude Code").font(.system(size: 14, weight: .semibold))
            Spacer()

            if viewModel.isLoading {
                ProgressView().scaleEffect(0.7).frame(width: 16, height: 16)
            } else {
                Button { viewModel.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).help("Actualizar (Cmd+R)")
                .keyboardShortcut("r", modifiers: .command)
            }

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain).help("Salir")
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: Content

    private var scrollContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // Sesion actual (sin barra de %, la sesion puede ser larga y span multiples dias)
                UsageCardView(title: "Sesión actual", icon: "clock.fill",
                              usage: viewModel.currentSession, color: .blue,
                              outputLimit: nil)

                Divider()

                // Hoy — con barra de % del limite diario
                UsageCardView(title: "Hoy", icon: "sun.max.fill",
                              usage: viewModel.todayTotal, color: .orange,
                              outputLimit: viewModel.dailyOutputLimit)

                Divider()

                // Semana — con barra de % del limite semanal
                UsageCardView(title: "Últimos 7 días", icon: "calendar",
                              usage: viewModel.weekTotal, color: .purple,
                              outputLimit: viewModel.weeklyOutputLimit)

                if !viewModel.dailyHistory.isEmpty {
                    Divider()
                    DailyHistoryChartView(days: viewModel.dailyHistory)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if viewModel.currentSession == nil && !viewModel.isLoading {
                noDataView
            }

            Divider()
            bottomBar
        }
    }

    private var noDataView: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal").font(.system(size: 11)).foregroundStyle(.secondary)
            Text("Ejecuta `claude` en la terminal para ver tu uso")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private var bottomBar: some View {
        HStack {
            // Nota sobre coste de referencia
            Text("Ref. API: precios Anthropic públicos")
                .font(.system(size: 9)).foregroundStyle(.quaternary)
            Spacer()
            if let lastUpdated = viewModel.lastUpdated {
                Text("Actualizado \(lastUpdated, style: .relative)")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }
}
