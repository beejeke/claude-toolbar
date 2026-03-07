import Foundation
import SwiftUI
import AppKit

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var sessionUsage: UsageMetric?
    @Published var weeklyUsage: UsageMetric?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var showSettings = false

    private var autoRefreshTask: Task<Void, Never>?
    private var loginWindowController: LoginWindowController?
    private var sessionKeyObserver: NSObjectProtocol?
    private let refreshInterval: UInt64 = 5 * 60 * 1_000_000_000 // 5 minutos en nanosegundos

    var sessionKey: String {
        UserDefaults.standard.string(forKey: "sessionKey") ?? ""
    }

    var hasSessionKey: Bool { !sessionKey.isEmpty }

    init() {
        if hasSessionKey {
            Task { await fetchData() }
        } else {
            showSettings = true
        }
        startAutoRefresh()
        observeSessionKeyDetection()
    }

    func refresh() {
        Task { await fetchData() }
    }

    func saveSessionKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "sessionKey")
        showSettings = false
        Task { await fetchData() }
    }

    func openLoginWindow() {
        // Si ya hay una ventana abierta, la traemos al frente
        if let existing = loginWindowController {
            existing.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = LoginWindowController { [weak self] sessionKey in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.loginWindowController = nil
                self.saveSessionKey(sessionKey)
            }
        }
        loginWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Private

    private func fetchData() async {
        guard hasSessionKey else {
            showSettings = true
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let data = try await ClaudeAPIService.shared.fetchUsageData(sessionKey: sessionKey)
            sessionUsage = data.sessionUsage
            weeklyUsage = data.weeklyUsage
            lastUpdated = .now
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func startAutoRefresh() {
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self?.refreshInterval ?? 300_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.fetchData()
            }
        }
    }

    private func observeSessionKeyDetection() {
        sessionKeyObserver = NotificationCenter.default.addObserver(
            forName: .claudeSessionKeyDetected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let key = notification.object as? String else { return }
            Task { @MainActor [weak self] in
                self?.loginWindowController?.close()
                self?.loginWindowController = nil
                self?.saveSessionKey(key)
            }
        }
    }

    deinit {
        autoRefreshTask?.cancel()
        if let observer = sessionKeyObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
