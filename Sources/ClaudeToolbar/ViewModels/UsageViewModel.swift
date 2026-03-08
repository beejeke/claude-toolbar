import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var currentSession: PeriodUsage?
    @Published var todayTotal: PeriodUsage?
    @Published var weekTotal: PeriodUsage?
    @Published var dailyHistory: [DailyUsage] = []
    @Published var burnRate: BurnRate?
    @Published var isLoading = false
    @Published var lastUpdated: Date?

    /// Plan detectado automáticamente desde el Keychain de Claude Code CLI.
    @Published private(set) var subscriptionPlan: SubscriptionPlan = .pro

    // Límites de output tokens configurables por periodo.
    // Se inicializan con los valores del plan detectado y se persisten en UserDefaults
    // si el usuario los sobreescribe manualmente.
    @Published var dailyOutputLimit: Int {
        didSet {
            UserDefaults.standard.set(dailyOutputLimit, forKey: "dailyOutputLimit")
            UserDefaults.standard.set(true, forKey: "dailyLimitOverridden")
        }
    }
    @Published var weeklyOutputLimit: Int {
        didSet {
            UserDefaults.standard.set(weeklyOutputLimit, forKey: "weeklyOutputLimit")
            UserDefaults.standard.set(true, forKey: "weeklyLimitOverridden")
        }
    }

    /// Activa o desactiva las notificaciones de umbral. Persiste en UserDefaults.
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    private var autoRefreshTask: Task<Void, Never>?
    private let refreshInterval: UInt64 = 60 * 1_000_000_000

    init() {
        // Detectar plan de suscripción desde el Keychain
        let plan = KeychainCredentialsService.readSubscriptionPlan()
        subscriptionPlan = plan

        // Usar límite guardado solo si el usuario lo sobreescribió manualmente;
        // de lo contrario, aplicar los valores del plan detectado.
        let dailyOverridden  = UserDefaults.standard.bool(forKey: "dailyLimitOverridden")
        let weeklyOverridden = UserDefaults.standard.bool(forKey: "weeklyLimitOverridden")

        let storedDaily  = UserDefaults.standard.integer(forKey: "dailyOutputLimit")
        let storedWeekly = UserDefaults.standard.integer(forKey: "weeklyOutputLimit")

        dailyOutputLimit  = (dailyOverridden  && storedDaily  > 0) ? storedDaily  : plan.defaultDailyOutputLimit
        weeklyOutputLimit = (weeklyOverridden && storedWeekly > 0) ? storedWeekly : plan.defaultWeeklyOutputLimit

        // Notificaciones: activadas por defecto; respetar preferencia si ya fue guardada
        let storedNotif = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool
        notificationsEnabled = storedNotif ?? true

        Task { await fetchData() }
        startAutoRefresh()
    }

    private func computeBurnRate(tokensPerHour: Double?) -> BurnRate? {
        guard let rate = tokensPerHour, rate > 0 else { return nil }
        let todayUsed   = todayTotal?.outputTokens ?? 0
        let weekUsed    = weekTotal?.outputTokens  ?? 0
        let remDaily    = Double(dailyOutputLimit  - todayUsed)
        let remWeekly   = Double(weeklyOutputLimit - weekUsed)
        return BurnRate(
            tokensPerHour: rate,
            hoursToDaily:  remDaily  > 0 ? remDaily  / rate : nil,
            hoursToWeekly: remWeekly > 0 ? remWeekly / rate : nil
        )
    }

    /// Descarta cualquier override manual y vuelve a los límites del plan detectado.
    func resetLimitsToDetectedPlan() {
        UserDefaults.standard.removeObject(forKey: "dailyLimitOverridden")
        UserDefaults.standard.removeObject(forKey: "weeklyLimitOverridden")
        dailyOutputLimit  = subscriptionPlan.defaultDailyOutputLimit
        weeklyOutputLimit = subscriptionPlan.defaultWeeklyOutputLimit
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
        dailyHistory   = data.dailyHistory
        burnRate       = computeBurnRate(tokensPerHour: data.sessionTokensPerHour)
        lastUpdated    = .now
        isLoading      = false

        // Comprobar umbrales y enviar notificaciones si corresponde
        if notificationsEnabled {
            NotificationService.checkAndNotify(
                dailyUsed:   data.todayTotal?.outputTokens  ?? 0,
                dailyLimit:  dailyOutputLimit,
                weeklyUsed:  data.weekTotal?.outputTokens   ?? 0,
                weeklyLimit: weeklyOutputLimit
            )
        }
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
