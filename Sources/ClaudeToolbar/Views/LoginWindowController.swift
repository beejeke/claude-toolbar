import AppKit
import SwiftUI

// MARK: - Window Controller

@MainActor
final class LoginWindowController: NSWindowController {

    var onLoginSuccess: ((String) -> Void)?
    private var hostingController: NSHostingController<LoginFlowView>?

    convenience init(onSuccess: @escaping (String) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 360),
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

// MARK: - State machine

enum LoginState: Equatable {
    case checking            // Comprobando si ya hay sesion activa en Safari
    case notLoggedIn         // No hay sesion activa → mostrar boton de abrir Safari
    case openingSafari       // Abriendo Safari...
    case waitingForLogin     // Safari abierto, esperando que el usuario haga login
    case fallback(String?)   // Logueado pero no se pudo auto-capturar (HttpOnly)
}

// MARK: - ViewModel

@MainActor
final class LoginFlowViewModel: ObservableObject {

    @Published var state: LoginState = .checking

    private var pollingTask: Task<Void, Never>?

    init() {
        checkExistingSession()
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Public actions

    func openSafari() {
        state = .openingSafari
        SafariService.openLogin()
        state = .waitingForLogin
        startPolling()
    }

    func cancel() {
        pollingTask?.cancel()
        pollingTask = nil
        state = .notLoggedIn
    }

    func showFallback(reason: String? = nil) {
        pollingTask?.cancel()
        pollingTask = nil
        state = .fallback(reason)
    }

    func retryCheck() {
        pollingTask?.cancel()
        state = .checking
        checkExistingSession()
    }

    // MARK: - Session detection

    /// Comprueba al arrancar si ya hay sesion activa en Safari.
    private func checkExistingSession() {
        Task { [weak self] in
            // Pequeña pausa para que la UI aparezca antes del bloqueo de AppleScript
            try? await Task.sleep(nanoseconds: 400_000_000)

            // 1. Intentar captura automatica si ya hay sesion
            if let key = await SafariService.extractSessionKey(), !key.isEmpty {
                NotificationCenter.default.post(name: .claudeSessionKeyDetected, object: key)
                return
            }

            // 2. Comprobar si esta logueado (pero cookie HttpOnly, no se pudo leer)
            let loggedIn = await SafariService.isLoggedIntoClaudeAI()

            await MainActor.run { [weak self] in
                if loggedIn {
                    self?.state = .fallback("Tu sesion esta activa en Safari pero la key no se pudo leer automaticamente.")
                } else {
                    self?.state = .notLoggedIn
                }
            }
        }
    }

    /// Polling cada 2s mientras el usuario inicia sesion.
    private func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { break }

                // Intentar captura
                if let key = await SafariService.extractSessionKey(), !key.isEmpty {
                    NotificationCenter.default.post(name: .claudeSessionKeyDetected, object: key)
                    return
                }

                // Si ya esta logueado pero no podemos leer la key → fallback
                let loggedIn = await SafariService.isLoggedIntoClaudeAI()
                if loggedIn {
                    await MainActor.run { [weak self] in
                        self?.state = .fallback(nil)
                    }
                    return
                }
            }
        }
    }
}

// MARK: - Safari Service

enum SafariService {

    static func openLogin() {
        guard let safariURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.Safari"
        ) else {
            NSWorkspace.shared.open(URL(string: "https://claude.ai/login")!)
            return
        }
        NSWorkspace.shared.open(
            [URL(string: "https://claude.ai/login")!],
            withApplicationAt: safariURL,
            configuration: .init(),
            completionHandler: nil
        )
    }

    /// Comprueba si Safari tiene alguna pestaña logueada en claude.ai (URL no es /login ni /auth).
    static func isLoggedIntoClaudeAI() async -> Bool {
        await runAppleScript("""
        tell application "Safari"
            repeat with w in windows
                if visible of w then
                    repeat with t in tabs of w
                        set u to URL of t
                        if u contains "claude.ai" and u does not contain "/login" and u does not contain "/auth" then
                            return "yes"
                        end if
                    end repeat
                end if
            end repeat
            return "no"
        end tell
        """) == "yes"
    }

    /// Intenta leer la sessionKey via JavaScript en las pestanas claude.ai de Safari.
    /// Devuelve nil si la cookie tiene HttpOnly o si no hay sesion activa.
    static func extractSessionKey() async -> String? {
        let js = #"(function(){var c=document.cookie;var m=c.match(/(?:^|;\s*)sessionKey=([^;]+)/);if(m)return decodeURIComponent(m[1]);var ls=localStorage.getItem('sessionKey')||localStorage.getItem('session_key')||localStorage.getItem('__session');if(ls&&ls.length>10)return ls;return '';})()"#

        let result = await runAppleScript("""
        tell application "Safari"
            set keyValue to ""
            repeat with w in windows
                if visible of w then
                    repeat with t in tabs of w
                        set u to URL of t
                        if u contains "claude.ai" and u does not contain "/login" then
                            try
                                set v to do JavaScript "\(js)" in t
                                if v is not "" then
                                    set keyValue to v
                                end if
                            end try
                        end if
                    end repeat
                end if
            end repeat
            return keyValue
        end tell
        """)

        return result?.isEmpty == false ? result : nil
    }

    // MARK: AppleScript runner (background thread)

    static func runAppleScript(_ source: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(returning: nil)
                    return
                }
                let result = script.executeAndReturnError(&error)
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: result.stringValue)
            }
        }
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
                .animation(.easeInOut(duration: 0.25), value: vm.state)
        }
        .frame(width: 400)
        .onDisappear { vm.cancel() }
        .onReceive(
            NotificationCenter.default.publisher(for: .claudeSessionKeyDetected)
        ) { note in
            if let key = note.object as? String {
                onSuccess(key)
            }
        }
    }

    // MARK: Header

    private var headerView: some View {
        HStack(spacing: 12) {
            ClaudeLogoView(size: 24, color: .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Conectar con Claude")
                    .font(.system(size: 14, weight: .semibold))
                Text(headerSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var headerSubtitle: String {
        switch vm.state {
        case .checking:       return "Comprobando sesion activa en Safari..."
        case .notLoggedIn:    return "Abre Claude en Safari para iniciar sesion"
        case .openingSafari:  return "Abriendo Safari..."
        case .waitingForLogin: return "Esperando login en Safari..."
        case .fallback:       return "Copia tu session key de Safari"
        }
    }

    // MARK: Content

    @ViewBuilder
    private var contentView: some View {
        switch vm.state {
        case .checking:
            checkingView

        case .notLoggedIn:
            notLoggedInView

        case .openingSafari, .waitingForLogin:
            waitingView

        case .fallback(let reason):
            FallbackKeyView(reason: reason, onSuccess: onSuccess, onRetry: { vm.retryCheck() })
        }
    }

    // MARK: Checking view

    private var checkingView: some View {
        VStack(spacing: 14) {
            ProgressView().scaleEffect(1.1)
            Text("Comprobando si ya tienes sesion activa...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: Not logged in view

    private var notLoggedInView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "checkmark.circle.fill", color: .green,
                        text: "Se abrira Safari donde Google funciona correctamente")
                infoRow(icon: "key.fill", color: .orange,
                        text: "La session key se captura automaticamente tras el login")
            }
            .padding(14)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                vm.openSafari()
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

    // MARK: Waiting view

    private var waitingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.1)
            VStack(spacing: 6) {
                Text("Inicia sesion en Safari")
                    .font(.system(size: 13, weight: .medium))
                Text("La ventana de Safari esta abierta. Cuando completes el login la app lo detectara sola.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Button("Cancelar") { vm.cancel() }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button("Introducir manualmente") { vm.showFallback() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    private func infoRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color).frame(width: 18)
            Text(text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Fallback manual key view

struct FallbackKeyView: View {
    let reason: String?
    let onSuccess: (String) -> Void
    let onRetry: () -> Void

    @State private var keyInput = ""
    @State private var showKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Explicacion
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill").foregroundStyle(.blue).font(.system(size: 13))
                Text(reason ?? "La session key no se pudo leer automaticamente (cookie protegida). Cópiala en un paso:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(Color.blue.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Instruccion compacta Safari
            VStack(alignment: .leading, spacing: 4) {
                Text("En Safari:")
                    .font(.system(size: 11, weight: .semibold))
                Text("Develop → Show Web Inspector → Storage → Cookies → claude.ai")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("Copia el valor de")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("sessionKey")
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Campo
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
                    Image(systemName: showKey ? "eye.slash" : "eye").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }

            HStack {
                Button("Reintentar deteccion") { onRetry() }
                    .buttonStyle(.plain).foregroundStyle(.secondary).font(.system(size: 11))
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

// MARK: - Notification

extension Notification.Name {
    static let claudeSessionKeyDetected = Notification.Name("claudeSessionKeyDetected")
}
