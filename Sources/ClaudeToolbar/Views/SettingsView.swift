import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: UsageViewModel
    @State private var keyInput: String = ""
    @State private var showKey = false
    @State private var showManual = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Titulo
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.orange)
                Text("Conectar con Claude")
                    .font(.system(size: 14, weight: .semibold))
            }

            // Boton principal de login
            Button {
                viewModel.openLoginWindow()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .medium))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Iniciar sesion con Claude")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Se abre una ventana de login automaticamente")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // Separador con opcion manual
            HStack {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 1)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showManual.toggle()
                    }
                } label: {
                    Text(showManual ? "ocultar manual" : "introducir key manualmente")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 1)
            }

            // Seccion manual (colapsable)
            if showManual {
                VStack(alignment: .leading, spacing: 10) {
                    // Campo session key
                    HStack(spacing: 6) {
                        Group {
                            if showKey {
                                TextField("sessionKey", text: $keyInput)
                            } else {
                                SecureField("sessionKey", text: $keyInput)
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

                    // Como obtener la key manualmente
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Como obtener la session key:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("claude.ai → DevTools (Cmd+Option+I) → Application → Cookies → sessionKey")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

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
                        Button("Guardar") {
                            viewModel.saveSessionKey(keyInput.trimmingCharacters(in: .whitespaces))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if viewModel.hasSessionKey && !showManual {
                HStack {
                    Spacer()
                    Button("Cancelar") {
                        viewModel.showSettings = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .onAppear {
            keyInput = viewModel.sessionKey
        }
    }
}
