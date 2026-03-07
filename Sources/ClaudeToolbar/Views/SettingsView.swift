import SwiftUI

/// Ya no se necesita configuracion manual de session key.
/// La autenticacion se gestiona a traves de Safari automaticamente.
struct SettingsView: View {
    @EnvironmentObject private var viewModel: UsageViewModel

    var body: some View {
        VStack(spacing: 14) {
            ClaudeLogoView(size: 32, color: .orange)
            Text("Claude Toolbar").font(.system(size: 14, weight: .semibold))
            Text("La app lee tus datos de uso directamente desde tu sesion de Safari en claude.ai. No es necesario configurar nada.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Iniciar sesion en Safari") {
                viewModel.openLoginWindow()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}
