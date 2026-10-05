import Foundation
import UserNotifications
import PostCore

func notificationRequest(_ card: Card, settings: Settings) -> UNNotificationRequest? {
    guard let due = card.dueAt, card.kind == .reminder, card.doneAt == nil else { return nil }
    let content = UNMutableNotificationContent()
    content.title = settings.privacy ? tr(settings.language,"Şerit hatırlatması","Şerit reminder") : card.title
    content.body = settings.privacy ? tr(settings.language,"Bir hatırlatmanın vakti geldi. Şerit’i aç.","A reminder is ready. Open Şerit.") : card.body
    content.userInfo = ["cardID": card.id.uuidString]
    // Deliberately quiet: delivery follows the person's macOS notification settings.
    var components = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: due)
    components.timeZone = TimeZone.current
    return UNNotificationRequest(identifier: "serit." + card.id.uuidString, content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
}

final class NotificationDesk: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var desired = Archive()
    private var revision = 0
    private var busy = false
    var onError: ((String) -> Void)?
    var onOpen: ((UUID?) -> Void)?
    override init() { super.init(); center.delegate = self }
    func authorize(_ completion: @escaping (Bool, String?) -> Void) {
        center.requestAuthorization(options: [.alert]) { allowed, error in
            DispatchQueue.main.async { completion(allowed, error?.localizedDescription) }
        }
    }
    func refresh(_ archive: Archive) {
        desired = archive; revision += 1
        if archive.settings.privacy { center.removeAllDeliveredNotifications() }
        reconcile()
    }
    private func reconcile() {
        guard !busy else { return }; busy = true
        let planned = desired, scheduledRevision = revision
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.center.removeAllPendingNotificationRequests()
                guard planned.settings.notifications && settings.authorizationStatus == .authorized else {
                    if planned.settings.notifications { self.onError?(tr(planned.settings.language,"Bildirim izni yok; şerit ve menü çubuğu çalışır.","Notifications are not allowed; the strip and menu bar still work.")) }
                    self.finish(scheduledRevision); return
                }
                let group = DispatchGroup()
                for card in planned.notificationCards(at: Date()) {
                    guard let request = notificationRequest(card, settings: planned.settings) else { continue }
                    group.enter()
                    self.center.add(request) { error in
                        if let error = error { DispatchQueue.main.async { self.onError?(error.localizedDescription) } }
                        group.leave()
                    }
                }
                group.notify(queue: .main) { self.finish(scheduledRevision) }
            }
        }
    }
    private func finish(_ completed: Int) { busy = false; if revision != completed { reconcile() } }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = (response.notification.request.content.userInfo["cardID"] as? String).flatMap(UUID.init(uuidString:))
        DispatchQueue.main.async { self.onOpen?(id) }; completionHandler()
    }
}
