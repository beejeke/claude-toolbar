import AppKit
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Solicitar permiso de notificaciones y registrar el delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        NotificationService.requestPermission()

        menuBarController = MenuBarController()
    }
}
