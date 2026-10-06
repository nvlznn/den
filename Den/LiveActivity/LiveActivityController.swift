import ActivityKit
import Foundation

/// 計時開始時啟動 Live Activity；暫停、繼續時更新；結束時關掉。
@MainActor
enum LiveActivityController {
    static func start(for session: ActiveSession, tagName: String?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()

        let attributes = FocusActivityAttributes(tagName: tagName, characterID: session.characterID)
        _ = try? Activity.request(attributes: attributes, content: content(for: session), pushType: nil)
    }

    /// 暫停或繼續之後，把新的時間資料送給 Live Activity。
    static func update(for session: ActiveSession) {
        let content = content(for: session)
        let ids = Set(Activity<FocusActivityAttributes>.activities.map(\.id))
        guard !ids.isEmpty else { return }
        Task {
            for activity in Activity<FocusActivityAttributes>.activities where ids.contains(activity.id) {
                await activity.update(content)
            }
        }
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

    /// 暫停中不會過期（時間停著）；沒暫停的倒數在預定結束時間過期，之後畫面改成往上數超時。
    private static func content(for session: ActiveSession) -> ActivityContent<FocusActivityAttributes.ContentState> {
        ActivityContent(
            state: FocusActivityAttributes.ContentState(session: session),
            staleDate: session.isPaused ? nil : session.plannedEnd
        )
    }
}

extension FocusActivityAttributes.ContentState {
    /// 只有 app 這邊用得到 `ActiveSession`，所以放在這裡，不放在 widget 也會編譯的檔案裡。
    init(session: ActiveSession) {
        var pausedText: String?
        if let pausedAt = session.pausedAt {
            // 凍結在暫停那一刻：倒數顯示剩餘時間（超時就是 +超時），正計時顯示經過時間。
            let overtime = session.overtimeSeconds(at: pausedAt)
            pausedText = overtime > 0
                ? "+\(DurationText.clock(overtime))"
                : DurationText.clock(session.displayedSeconds(at: pausedAt))
        }
        self.init(
            startedAt: session.effectiveStart,
            endsAt: session.plannedEnd,
            pausedAt: session.pausedAt,
            pausedText: pausedText
        )
    }
}
