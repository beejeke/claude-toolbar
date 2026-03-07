import AppKit
import WebKit

/// Ventana con WKWebView que carga claude.ai/login y extrae automaticamente
/// la sessionKey al detectarla en las cookies tras el inicio de sesion.
@MainActor
final class LoginWindowController: NSWindowController {

    var onLoginSuccess: ((String) -> Void)?

    private var webView: WKWebView!
    private var progressBar: NSProgressIndicator!
    private var statusLabel: NSTextField!

    // MARK: Init

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 680),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Iniciar sesion en Claude"
        window.center()
        window.minSize = NSSize(width: 400, height: 500)
        self.init(window: window)
        buildUI()
    }

    // MARK: UI Setup

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        // Barra de progreso superior
        progressBar = NSProgressIndicator()
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.doubleValue = 0
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressBar)

        // WKWebView
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent() // sesion limpia cada vez
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        contentView.addSubview(webView)

        // Label de estado
        statusLabel = NSTextField(labelWithString: "Detectando sesion...")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.isHidden = true
        contentView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            progressBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            progressBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 4),

            webView.topAnchor.constraint(equalTo: progressBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -6),

            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            statusLabel.heightAnchor.constraint(equalToConstant: 16)
        ])

        // Monitorear cookies
        config.websiteDataStore.httpCookieStore.add(self)

        // Cargar pagina de login
        let loginURL = URL(string: "https://claude.ai/login")!
        webView.load(URLRequest(url: loginURL))
    }

    // MARK: Cookie detection

    private func checkForSessionKey(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            guard let sessionCookie = cookies.first(where: {
                ($0.domain.contains("claude.ai") || $0.domain.contains("anthropic.com"))
                    && $0.name == "sessionKey"
            }) else { return }

            let key = sessionCookie.value
            Task { @MainActor [weak self] in
                self?.handleSuccessfulLogin(sessionKey: key)
            }
        }
    }

    private func handleSuccessfulLogin(sessionKey: String) {
        statusLabel.isHidden = false
        statusLabel.stringValue = "Sesion detectada. Conectando..."
        webView.isHidden = true

        // Pequeña pausa visual antes de cerrar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.onLoginSuccess?(sessionKey)
            self.close()
        }
    }
}

// MARK: - WKHTTPCookieStoreObserver

extension LoginWindowController: WKHTTPCookieStoreObserver {
    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor [weak self] in
            self?.checkForSessionKey(in: cookieStore)
        }
    }
}

// MARK: - WKNavigationDelegate

extension LoginWindowController: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView,
                             didStartProvisionalNavigation navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            self?.progressBar.doubleValue = 0.1
        }
    }

    nonisolated func webView(_ webView: WKWebView,
                             didCommit navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            self?.progressBar.doubleValue = 0.5
        }
    }

    nonisolated func webView(_ webView: WKWebView,
                             didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.progressBar.doubleValue = 1.0
            // Verificar cookies al terminar de cargar cada pagina
            self.checkForSessionKey(in: webView.configuration.websiteDataStore.httpCookieStore)
            // Ocultar barra tras un momento
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.progressBar.doubleValue = 0
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView,
                             didFail navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor [weak self] in
            self?.progressBar.doubleValue = 0
        }
    }
}
