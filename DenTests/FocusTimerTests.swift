import Foundation
import Testing
@testable import Den

@MainActor
struct FocusTimerTests {
    let defaults: UserDefaults
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    init() {
        defaults = UserDefaults(suiteName: "FocusTimerTests-\(UUID().uuidString)")!
    }

    // MARK: 正計時

    @Test func stopwatchElapsedComesFromTimestamp() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.stopwatch, at: start)

        let active = try #require(timer.active)
        #expect(active.elapsed(at: start.addingTimeInterval(90)) == 90)
        #expect(active.displayedSeconds(at: start.addingTimeInterval(5025)) == 5025)
        #expect(active.plannedEnd == nil)
        #expect(!active.isExpired(at: start.addingTimeInterval(100_000)))
    }

    @Test func stopwatchSurvivesRelaunch() throws {
        FocusTimer(defaults: defaults).start(.stopwatch, at: start)

        // 新的 FocusTimer 等於 app 被砍掉後重新啟動。
        let relaunched = FocusTimer(defaults: defaults)
        let active = try #require(relaunched.active)
        #expect(active.startedAt == start)
        #expect(active.mode == .stopwatch)
        #expect(active.elapsed(at: start.addingTimeInterval(3600)) == 3600)
    }

    @Test func stopwatchEndUsesNow() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.stopwatch, at: start)

        let finished = try #require(timer.end(at: start.addingTimeInterval(8100)))
        #expect(finished.startedAt == start)
        #expect(finished.duration == 8100)
        #expect(timer.active == nil)
        #expect(FocusTimer(defaults: defaults).active == nil)
    }

    @Test func stopwatchNeverExpires() {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.stopwatch, at: start)
        #expect(timer.completeIfExpired(at: start.addingTimeInterval(1_000_000)) == nil)
        #expect(timer.isRunning)
    }

    @Test func shortenOnlyGoesDown() {
        let finished = FinishedSession(startedAt: start, endedAt: start.addingTimeInterval(7200))
        #expect(finished.shortened(to: 1800).duration == 1800)
        #expect(finished.shortened(to: 99_999).duration == 7200)
        #expect(finished.shortened(to: -5).duration == 0)
    }

    // MARK: 倒數

    @Test func countdownShowsRemaining() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.countdown(planned: 25 * 60), at: start)

        let active = try #require(timer.active)
        #expect(active.plannedEnd == start.addingTimeInterval(1500))
        #expect(active.displayedSeconds(at: start) == 1500)
        #expect(active.displayedSeconds(at: start.addingTimeInterval(1)) == 1499)
        #expect(active.displayedSeconds(at: start.addingTimeInterval(1499.5)) == 1)
        #expect(active.displayedSeconds(at: start.addingTimeInterval(1500)) == 0)
        #expect(active.displayedSeconds(at: start.addingTimeInterval(9999)) == 0)
    }

    @Test func countdownSurvivesRelaunch() throws {
        FocusTimer(defaults: defaults).start(.countdown(planned: 45 * 60), at: start)

        let relaunched = FocusTimer(defaults: defaults)
        let active = try #require(relaunched.active)
        #expect(active.mode == .countdown(planned: 2700))
        #expect(active.displayedSeconds(at: start.addingTimeInterval(600)) == 2100)
    }

    @Test func countdownNotExpiredBeforeEnd() {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.countdown(planned: 1500), at: start)
        #expect(timer.completeIfExpired(at: start.addingTimeInterval(1499)) == nil)
        #expect(timer.isRunning)
    }

    @Test func countdownCompletesAtPlannedEnd() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.countdown(planned: 1500), at: start)

        let finished = try #require(timer.completeIfExpired(at: start.addingTimeInterval(1500)))
        #expect(finished.endedAt == start.addingTimeInterval(1500))
        #expect(timer.active == nil)
    }

    /// 使用者在時間到之後才打開 app：照樣用「開始 + 預定時長」存檔，不用打開當下的時間。
    @Test func countdownOpenedLateSavesPlannedEnd() throws {
        FocusTimer(defaults: defaults).start(.countdown(planned: 1500), at: start)

        let openedTwoDaysLater = start.addingTimeInterval(2 * 24 * 3600)
        let relaunched = FocusTimer(defaults: defaults)
        let finished = try #require(relaunched.completeIfExpired(at: openedTwoDaysLater))

        #expect(finished.startedAt == start)
        #expect(finished.endedAt == start.addingTimeInterval(1500))
        #expect(finished.duration == 1500)
        #expect(FocusTimer(defaults: defaults).active == nil)
    }

    /// 提早結束：已經過的時間照樣算數。
    @Test func countdownEndedEarlyKeepsElapsed() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.countdown(planned: 1500), at: start)

        let finished = try #require(timer.end(at: start.addingTimeInterval(600)))
        #expect(finished.duration == 600)
        #expect(finished.isWorthKeeping)
    }

    @Test func countdownEndedAfterExpiryIsCapped() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.countdown(planned: 1500), at: start)

        let finished = try #require(timer.end(at: start.addingTimeInterval(4000)))
        #expect(finished.endedAt == start.addingTimeInterval(1500))
    }

    // MARK: 最短紀錄

    @Test func underOneMinuteIsDropped() {
        #expect(!FinishedSession(startedAt: start, endedAt: start.addingTimeInterval(59)).isWorthKeeping)
        #expect(FinishedSession(startedAt: start, endedAt: start.addingTimeInterval(60)).isWorthKeeping)
    }

    @Test func clearDiscards() {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.stopwatch, at: start)
        timer.clear()
        #expect(timer.active == nil)
        #expect(FocusTimer(defaults: defaults).active == nil)
    }

    @Test func tagSurvivesRelaunchAndEndsUpInRecord() throws {
        let tagID = UUID()
        FocusTimer(defaults: defaults).start(.countdown(planned: 1500), tagID: tagID, at: start)

        let relaunched = FocusTimer(defaults: defaults)
        #expect(relaunched.active?.tagID == tagID)
        let finished = try #require(relaunched.completeIfExpired(at: start.addingTimeInterval(9999)))
        #expect(finished.tagID == tagID)
        #expect(finished.shortened(to: 60).tagID == tagID)
    }

    /// 舊版存下、沒有 tagID 的計時也要讀得回來。
    @Test func decodesSessionSavedBeforeTags() throws {
        let json = #"{"startedAt": 800000000, "mode": {"stopwatch": {}}}"#
        defaults.set(Data(json.utf8), forKey: FocusTimer.storageKey)
        let active = try #require(FocusTimer(defaults: defaults).active)
        #expect(active.mode == .stopwatch)
        #expect(active.tagID == nil)
    }

    @Test func restorePicksUpChangesFromStorage() {
        let timer = FocusTimer(defaults: defaults)
        #expect(timer.active == nil)

        FocusTimer(defaults: defaults).start(.stopwatch, at: start)
        timer.restore()
        #expect(timer.active?.startedAt == start)
    }
}
