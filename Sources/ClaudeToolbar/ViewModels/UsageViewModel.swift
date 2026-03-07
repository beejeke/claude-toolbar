import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var sessionUsage: UsageMetric?
    @Published var weeklyUsage: UsageMetric?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var showSettings = false

    private var autoRefreshTask: Task<Void, Never>?
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
    }

    func refresh() {
        Task { await fetchData() }
    }

    func saveSessionKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "sessionKey")
        showSettings = false
        Task { await fetchData() }
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

    deinit {
        autoRefreshTask?.cancel()
    }
}
