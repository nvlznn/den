import Foundation
import Observation

/// 一段進行中的計時。所有時間都由 `startedAt` 推算，不依賴累加的 Timer，
/// 所以 app 被系統砍掉或手機重開後，回來時間依然正確。
struct ActiveSession: Codable, Hashable, Sendable {
    let startedAt: Date
    let mode: TimerMode
    /// 開始時選的標籤。
    var tagID: UUID?
    /// 開始時陪著的角色。
    var characterID: String?

    /// 倒數的預定結束時間；正計時沒有。
    var plannedEnd: Date? {
        guard case .countdown(let planned) = mode else { return nil }
        return startedAt.addingTimeInterval(planned)
    }

    /// 已經過的時間。倒數時間到了之後仍然繼續計，直到使用者按結束。
    func elapsed(at now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(startedAt))
    }

    /// 畫面上顯示的整數秒：正計時是經過時間，倒數是剩餘時間（到 0 為止）。
    func displayedSeconds(at now: Date) -> Int {
        let elapsedSeconds = Int(elapsed(at: now))
        guard case .countdown(let planned) = mode else { return elapsedSeconds }
        return max(0, Int(planned.rounded()) - elapsedSeconds)
    }

    /// 倒數時間到之後多專注了幾秒；還沒到或是正計時就是 0。
    func overtimeSeconds(at now: Date) -> Int {
        guard case .countdown(let planned) = mode else { return 0 }
        return max(0, Int(elapsed(at: now)) - Int(planned.rounded()))
    }

    /// 在 `now` 結束時會留下的紀錄，包含倒數時間到之後多專注的時間。
    func finished(at now: Date) -> FinishedSession {
        FinishedSession(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(elapsed(at: now)),
            tagID: tagID,
            characterID: characterID
        )
    }
}

/// 一段已結束、準備存檔的專注。
struct FinishedSession: Hashable, Sendable {
    /// 不到 15 秒的紀錄直接丟掉。
    static let minimumDuration: TimeInterval = 15

    let startedAt: Date
    let endedAt: Date
    var tagID: UUID?
    var characterID: String?

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    var isWorthKeeping: Bool { duration >= Self.minimumDuration }

    /// 把時長往下修正（忘記按結束、睡著了）。不能往上調。
    func shortened(to newDuration: TimeInterval) -> FinishedSession {
        let clamped = min(max(0, newDuration), duration)
        return FinishedSession(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(clamped),
            tagID: tagID,
            characterID: characterID
        )
    }
}

/// 進行中計時的狀態。開始時寫入 `UserDefaults`，啟動與回到前景時還原。
@MainActor
@Observable
final class FocusTimer {
    static let storageKey = "activeSession"

    private(set) var active: ActiveSession?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
    }

    var isRunning: Bool { active != nil }

    /// 從 `UserDefaults` 讀回未結束的計時。
    func restore() {
        let stored = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(ActiveSession.self, from: $0) }
        if stored != active {
            active = stored
        }
    }

    func start(_ mode: TimerMode, tagID: UUID? = nil, characterID: String? = nil, at now: Date = .now) {
        let session = ActiveSession(startedAt: now, mode: mode, tagID: tagID, characterID: characterID)
        active = session
        defaults.set(try? JSONEncoder().encode(session), forKey: Self.storageKey)
    }

    /// 使用者按下結束。已經過的時間（含倒數之後的超時）照樣算數。
    func end(at now: Date = .now) -> FinishedSession? {
        guard let active else { return nil }
        clear()
        return active.finished(at: now)
    }

    /// 丟掉進行中的計時，不留下紀錄。
    func clear() {
        active = nil
        defaults.removeObject(forKey: Self.storageKey)
    }
}
