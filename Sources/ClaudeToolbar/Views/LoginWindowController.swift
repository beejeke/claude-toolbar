import AppKit
import SwiftUI

// MARK: - Window Controller

@MainActor
final class LoginWindowController: NSWindowController {

    var onLoginSuccess: ((String) -> Void)?
    private var hostingController: NSHostingController<LoginFlowView>?

    convenience init(onSuccess: @escaping (String) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 340),
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
        hostingController = hc
    }
}

// MARK: - SwiftUI View

struct LoginFlowView: View {
    let onSuccess: (String) -> Void

    @StateObject private var vm = LoginFlowViewModel()

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
                .padding(22)
        }
        .frame(width: 400)
        .onDisappear { vm.stopPolling() }
    }

    // MARK: Header

    private var headerView: some View {
        HStack(spacing: 12) {
            ClaudeLogoView(size: 24, color: .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Iniciar sesion en Claude")
                    .font(.system(size: 14, weight: .semibold))
                Text(vm.state.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            stepIndicator
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var stepIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<2) { i in
                Circle()
                    .fill(vm.state.stepIndex >= i ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var contentView: some View {
        switch vm.state {
        case .ready:
            readyStep
        case .waiting:
            waitingStep
        case .fallback:
            fallbackStep(error: nil)
        case .error(let msg):
            fallbackStep(error: msg)
        }
    }

    // MARK: Step 1 - Ready

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "checkmark.circle.fill", color: .green,
                        text: "Se abrira Safari donde Google funciona correctamente")
                infoRow(icon: "key.fill", color: .orange,
                        text: "La session key se captura automaticamente al hacer login")
                infoRow(icon: "lock.shield.fill", color: .blue,
                        text: "Tu contrasena nunca pasa por esta app")
            }
            .padding(14)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                vm.openSafariAndStartPolling()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "safari")
                        .font(.system(size: 15))
                    Text("Abrir Safari e iniciar sesion")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: Step 2 - Waiting / polling

    private var waitingStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Esperando que inicies sesion en Safari...")
                    .font(.system(size: 13, weight: .medium))
                Text("Inicia sesion con Google en la ventana de Safari.\nLa app lo detectara automaticamente.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)

            HStack(spacing: 12) {
                Button("Cancelar") {
                    vm.stopPolling()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Introducir key manualmente") {
                    vm.showFallback()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Fallback - Manual key input

    private func fallbackStep(error: String?) -> some View {
        FallbackKeyView(error: error, onSuccess: onSuccess, onBack: { vm.reset() })
    }

    // MARK: Helpers

    private func infoRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Fallback manual key view

private struct FallbackKeyView: View {
    let error: String?
    let onSuccess: (String) -> Void
    let onBack: () -> Void

    @State private var keyInput = ""
    @State private var showKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(error).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text("Copia la sessionKey manualmente:")
                .font(.system(size: 12, weight: .medium))

            // Instrucciones compactas
            VStack(alignment: .leading, spacing: 5) {
                Text("En Safari: Develop → Show Web Inspector → Storage → Cookies → claude.ai → sessionKey")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 6) {
                Group {
                    if showKey {
                        TextField("Pega aqui el valor de sessionKey", text: $keyInput)
                    } else {
                        SecureField("Pega aqui el valor de sessionKey", text: $keyInput)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

                Button { showKey.toggle() } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button("Atras") { onBack() }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button("Conectar") {
                    let key = keyInput.trimmingCharacters(in: .whitespaces)
                    guard key.count > 10 else { return }
                    onSuccess(key)
                }
                .buttonStyle(.borderedProminent)
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).count <= 10)
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
private final class LoginFlowViewModel: ObservableObject {

    enum State {
        case ready, waiting, fallback, error(String)

        var subtitle: String {
            switch self {
            case .ready:    return "Paso 1 de 2: Abre Claude en Safari"
            case .waiting:  return "Paso 2 de 2: Inicia sesion en Safari"
            case .fallback: return "Introduccion manual de session key"
            case .error:    return "No se pudo capturar automaticamente"
            }
        }

        var stepIndex: Int {
            switch self {
            case .ready: return 0
            default:     return 1
            }
        }
    }

    @Published var state: State = .ready

    private var pollingTask: Task<Void, Never>?

    // MARK: Actions

    func openSafariAndStartPolling() {
        openSafari()
        state = .waiting
        startPolling()
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        state = .ready
    }

    func showFallback() {
        pollingTask?.cancel()
        pollingTask = nil
        state = .fallback
    }

    func reset() {
        state = .ready
    }

    // MARK: Safari

    private func openSafari() {
        guard let safariURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.Safari"
        ) else {
            // Fallback al navegador por defecto si Safari no esta disponible
            NSWorkspace.shared.open(URL(string: "https://claude.ai/login")!)
            return
        }

        let loginURL = URL(string: "https://claude.ai/login")!
        NSWorkspace.shared.open(
            [loginURL],
            withApplicationAt: safariURL,
            configuration: .init(),
            completionHandler: nil
        )
    }

    // MARK: Polling via AppleScript

    private func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000) // cada 2.5s
                guard !Task.isCancelled else { break }

                if let key = await self?.extractSessionKeyFromSafari(), !key.isEmpty {
                    await MainActor.run { [weak self] in
                        self?.pollingTask = nil
                        // Publicamos el exito a traves de una notificacion
                        NotificationCenter.default.post(
                            name: .claudeSessionKeyDetected,
                            object: key
                        )
                    }
                    break
                }
            }
        }
    }

    /// Ejecuta AppleScript en background para leer la cookie sessionKey de Safari.
    /// Funciona si la cookie no tiene el flag HttpOnly.
    /// Si el flag esta presente, devuelve nil y se muestra el flujo manual.
    private func extractSessionKeyFromSafari() async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let source = """
                tell application "Safari"
                    set keyValue to ""
                    repeat with w in windows
                        if visible of w then
                            repeat with t in tabs of w
                                set tabURL to URL of t
                                if tabURL contains "claude.ai" and tabURL does not contain "/login" then
                                    try
                                        set js to "(function(){var c=document.cookie;var m=c.match(/(?:^|;\\\\s*)sessionKey=([^;]+)/);return m?decodeURIComponent(m[1]):'';})()"
                                        set cookieVal to do JavaScript js in t
                                        if cookieVal is not "" then
                                            set keyValue to cookieVal
                                        end if
                                    end try
                                end if
                            end repeat
                        end if
                    end repeat
                    return keyValue
                end tell
                """
                var error: NSDictionary?
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(returning: nil)
                    return
                }
                let result = script.executeAndReturnError(&error)
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                let value = result.stringValue
                continuation.resume(returning: value?.isEmpty == false ? value : nil)
            }
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let claudeSessionKeyDetected = Notification.Name("claudeSessionKeyDetected")
}
