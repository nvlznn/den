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
    /// 專注結束後要顯示的慶祝畫面。
    var celebration: Celebration?

    // Haptic 觸發器
    private(set) var petTaps = 0
    private(set) var celebrations = 0
    private(set) var starts = 0
    private(set) var stops = 0

    init(timer: FocusTimer) {
        self.timer = timer
    }

    // MARK: 開始與結束

    func start(focusMinutes: Int, tag: FocusTag?, character: PetCharacter) {
        let mode = TimerMode(focusMinutes: focusMinutes)
        timer.start(mode, tagID: tag?.id, characterID: character.id)
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

        // 倒數提早結束，已經過的時間照樣存；正計時也直接存。
        CountdownNotifier.shared.cancel()
        LiveActivityController.end()
        if let finished = timer.end(at: .now) {
            record(finished, context: context)
        }
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
    }

    // MARK: 寵物

    func petTapped() {
        happySince = .now
        petTaps += 1
    }

    // MARK: 存檔

    /// 不到 1 分鐘的直接丟掉，不顯示任何畫面。存好之後顯示慶祝畫面。
    private func record(_ finished: FinishedSession, context: ModelContext) {
        guard finished.isWorthKeeping else { return }

        // 每個角色的等級各自計算，升級也只看這一隻。
        let characterID = finished.characterID ?? PetSprites.defaultCharacterID
        let sessions = (try? context.fetch(FetchDescriptor<FocusSession>())) ?? []
        let before = Level(totalSeconds: Level.totalSeconds(
            of: characterID,
            defaultID: PetSprites.defaultCharacterID,
            in: sessions,
            characterOf: \.characterID,
            isManual: \.isManual,
            duration: \.duration
        ))

        context.insert(FocusSession(
            startedAt: finished.startedAt,
            endedAt: finished.endedAt,
            tag: tag(withID: finished.tagID, context: context),
            characterID: characterID
        ))
        try? context.save()

        let after = Level(totalSeconds: before.totalSeconds + finished.duration)
        celebration = Celebration(
            characterID: characterID,
            duration: finished.duration,
            levelBefore: before.number,
            levelAfter: after.number,
            characterName: PetSprites.character(id: characterID).name
        )
        celebrations += 1
    }

    private func tag(withID id: UUID?, context: ModelContext) -> FocusTag? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<FocusTag>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
