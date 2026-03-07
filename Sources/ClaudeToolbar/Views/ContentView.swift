import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: UsageViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            if viewModel.showSettings {
                SettingsView()
            } else {
                mainContent
            }
        }
        .frame(width: 340)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: Header

    private var headerView: some View {
        HStack(spacing: 8) {
            ClaudeLogoView(size: 18, color: .orange)

            Text("Claude Usage")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            } else {
                Button {
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Actualizar ahora")
                .keyboardShortcut("r", modifiers: .command)
            }

            Button {
                viewModel.showSettings.toggle()
            } label: {
                Image(systemName: viewModel.showSettings ? "xmark.circle" : "gear")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(viewModel.showSettings ? "Cerrar configuracion" : "Configuracion")

            quitButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var quitButton: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Image(systemName: "power")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Salir")
    }

    // MARK: Main content

    private var mainContent: some View {
        VStack(spacing: 16) {
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            VStack(spacing: 12) {
                UsageBarView(
                    title: "Sesion actual",
                    icon: "clock.fill",
                    metric: viewModel.sessionUsage,
                    color: .blue
                )

                Divider()
                    .padding(.horizontal, -16)

                UsageBarView(
                    title: "Uso semanal",
                    icon: "calendar",
                    metric: viewModel.weeklyUsage,
                    color: .purple
                )
            }

            if let lastUpdated = viewModel.lastUpdated {
                HStack {
                    Spacer()
                    Text("Actualizado \(lastUpdated, style: .relative)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
    }

    // MARK: Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button {
                viewModel.showSettings = true
            } label: {
                Text("Configurar")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

