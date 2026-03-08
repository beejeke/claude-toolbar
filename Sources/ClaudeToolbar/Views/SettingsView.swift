import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: UsageViewModel

    var body: some View {
        VStack(spacing: 0) {
            notificationsSection
            Divider()
            limitsSection
            Divider()
            aboutSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Notificaciones

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Notificaciones", icon: "bell.fill", color: .blue)

            Toggle(isOn: $viewModel.notificationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alertas de umbral")
                        .font(.system(size: 12, weight: .medium))
                    Text("Avisa al 70% y 90% del límite diario y semanal")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            if !viewModel.notificationsEnabled {
                Text("Las notificaciones están desactivadas")
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
            sectionHeader("Límites de tokens", icon: "gauge.medium", color: .orange)

            limitRow(
                label: "Diario",
                value: viewModel.dailyOutputLimit,
                planDefault: viewModel.subscriptionPlan.defaultDailyOutputLimit
            )
            limitRow(
                label: "Semanal",
                value: viewModel.weeklyOutputLimit,
                planDefault: viewModel.subscriptionPlan.defaultWeeklyOutputLimit
            )

            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("Detectado: plan \(viewModel.subscriptionPlan.displayName)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Restablecer") {
                    viewModel.resetLimitsToDetectedPlan()
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 12)
    }

    private func limitRow(label: String, value: Int, planDefault: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(formatTokens(value))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            if value != planDefault {
                Text("(modificado)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    // MARK: - Acerca de

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Acerca de", icon: "info.circle.fill", color: .secondary)

            HStack {
                Text("Fuente de datos")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("~/.claude/projects/")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Text("Red")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 3) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Sin conexiones externas")
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
