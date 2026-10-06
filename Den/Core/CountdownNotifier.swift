import Foundation
import UserNotifications

/// 倒數結束的本機通知。這是 app 唯一的一種通知。
///
/// - 第一次開始倒數時才請求權限；被拒絕就安靜地不發，不再詢問也不引導去設定。
/// - App 在前景時不顯示橫幅，由寵物自己反應。
@MainActor
final class CountdownNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = CountdownNotifier()

    private static let requestID = "countdown-finished"

    private var center: UNUserNotificationCenter { .current() }

    func becomeDelegate() {
        center.delegate = self
    }

    /// 排一則在 `endDate` 發出的通知。`planned` 是這次倒數的總時長，用在內文。
    func schedule(at endDate: Date, planned: TimeInterval) async {
        guard await isAllowed() else { return }

        let interval = endDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "時間到了"
        content.body = "\(DurationText.hoursAndMinutes(planned))，辛苦了。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.requestID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// 取消還沒發出的通知（倒數提早結束）。
    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestID])
    }

    private func isAllowed() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // App 在前景時寵物會自己開心，不需要橫幅。
        []
    }
}
