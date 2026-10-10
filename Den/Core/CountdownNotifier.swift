import Foundation
import UserNotifications

/// 倒數結束的本機通知。這是 app 唯一的一種通知。
///
/// - 第一次開始倒數時才請求權限；被拒絕就安靜地不發，不再詢問也不引導去設定。
/// - 時間到了之後計時不會停，使用者按 End 才結束，所以前景也會顯示橫幅。
@MainActor
final class CountdownNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = CountdownNotifier()

    /// 打開後倒數結束的通知用 Time Sensitive，專注模式 / 勿擾下也會響。
    static let ignoreFocusKey = "ignoreFocus"

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
        content.title = String(localized: "Time's up")
        content.body = String(localized: "\(DurationText.hoursAndMinutes(planned)). Nice work.")
        content.sound = .default
        if UserDefaults.standard.bool(forKey: Self.ignoreFocusKey) {
            content.interruptionLevel = .timeSensitive
        }

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
        // 倒數到了之後計時還會繼續，所以前景也要提醒。
        [.banner, .sound]
    }
}
