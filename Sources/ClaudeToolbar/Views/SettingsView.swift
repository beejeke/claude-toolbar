import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: UsageViewModel
    @State private var keyInput: String = ""
    @State private var showKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Titulo
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundStyle(.orange)
                Text("Configurar acceso")
                    .font(.system(size: 14, weight: .semibold))
            }

            Text("Necesitas tu session key de Claude para obtener datos de uso en tiempo real.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Instrucciones
            VStack(alignment: .leading, spacing: 6) {
                instructionRow(number: "1", text: "Abre **claude.ai** con sesion iniciada")
                instructionRow(number: "2", text: "Presiona **Cmd+Option+I** (DevTools)")
                instructionRow(number: "3", text: "Ve a **Application → Cookies → claude.ai**")
                instructionRow(number: "4", text: "Copia el valor de **sessionKey**")
            }
            .padding(10)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Campo session key
            HStack(spacing: 6) {
                Group {
                    if showKey {
                        TextField("Pega tu sessionKey aqui", text: $keyInput)
                    } else {
                        SecureField("Pega tu sessionKey aqui", text: $keyInput)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(showKey ? "Ocultar" : "Mostrar")
            }

            // Acciones
            HStack {
                if viewModel.hasSessionKey {
                    Button("Cancelar") {
                        viewModel.showSettings = false
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Guardar y conectar") {
                    viewModel.saveSessionKey(keyInput)
                }
                .buttonStyle(.borderedProminent)
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .onAppear {
            keyInput = viewModel.sessionKey
        }
    }

    private func instructionRow(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(.orange)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
