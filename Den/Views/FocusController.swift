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
    /// 其他裝置的計時狀態；這台的狀態一變就寫上去。
    let otherDevices: OtherDeviceTimers

    var happySince: Date?
    /// 專注結束後要顯示的慶祝畫面。
    var celebration: Celebration?

    // Haptic 觸發器
    private(set) var petTaps = 0
    private(set) var celebrations = 0
    private(set) var starts = 0
    private(set) var stops = 0
    private(set) var pauseToggles = 0

    init(timer: FocusTimer, otherDevices: OtherDeviceTimers = OtherDeviceTimers()) {
        self.timer = timer
        self.otherDevices = otherDevices
    }

    // MARK: 開始與結束

    func start(focusMinutes: Int, tag: FocusTag?, character: PetCharacter, displayCharacterID: String? = nil) {
        let mode = TimerMode(focusMinutes: focusMinutes)
        timer.start(mode, tagID: tag?.id, characterID: character.id)
        starts += 1
        otherDevices.publish(timer.active)

        guard let active = timer.active else { return }
        LiveActivityController.start(for: active, tagName: tag?.name, displayCharacterID: displayCharacterID)
        if case .countdown(let planned) = mode, let end = active.plannedEnd {
            Task {
                await CountdownNotifier.shared.schedule(at: end, planned: planned)
            }
        }
    }

    /// 專注中換標籤，紀錄會歸在最後選的標籤。
    func changeTag(to tag: FocusTag?) {
        guard timer.active != nil else { return }
        timer.setTag(tag?.id)
        if let active = timer.active {
            LiveActivityController.update(for: active, tagName: tag?.name)
        }
    }

    /// 暫停或繼續。暫停時取消倒數的通知（時間凍結了），繼續時依剩餘時間重新排。
    func togglePause() {
        guard let active = timer.active else { return }
        pauseToggles += 1

        if active.isPaused {
            timer.resume()
            guard let resumed = timer.active else { return }
            LiveActivityController.update(for: resumed)
            if case .countdown(let planned) = resumed.mode, let end = resumed.plannedEnd, end > .now {
                Task {
                    await CountdownNotifier.shared.schedule(at: end, planned: planned)
                }
            }
        } else {
            timer.pause()
            CountdownNotifier.shared.cancel()
            if let paused = timer.active {
                LiveActivityController.update(for: paused)
            }
        }
    }

    func endTapped(context: ModelContext) {
        guard timer.active != nil else { return }
        stops += 1

        // 不管提早結束、剛好到、還是超時，已經過的時間都照樣存。
        CountdownNotifier.shared.cancel()
        LiveActivityController.end()
        let finished = timer.end(at: .now)
        otherDevices.publish(nil)
        if let finished {
            record(finished, context: context)
        }
    }

    /// 放棄這次專注：不留下任何紀錄，也不顯示慶祝畫面。
    func abort() {
        guard timer.active != nil else { return }
        stops += 1
        CountdownNotifier.shared.cancel()
        LiveActivityController.end()
        timer.clear()
        otherDevices.publish(nil)
    }

    /// App 啟動或回到前景。倒數時間到了不會自動結束，只有使用者按 End 才結束。
    func sceneBecameActive() {
        timer.restore()
        // 修正上次沒寫到的狀態（例如計時中 app 被砍掉），順便拉一次別台的。
        otherDevices.publish(timer.active)
        otherDevices.reload()
        if !timer.isRunning {
            LiveActivityController.end()
        }
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

        // 兩台裝置同時計時時，已經同步進來的紀錄是完整的，這一筆只填剩下的空檔。
        let taken = sessions.filter { !$0.isManual && $0.endedAt > $0.startedAt }
            .map { DateInterval(start: $0.startedAt, end: $0.endedAt) }
        let pieces = finished.fillingGaps(around: taken)
        guard !pieces.isEmpty else { return }
        let duration = pieces.reduce(0) { $0 + $1.duration }
        let before = Level(totalSeconds: Level.totalSeconds(
            of: characterID,
            defaultID: PetSprites.defaultCharacterID,
            in: sessions,
            characterOf: \.characterID,
            isManual: \.isManual,
            duration: \.duration
        ))

        // 標籤被刪掉了或找不到時，補第一個，每筆紀錄一定要有標籤。
        let sessionTag = tag(withID: finished.tagID, context: context) ?? TagMaintenance.fallbackTag(context: context)
        for piece in pieces {
            let record = FocusSession(
                startedAt: piece.startedAt,
                endedAt: piece.endedAt,
                tag: sessionTag,
                characterID: characterID
            )
            context.insert(record)
            FocusContribution.capture(record, context: context)
        }
        try? context.save()

        let after = Level(totalSeconds: before.totalSeconds + duration)
        var didHatch = false
        var displayID = "egg"
        var name = PetSprites.character(id: displayID).name
        if let library = CharacterLibrary.current(in: context) {
            var collection = library.collection
            // 專注中滿 5 小時也不會先孵，按 End 才孵。
            didHatch = collection.hatch(characterID, totalSeconds: after.totalSeconds)
            library.collection = collection
            try? context.save()
            displayID = collection.displayID(for: characterID)
            name = collection.name(for: characterID)
        }
        celebration = Celebration(
            characterID: displayID,
            duration: duration,
            levelBefore: before.number,
            levelAfter: after.number,
            characterName: name,
            didHatch: didHatch
        )
        celebrations += 1
    }

    /// 關掉慶祝畫面。剛孵化的話順便存使用者取的名字（nil 就是沒取，維持原名）。
    func finishCelebration(naming name: String?, context: ModelContext) {
        defer { celebration = nil }
        guard let celebration, celebration.didHatch, let name,
              let library = CharacterLibrary.current(in: context) else { return }
        var collection = library.collection
        collection.rename(celebration.characterID, to: name)
        library.collection = collection
        try? context.save()
    }

    private func tag(withID id: UUID?, context: ModelContext) -> FocusTag? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<FocusTag>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
