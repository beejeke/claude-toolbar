import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 14) {
            ClaudeLogoView(size: 32, color: .orange)
            Text("Claude Code Usage").font(.system(size: 14, weight: .semibold))
            Text("Lee el uso de tokens directamente de los archivos de sesión de Claude Code en ~/.claude/projects/. No requiere configuración.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}
