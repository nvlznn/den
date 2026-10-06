import ActivityKit
import Foundation

/// 計時開始時啟動 Live Activity；結束、不儲存、倒數時間到時關掉。
@MainActor
enum LiveActivityController {
    static func start(for session: ActiveSession, tagName: String?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()

        let attributes = FocusActivityAttributes(
            startedAt: session.startedAt,
            endsAt: session.plannedEnd,
            tagName: tagName
        )
        let content = ActivityContent(state: FocusActivityAttributes.ContentState(), staleDate: session.plannedEnd)
        _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    static func end() {
        // 先記下現在有哪些，避免把緊接著 `start` 建立的新 activity 也關掉。
        let ids = Set(Activity<FocusActivityAttributes>.activities.map(\.id))
        guard !ids.isEmpty else { return }
        Task {
            for activity in Activity<FocusActivityAttributes>.activities where ids.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
