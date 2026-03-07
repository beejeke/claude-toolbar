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
    @Published var showLogin = false

    private var autoRefreshTask: Task<Void, Never>?
    private var loginWindowController: LoginWindowController?
    private let refreshInterval: UInt64 = 5 * 60 * 1_000_000_000

    init() {
        Task { await fetchData() }
        startAutoRefresh()
    }

    // MARK: Public

    func refresh() {
        Task { await fetchData() }
    }

    func openLoginWindow() {
        if let existing = loginWindowController {
            existing.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = LoginWindowController { [weak self] in
            Task { @MainActor [weak self] in
                self?.loginWindowController = nil
                self?.showLogin = false
                await self?.fetchData()
            }
        }
        loginWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Private

    private func fetchData() async {
        isLoading = true
        errorMessage = nil
        do {
            let data = try await ClaudeAPIService.shared.fetchUsageData()
            sessionUsage = data.sessionUsage
            weeklyUsage  = data.weeklyUsage
            lastUpdated  = .now
            showLogin = false
        } catch ClaudeAPIError.notLoggedIn {
            showLogin = true
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

    deinit { autoRefreshTask?.cancel() }
}
