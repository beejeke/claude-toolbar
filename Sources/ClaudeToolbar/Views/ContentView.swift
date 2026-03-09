import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: UsageViewModel
    @EnvironmentObject private var lm: LocalizationManager
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
                    .buttonStyle(.plain).help(lm.s(.refresh))
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
            .help(showSettings ? lm.s(.settingsClose) : lm.s(.settingsOpen))

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain).help(lm.s(.quit))
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
            .help("Plan detectado desde Keychain · Ventana 5h: \(viewModel.windowOutputLimit / 1000)K, Semana: \(viewModel.weeklyOutputLimit / 1000)K")
    }

    // MARK: Content

    private var scrollContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                UsageCardView(title: lm.s(.currentSession), icon: "clock.fill",
                              usage: viewModel.currentSession, color: .blue,
                              outputLimit: nil)

                Divider()

                UsageCardView(title: lm.s(.windowFiveH), icon: "timer",
                              usage: viewModel.windowUsage, color: .orange,
                              outputLimit: viewModel.effectiveWindowLimit,
                              burnRate: viewModel.burnRate,
                              todayTotal: viewModel.todayTotal,
                              isCalibrated: viewModel.calibratedWindowLimit != nil,
                              resetTime: viewModel.windowResetTime)

                Divider()

                UsageCardView(title: lm.s(.lastSevenDays), icon: "calendar",
                              usage: viewModel.weekTotal, color: .purple,
                              outputLimit: viewModel.weeklyOutputLimit,
                              resetTime: viewModel.weeklyResetTime)

                // Solo mostrar el banner si el rate limit ocurrió en la ventana activa actual (< 5h).
                // Si pasó hace más de 5h, la ventana ya se reseteó y el dato es obsoleto.
                if let rl = viewModel.rateLimitInfo,
                   Date.now.timeIntervalSince(rl.hitAt) < 5 * 3600 {
                    Divider()
                    rateLimitBanner(rl)
                }

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

    private func rateLimitBanner(_ rl: RateLimitInfo) -> some View {
        let isToday = rl.wasHitToday
        let accent: Color = isToday ? .red : .secondary
        let hitLabel = isToday ? lm.s(.rateLimitToday) : lm.s(.rateLimitPast)
        return HStack(spacing: 6) {
            Image(systemName: isToday ? "exclamationmark.octagon.fill" : "clock.arrow.circlepath")
                .font(.system(size: 10))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(hitLabel) \(rl.relativeHitAt)")
                    .font(.system(size: 10, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(isToday ? Color.primary : Color.secondary)
                Text("\(lm.s(.rateLimitResets)) \(rl.resetText)")
                    .font(.system(size: 10))
                    .foregroundStyle(isToday ? Color.secondary : Color.primary.opacity(0.3))
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var noDataView: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal").font(.system(size: 11)).foregroundStyle(.secondary)
            Text(lm.s(.noDataMessage))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private var bottomBar: some View {
        HStack {
            Text(lm.s(.apiRefNote))
                .font(.system(size: 9)).foregroundStyle(.quaternary)
            Spacer()
            if let lastUpdated = viewModel.lastUpdated {
                Text("\(lm.s(.lastUpdated)) \(lastUpdated, style: .relative)")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }
}
