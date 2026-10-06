import Foundation
import Observation
import SwiftData

/// 計時的動作與副作用：存檔、通知、Live Activity、寵物反應。
///
/// 放在最外層常駐，切到「紀錄」分頁時倒數到期也照樣處理。
@MainActor
@Observable
final class FocusController {
    let timer: FocusTimer

    var happySince: Date?
    var levelFlashSince: Date?
    /// 正計時結束後等待確認的紀錄。
    var sessionToConfirm: FinishedSession?

    // Haptic 觸發器
    private(set) var petTaps = 0
    private(set) var celebrations = 0
    private(set) var starts = 0
    private(set) var stops = 0

    init(timer: FocusTimer) {
        self.timer = timer
    }

    // MARK: 開始與結束

    func start(focusMinutes: Int, tag: FocusTag?) {
        let mode = TimerMode(focusMinutes: focusMinutes)
        timer.start(mode, tagID: tag?.id)
        starts += 1

        guard let active = timer.active else { return }
        LiveActivityController.start(for: active, tagName: tag?.name)
        if case .countdown(let planned) = mode, let end = active.plannedEnd {
            Task {
                await CountdownNotifier.shared.schedule(at: end, planned: planned)
            }
        }
    }

    func endTapped(context: ModelContext) {
        guard let active = timer.active else { return }
        stops += 1

        switch active.mode {
        case .stopwatch:
            let finished = active.finished(at: .now)
            if finished.isWorthKeeping {
                sessionToConfirm = finished
            } else {
                discardStopwatch()
            }

        case .countdown:
            // 提早結束：已經過的時間照樣存，不確認、不評論。寵物直接回到待機。
            CountdownNotifier.shared.cancel()
            LiveActivityController.end()
            if let finished = timer.end() {
                record(finished, context: context)
            }
        }
    }

    func saveConfirmed(_ session: FinishedSession, context: ModelContext) {
        sessionToConfirm = nil
        timer.clear()
        LiveActivityController.end()
        record(session, context: context)
    }

    func discardStopwatch() {
        sessionToConfirm = nil
        timer.clear()
        LiveActivityController.end()
    }

    // MARK: 倒數到期

    func waitForCountdownEnd(context: ModelContext) async {
        guard let end = timer.active?.plannedEnd else { return }
        let delay = end.timeIntervalSinceNow
        if delay > 0 {
            do {
                try await Task.sleep(for: .seconds(delay + 0.05))
            } catch {
                return
            }
        }
        finishExpiredCountdown(context: context)
    }

    /// App 啟動或回到前景。
    func sceneBecameActive(context: ModelContext) {
        timer.restore()
        if timer.isRunning {
            finishExpiredCountdown(context: context)
        } else {
            LiveActivityController.end()
        }
    }

    /// 倒數時間到：以「開始 + 預定時長」存檔，不跳確認視窗。
    /// 使用者在時間到之後才打開 app 也一樣。
    private func finishExpiredCountdown(context: ModelContext) {
        guard let finished = timer.completeIfExpired() else { return }
        CountdownNotifier.shared.cancel()
        LiveActivityController.end()
        record(finished, context: context)
        happySince = .now
        celebrations += 1
    }

    // MARK: 寵物

    func petTapped() {
        happySince = .now
        petTaps += 1
    }

    // MARK: 存檔

    /// 不到 1 分鐘的直接丟掉，不顯示任何訊息。
    private func record(_ finished: FinishedSession, context: ModelContext) {
        guard finished.isWorthKeeping else { return }

        let sessions = (try? context.fetch(FetchDescriptor<FocusSession>())) ?? []
        let before = Level(totalSeconds: sessions.reduce(0) { $0 + $1.duration })

        context.insert(FocusSession(
            startedAt: finished.startedAt,
            endedAt: finished.endedAt,
            tag: tag(withID: finished.tagID, context: context)
        ))
        try? context.save()

        let after = Level(totalSeconds: before.totalSeconds + finished.duration)
        if after.number > before.number {
            // 升級：寵物開心、Lv 閃兩下。不彈窗、不撒彩帶。
            happySince = .now
            levelFlashSince = .now
            celebrations += 1
        }
    }

    private func tag(withID id: UUID?, context: ModelContext) -> FocusTag? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<FocusTag>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
