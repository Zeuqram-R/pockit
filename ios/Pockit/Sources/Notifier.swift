import Foundation
import UIKit
import UserNotifications

/// Avisa cuando Marisol termina de responder y la app no está en pantalla.
/// iOS solo deja seguir trabajando unos segundos en segundo plano, así que mientras ella escribe se pide
/// ese tiempo extra; si la respuesta es muy larga, al volver a la app termina de llegar normal.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private var asked = false
    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "pockit.notifyReplies") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "pockit.notifyReplies") }
    }

    func setUp() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Se pide permiso la primera vez que Marisol empieza a responder (no al abrir la app de una).
    func askPermissionIfNeeded() {
        guard enabled, !asked else { return }
        asked = true
        UNUserNotificationCenter.current().getNotificationSettings { s in
            guard s.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    func streamingChanged(_ on: Bool, inBackground: Bool, lang: AppLanguage) {
        if on {
            askPermissionIfNeeded()
            if inBackground { keepAlive() }
        } else {
            if inBackground && enabled { post(lang: lang) }
            endKeepAlive()
        }
    }

    func wentToBackground(streaming: Bool) { if streaming { keepAlive() } }
    func becameActive() {
        endKeepAlive()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    private func keepAlive() {
        guard bgTask == .invalid else { return }
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "marisol-reply") { [weak self] in
            Task { @MainActor in self?.endKeepAlive() }
        }
    }

    private func endKeepAlive() {
        guard bgTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
    }

    private func post(lang: AppLanguage) {
        let t = L10n(lang)
        let c = UNMutableNotificationContent()
        // Sin el texto de la respuesta: así nunca se cuela un spoiler en la pantalla bloqueada.
        c.title = "Marisol"
        c.body = t.s("Ya te respondió. Tocá pa' leerla 💬", "She answered. Tap to read 💬")
        c.sound = .default
        c.badge = 1
        c.threadIdentifier = "marisol"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "reply-\(Date().timeIntervalSince1970)", content: c, trigger: nil))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [] // con la app abierta no hace falta: ya la estás viendo
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { IntentInbox.shared.openMarisol = true }
    }
}
