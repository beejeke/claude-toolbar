import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: UsageViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            if showSettings {
                SettingsView()
                    .environmentObject(viewModel)
                    .transition(.opacity)
            } else {
                scrollContent
                    .transition(.opacity)
            }
        }
        .frame(width: 340)
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.easeInOut(duration: 0.15), value: showSettings)
    }

    // MARK: Header

    private var headerView: some View {
        HStack(spacing: 8) {
            ClaudeLogoView(size: 18, color: .orange)
            Text("Claude Code").font(.system(size: 14, weight: .semibold))
            planBadge
            Spacer()

            if !showSettings {
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
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showSettings.toggle() }
            } label: {
                Image(systemName: showSettings ? "xmark.circle.fill" : "gearshape.fill")
                    .font(.system(size: showSettings ? 14 : 12))
                    .foregroundStyle(showSettings ? Color.secondary : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(showSettings ? "Cerrar ajustes" : "Ajustes")

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain).help("Salir")
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var planBadge: some View {
        Text(viewModel.subscriptionPlan.displayName)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.12), in: Capsule())
            .help("Plan detectado desde Keychain · Límites: \(viewModel.dailyOutputLimit / 1000)K/día, \(viewModel.weeklyOutputLimit / 1000)K/semana")
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

                // Hoy — con barra de % del limite diario + burn rate
                UsageCardView(title: "Hoy", icon: "sun.max.fill",
                              usage: viewModel.todayTotal, color: .orange,
                              outputLimit: viewModel.dailyOutputLimit,
                              burnRate: viewModel.burnRate)

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
