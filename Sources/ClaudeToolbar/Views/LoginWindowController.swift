import AppKit
import SwiftUI

/// Ventana de login que abre el navegador del sistema (Safari/Chrome/etc)
/// para evitar el bloqueo de Google en WKWebView embebidos.
/// Guia al usuario para obtener la sessionKey desde DevTools.
@MainActor
final class LoginWindowController: NSWindowController {

    var onLoginSuccess: ((String) -> Void)?
    private var hostingController: NSHostingController<LoginFlowView>?

    convenience init(onSuccess: @escaping (String) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Conectar con Claude"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        self.onLoginSuccess = onSuccess

        let view = LoginFlowView { [weak self] key in
            self?.onLoginSuccess?(key)
            self?.close()
        }
        let hc = NSHostingController(rootView: view)
        window.contentViewController = hc
        window.setContentSize(hc.view.fittingSize)
        hostingController = hc
    }
}

// MARK: - SwiftUI View

struct LoginFlowView: View {
    let onSuccess: (String) -> Void

    @State private var step: Step = .openBrowser
    @State private var keyInput: String = ""
    @State private var showKey: Bool = false
    @State private var isValidating: Bool = false
    @State private var validationError: String? = nil

    enum Step {
        case openBrowser, copyKey
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            Group {
                if step == .openBrowser {
                    openBrowserStep
                } else {
                    copyKeyStep
                }
            }
            .padding(24)
        }
        .frame(width: 420)
    }

    // MARK: Header

    private var headerView: some View {
        HStack(spacing: 12) {
            ClaudeLogoView(size: 28, color: .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Iniciar sesion en Claude")
                    .font(.system(size: 14, weight: .semibold))
                Text(step == .openBrowser
                     ? "Paso 1 de 2: Abre Claude en tu navegador"
                     : "Paso 2 de 2: Copia tu session key")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Progress dots
            HStack(spacing: 6) {
                Circle()
                    .fill(step == .openBrowser ? Color.accentColor : Color.accentColor.opacity(0.4))
                    .frame(width: 7, height: 7)
                Circle()
                    .fill(step == .copyKey ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: Step 1 - Open browser

    private var openBrowserStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Explicacion del problema
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 14))
                    .padding(.top, 1)
                Text("El login con Google no funciona en ventanas embebidas por politica de seguridad de Google. Te abrimos tu navegador habitual donde si funciona.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Pasos
            VStack(alignment: .leading, spacing: 10) {
                stepRow(number: 1, text: "Haz clic en el boton para abrir Claude en tu navegador")
                stepRow(number: 2, text: "Inicia sesion con tu cuenta de Google (o email)")
                stepRow(number: 3, text: "Cuando hayas accedido, vuelve aqui para el paso 2")
            }

            // Boton principal
            Button {
                openBrowserAndAdvance()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "safari")
                        .font(.system(size: 15))
                    Text("Abrir Claude en el navegador")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: Step 2 - Copy session key

    private var copyKeyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Instrucciones DevTools
            VStack(alignment: .leading, spacing: 10) {
                Text("Abre las DevTools de tu navegador y copia la session key:")
                    .font(.system(size: 12, weight: .medium))

                VStack(alignment: .leading, spacing: 6) {
                    browserRow(icon: "safari", name: "Safari",
                               instruction: "Develop → Show Web Inspector → Storage → Cookies")
                    Divider()
                    browserRow(icon: "globe", name: "Chrome / Brave",
                               instruction: "F12 → Application → Cookies → https://claude.ai")
                    Divider()
                    browserRow(icon: "globe", name: "Firefox",
                               instruction: "F12 → Storage → Cookies → https://claude.ai")
                }
                .padding(10)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 4) {
                    Text("Busca la cookie llamada")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("sessionKey")
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text("y copia su valor")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Campo para pegar la key
            VStack(alignment: .leading, spacing: 6) {
                Text("Pega aqui tu session key:")
                    .font(.system(size: 12, weight: .medium))

                HStack(spacing: 6) {
                    Group {
                        if showKey {
                            TextField("sk-ant-...", text: $keyInput)
                        } else {
                            SecureField("sk-ant-...", text: $keyInput)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onChange(of: keyInput) { _ in
                        validationError = nil
                    }

                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if let error = validationError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 11))
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
            }

            // Acciones
            HStack {
                Button("Volver al paso 1") {
                    step = .openBrowser
                    validationError = nil
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

                Spacer()

                if isValidating {
                    ProgressView().scaleEffect(0.8)
                }

                Button("Conectar") {
                    validateAndConnect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
            }
        }
    }

    // MARK: Helpers

    private func openBrowserAndAdvance() {
        NSWorkspace.shared.open(URL(string: "https://claude.ai/login")!)
        withAnimation(.easeInOut(duration: 0.3)) {
            step = .copyKey
        }
    }

    private func validateAndConnect() {
        let key = keyInput.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }

        // Validacion basica del formato
        guard key.count > 20 else {
            validationError = "La session key parece demasiado corta. Verifica que la hayas copiado completa."
            return
        }

        isValidating = true
        validationError = nil

        // Breve delay visual antes de conectar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isValidating = false
            onSuccess(key)
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.accentColor)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func browserRow(icon: String, name: String, instruction: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                Text(instruction)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
