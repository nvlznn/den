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
        #expect(active.overtimeSeconds(at: start.addingTimeInterval(100_000)) == 0)
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

    /// 時間到了不會自動結束：計時繼續，超時的部分往上數。
    @Test func countdownKeepsRunningPastZero() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.countdown(planned: 1500), at: start)
        let active = try #require(timer.active)

        #expect(active.overtimeSeconds(at: start.addingTimeInterval(1499)) == 0)
        #expect(active.overtimeSeconds(at: start.addingTimeInterval(1500)) == 0)
        #expect(active.overtimeSeconds(at: start.addingTimeInterval(1500 + 136)) == 136)
        #expect(active.displayedSeconds(at: start.addingTimeInterval(1500 + 136)) == 0)
        #expect(active.elapsed(at: start.addingTimeInterval(1500 + 136)) == 1636)
        #expect(timer.isRunning)
    }

    /// 倒數時間到之後才回來，計時照樣還在，按 End 時總時間含超時。
    @Test func countdownOpenedLateKeepsRunningAndCountsEverything() throws {
        FocusTimer(defaults: defaults).start(.countdown(planned: 1500), at: start)

        let openedLater = start.addingTimeInterval(3 * 3600)
        let relaunched = FocusTimer(defaults: defaults)
        let active = try #require(relaunched.active)
        #expect(active.overtimeSeconds(at: openedLater) == 3 * 3600 - 1500)

        let finished = try #require(relaunched.end(at: openedLater))
        #expect(finished.startedAt == start)
        #expect(finished.duration == 3 * 3600)
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

    @Test func countdownEndedAfterExpiryCountsOvertime() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.countdown(planned: 1500), at: start)

        let finished = try #require(timer.end(at: start.addingTimeInterval(4000)))
        #expect(finished.endedAt == start.addingTimeInterval(4000))
        #expect(finished.duration == 4000)
    }

    // MARK: 暫停

    @Test func pauseFreezesElapsedAndResumeContinues() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.stopwatch, at: start)

        timer.pause(at: start.addingTimeInterval(600))
        var active = try #require(timer.active)
        #expect(active.isPaused)
        #expect(active.elapsed(at: start.addingTimeInterval(600)) == 600)
        #expect(active.elapsed(at: start.addingTimeInterval(5000)) == 600) // 暫停中不再增加

        timer.resume(at: start.addingTimeInterval(1800)) // 暫停了 1200 秒
        active = try #require(timer.active)
        #expect(!active.isPaused)
        #expect(active.elapsed(at: start.addingTimeInterval(1800)) == 600)
        #expect(active.elapsed(at: start.addingTimeInterval(2000)) == 800)
        #expect(active.pausedSeconds(at: start.addingTimeInterval(2000)) == 1200)
    }

    @Test func countdownEndShiftsByPausedTime() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.countdown(planned: 1500), at: start)
        timer.pause(at: start.addingTimeInterval(300))
        timer.resume(at: start.addingTimeInterval(900)) // 暫停 600 秒

        let active = try #require(timer.active)
        #expect(active.plannedEnd == start.addingTimeInterval(2100))
        #expect(active.displayedSeconds(at: start.addingTimeInterval(900)) == 1200)
        #expect(active.overtimeSeconds(at: start.addingTimeInterval(2100)) == 0)
        #expect(active.overtimeSeconds(at: start.addingTimeInterval(2160)) == 60)
        #expect(active.effectiveStart == start.addingTimeInterval(600))
    }

    @Test func pausedTimeIsNotSavedInRecord() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.stopwatch, at: start)
        timer.pause(at: start.addingTimeInterval(600))
        timer.resume(at: start.addingTimeInterval(1800))
        let finished = try #require(timer.end(at: start.addingTimeInterval(2400)))
        #expect(finished.duration == 1200) // 600 + 600，不含暫停的 1200
    }

    @Test func endingWhilePausedCountsUpToThePause() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.stopwatch, at: start)
        timer.pause(at: start.addingTimeInterval(900))
        let finished = try #require(timer.end(at: start.addingTimeInterval(9000)))
        #expect(finished.duration == 900)
    }

    @Test func pauseStateSurvivesRelaunch() throws {
        let first = FocusTimer(defaults: defaults)
        first.start(.countdown(planned: 1500), at: start)
        first.pause(at: start.addingTimeInterval(300))

        let relaunched = FocusTimer(defaults: defaults)
        let active = try #require(relaunched.active)
        #expect(active.isPaused)
        #expect(active.elapsed(at: start.addingTimeInterval(99_999)) == 300)
    }

    @Test func pauseAndResumeAreIdempotent() throws {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.stopwatch, at: start)
        timer.resume(at: start.addingTimeInterval(10)) // 沒在暫停，什麼都不做
        #expect(timer.active?.pausedTotal == nil)

        timer.pause(at: start.addingTimeInterval(100))
        timer.pause(at: start.addingTimeInterval(500)) // 已經在暫停，不重設起點
        #expect(timer.active?.pausedAt == start.addingTimeInterval(100))
    }

    // MARK: 最短紀錄

    @Test func underFifteenSecondsIsDropped() {
        #expect(!FinishedSession(startedAt: start, endedAt: start.addingTimeInterval(14)).isWorthKeeping)
        #expect(FinishedSession(startedAt: start, endedAt: start.addingTimeInterval(15)).isWorthKeeping)
        #expect(FinishedSession(startedAt: start, endedAt: start.addingTimeInterval(16)).isWorthKeeping)
    }

    @Test func clearDiscards() {
        let timer = FocusTimer(defaults: defaults)
        timer.start(.stopwatch, at: start)
        timer.clear()
        #expect(timer.active == nil)
        #expect(FocusTimer(defaults: defaults).active == nil)
    }

    @Test func tagAndCharacterSurviveRelaunchAndEndUpInRecord() throws {
        let tagID = UUID()
        FocusTimer(defaults: defaults).start(.countdown(planned: 1500), tagID: tagID, characterID: "orb", at: start)

        let relaunched = FocusTimer(defaults: defaults)
        #expect(relaunched.active?.tagID == tagID)
        #expect(relaunched.active?.characterID == "orb")
        let finished = try #require(relaunched.end(at: start.addingTimeInterval(9999)))
        #expect(finished.tagID == tagID)
        #expect(finished.characterID == "orb")
        #expect(finished.shortened(to: 60).characterID == "orb")
    }

    @Test func changingTagMidSessionKeepsTheLastTagInRecord() throws {
        let first = UUID(), second = UUID()
        let timer = FocusTimer(defaults: defaults)
        timer.start(.stopwatch, tagID: first, characterID: "orb", at: start)
        timer.setTag(second)

        let relaunched = FocusTimer(defaults: defaults)
        #expect(relaunched.active?.tagID == second)
        #expect(relaunched.active?.startedAt == start)
        let finished = try #require(relaunched.end(at: start.addingTimeInterval(600)))
        #expect(finished.tagID == second)
        #expect(finished.characterID == "orb")
    }

    /// 舊版存下、沒有 tagID 的計時也要讀得回來。
    @Test func decodesSessionSavedBeforeTags() throws {
        let json = #"{"startedAt": 800000000, "mode": {"stopwatch": {}}}"#
        defaults.set(Data(json.utf8), forKey: FocusTimer.storageKey)
        let active = try #require(FocusTimer(defaults: defaults).active)
        #expect(active.mode == .stopwatch)
        #expect(active.tagID == nil)
        #expect(active.characterID == nil)
    }

    @Test func restorePicksUpChangesFromStorage() {
        let timer = FocusTimer(defaults: defaults)
        #expect(timer.active == nil)

        FocusTimer(defaults: defaults).start(.stopwatch, at: start)
        timer.restore()
        #expect(timer.active?.startedAt == start)
    }
}
