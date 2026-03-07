import AppKit
import SwiftUI

// MARK: - Window Controller

@MainActor
final class LoginWindowController: NSWindowController {

    /// Llamado cuando el login se detecta correctamente
    var onLoggedIn: (() -> Void)?

    convenience init(onLoggedIn: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Conectar con Claude"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        self.onLoggedIn = onLoggedIn

        let hc = NSHostingController(rootView: LoginFlowView(onLoggedIn: onLoggedIn))
        window.contentViewController = hc
    }
}

// MARK: - ViewModel

@MainActor
private final class LoginFlowViewModel: ObservableObject {

    enum State { case checking, notLoggedIn, waitingForLogin }

    @Published var state: State = .checking

    private var pollingTask: Task<Void, Never>?
    let onLoggedIn: () -> Void

    init(onLoggedIn: @escaping () -> Void) {
        self.onLoggedIn = onLoggedIn
        checkNow()
    }

    deinit { pollingTask?.cancel() }

    // MARK: Actions

    func openSafariAndWait() {
        openSafari()
        state = .waitingForLogin
        startPolling()
    }

    func cancel() {
        pollingTask?.cancel()
        state = .notLoggedIn
    }

    // MARK: Detection

    /// Comprobacion inicial: intenta la API directamente.
    private func checkNow() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // espera que la UI aparezca
            let loggedIn = await ClaudeAPIService.shared.checkLoginStatus()
            await MainActor.run { [weak self] in
                if loggedIn {
                    self?.onLoggedIn()
                } else {
                    self?.state = .notLoggedIn
                }
            }
        }
    }

    /// Polling cada 2s tras abrir Safari — detecta cuando el login completa.
    private func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { break }
                let loggedIn = await ClaudeAPIService.shared.checkLoginStatus()
                if loggedIn {
                    await MainActor.run { [weak self] in self?.onLoggedIn() }
                    return
                }
            }
        }
    }

    private func openSafari() {
        let url = URL(string: "https://claude.ai/login")!
        if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
            NSWorkspace.shared.open([url], withApplicationAt: safariURL,
                                    configuration: .init(), completionHandler: nil)
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - SwiftUI View

private struct LoginFlowView: View {
    let onLoggedIn: () -> Void
    @StateObject private var vm: LoginFlowViewModel

    init(onLoggedIn: @escaping () -> Void) {
        self.onLoggedIn = onLoggedIn
        _vm = StateObject(wrappedValue: LoginFlowViewModel(onLoggedIn: onLoggedIn))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ClaudeLogoView(size: 24, color: .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conectar con Claude").font(.system(size: 14, weight: .semibold))
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            // Content
            Group {
                switch vm.state {
                case .checking:      checkingView
                case .notLoggedIn:   notLoggedInView
                case .waitingForLogin: waitingView
                }
            }
            .padding(22)
            .animation(.easeInOut(duration: 0.2), value: vm.state == .checking)
        }
        .frame(width: 380)
    }

    private var subtitle: String {
        switch vm.state {
        case .checking:        return "Comprobando sesion..."
        case .notLoggedIn:     return "Inicia sesion en Safari"
        case .waitingForLogin: return "Esperando login en Safari..."
        }
    }

    // MARK: Subviews

    private var checkingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.1)
            Text("Comprobando si ya tienes sesion activa en Safari...")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }

    private var notLoggedInView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
                row(icon: "safari",            color: .blue,   text: "Se abrira Safari en claude.ai/login")
                row(icon: "hand.tap.fill",     color: .orange, text: "Inicia sesion con Google u otro metodo")
                row(icon: "checkmark.circle.fill", color: .green, text: "La app detectara el login automaticamente")
            }
            .padding(14)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                vm.openSafariAndWait()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "safari").font(.system(size: 14))
                    Text("Abrir Safari e iniciar sesion").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 9)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    private var waitingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.1)
            VStack(spacing: 5) {
                Text("Inicia sesion en Safari")
                    .font(.system(size: 13, weight: .medium))
                Text("Cuando completes el login en Safari, esta ventana se cerrara sola.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Cancelar") { vm.cancel() }
                .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
    }

    private func row(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color).frame(width: 18)
            Text(text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
