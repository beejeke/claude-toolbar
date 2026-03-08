import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: UsageViewModel
    @EnvironmentObject private var lm: LocalizationManager

    var body: some View {
        VStack(spacing: 0) {
            languageSection
            Divider()
            notificationsSection
            Divider()
            limitsSection
            Divider()
            aboutSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Idioma

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(lm.s(.languageLabel), icon: "globe", color: .blue)
            Picker("", selection: $lm.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Notificaciones

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(lm.s(.sectionNotifications), icon: "bell.fill", color: .blue)

            Toggle(isOn: $viewModel.notificationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lm.s(.thresholdAlerts))
                        .font(.system(size: 12, weight: .medium))
                    Text(lm.s(.thresholdDesc))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            if !viewModel.notificationsEnabled {
                Text(lm.s(.notificationsOff))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Límites

    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(lm.s(.sectionLimits), icon: "gauge.medium", color: .orange)

            if let cal = viewModel.calibratedWindowLimit {
                calibratedLimitRow(cal)
            } else {
                limitRow(
                    label: lm.s(.windowFiveHLabel),
                    value: viewModel.windowOutputLimit,
                    planDefault: viewModel.subscriptionPlan.defaultWindowOutputLimit
                )
            }
            limitRow(
                label: lm.s(.weeklyLabel),
                value: viewModel.weeklyOutputLimit,
                planDefault: viewModel.subscriptionPlan.defaultWeeklyOutputLimit
            )

            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("\(lm.s(.detectedPlan)) \(viewModel.subscriptionPlan.displayName)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(lm.s(.resetButton)) {
                    viewModel.resetLimitsToDetectedPlan()
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 12)
    }

    private func calibratedLimitRow(_ limit: Int) -> some View {
        HStack {
            Text("Ventana 5h")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(formatTokens(limit))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Text("calibrado")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.green.opacity(0.12), in: Capsule())
            Spacer()
        }
        .help("Límite auto-detectado desde tu último rate limit real — más preciso que el valor por defecto del plan")
    }

    private func limitRow(label: String, value: Int, planDefault: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(formatTokens(value))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            if value != planDefault {
                Text(lm.s(.modified))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    // MARK: - Acerca de

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(lm.s(.sectionAbout), icon: "info.circle.fill", color: .secondary)

            HStack {
                Text(lm.s(.dataSource))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("~/.claude/projects/")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Text(lm.s(.network))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 3) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text(lm.s(.noExternalConns))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
