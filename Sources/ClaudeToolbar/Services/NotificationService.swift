import Foundation
import UserNotifications

// MARK: - Notification name (used to open popover on notification tap)

extension Notification.Name {
    static let claudeToolbarOpenPopover = Notification.Name("claudeToolbarOpenPopover")
}

// MARK: - Service

/// Gestiona notificaciones nativas de umbrales de uso.
/// Envía como máximo una notificación por umbral por día (daily) o semana (weekly).
struct NotificationService {

    static let thresholds: [Double] = [0.70, 0.90]

    // MARK: - Permission

    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Threshold check

    /// Llama tras cada refresco de datos para disparar notificaciones si se cruzan umbrales.
    static func checkAndNotify(
        dailyUsed: Int, dailyLimit: Int,
        weeklyUsed: Int, weeklyLimit: Int
    ) {
        guard dailyLimit > 0, weeklyLimit > 0 else { return }
        let day  = dayKey()
        let week = weekKey()

        for threshold in thresholds {
            let pct = Int(threshold * 100)

            // Umbral diario — dedup por día
            let dailyPct = Double(dailyUsed) / Double(dailyLimit)
            let dKey = "notif_daily_\(pct)_\(day)"
            if dailyPct >= threshold && !UserDefaults.standard.bool(forKey: dKey) {
                send(
                    id: dKey,
                    title: "Claude Code — Uso diario al \(pct)%",
                    body: "\(format(dailyUsed)) / \(format(dailyLimit)) tokens generados hoy"
                )
                UserDefaults.standard.set(true, forKey: dKey)
            }

            // Umbral semanal — dedup por semana ISO
            let weeklyPct = Double(weeklyUsed) / Double(weeklyLimit)
            let wKey = "notif_weekly_\(pct)_\(week)"
            if weeklyPct >= threshold && !UserDefaults.standard.bool(forKey: wKey) {
                send(
                    id: wKey,
                    title: "Claude Code — Uso semanal al \(pct)%",
                    body: "\(format(weeklyUsed)) / \(format(weeklyLimit)) tokens generados esta semana"
                )
                UserDefaults.standard.set(true, forKey: wKey)
            }
        }
    }

    // MARK: - Private helpers

    private static func send(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    private static func dayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }

    private static func weekKey() -> String {
        let cal  = Calendar(identifier: .iso8601)
        let now  = Date.now
        let week = cal.component(.weekOfYear,       from: now)
        let year = cal.component(.yearForWeekOfYear, from: now)
        return "\(year)W\(String(format: "%02d", week))"
    }

    private static func format(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Delegate (handles tap → open popover, foreground display)

/// Singleton que actúa como UNUserNotificationCenterDelegate.
/// Debe asignarse antes de que lleguen notificaciones (en applicationDidFinishLaunching).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    /// Muestra la notificación incluso con la app en primer plano.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Al pulsar la notificación, abre el popover en el hilo principal.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .claudeToolbarOpenPopover, object: nil)
        }
        completionHandler()
    }
}
