import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var currentSession: PeriodUsage?
    @Published var todayTotal: PeriodUsage?
    @Published var weekTotal: PeriodUsage?
    @Published var isLoading = false
    @Published var lastUpdated: Date?

    // Limites configurables de tokens de salida (output_tokens) por periodo.
    // Base: suscripcion Claude Code Pro — ajusta segun tu uso habitual.
    @Published var dailyOutputLimit: Int {
        didSet { UserDefaults.standard.set(dailyOutputLimit, forKey: "dailyOutputLimit") }
    }
    @Published var weeklyOutputLimit: Int {
        didSet { UserDefaults.standard.set(weeklyOutputLimit, forKey: "weeklyOutputLimit") }
    }

    private var autoRefreshTask: Task<Void, Never>?
    private let refreshInterval: UInt64 = 60 * 1_000_000_000

    init() {
        let daily  = UserDefaults.standard.integer(forKey: "dailyOutputLimit")
        let weekly = UserDefaults.standard.integer(forKey: "weeklyOutputLimit")
        dailyOutputLimit  = daily  > 0 ? daily  : 150_000
        weeklyOutputLimit = weekly > 0 ? weekly : 750_000

        Task { await fetchData() }
        startAutoRefresh()
    }

    func refresh() {
        Task { await fetchData() }
    }

    private func fetchData() async {
        isLoading = true
        let data = await CLIUsageService.shared.fetchUsageData()
        currentSession = data.currentSession
        todayTotal     = data.todayTotal
        weekTotal      = data.weekTotal
        lastUpdated    = .now
        isLoading = false
    }

    private func startAutoRefresh() {
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self?.refreshInterval ?? 60_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.fetchData()
            }
        }
    }

    deinit { autoRefreshTask?.cancel() }
}
