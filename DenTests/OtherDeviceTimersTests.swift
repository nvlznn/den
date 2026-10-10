import Foundation
import Testing
@testable import Den

@MainActor
struct OtherDeviceTimersTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func ignoresThisDeviceAndStaleEntries() {
        let entries: [String: OtherDeviceTimers.Entry] = [
            "me": .init(model: "iPhone", startedAt: now.addingTimeInterval(-60)),
            "old": .init(model: "iPad", startedAt: now.addingTimeInterval(-OtherDeviceTimers.maxAge - 1)),
        ]
        #expect(OtherDeviceTimers.latestOther(in: entries, excluding: "me", at: now) == nil)
    }

    @Test func picksTheMostRecentlyStartedOtherDevice() {
        let entries: [String: OtherDeviceTimers.Entry] = [
            "me": .init(model: "iPhone", startedAt: now),
            "ipad": .init(model: "iPad", startedAt: now.addingTimeInterval(-600)),
            "phone2": .init(model: "iPhone", startedAt: now.addingTimeInterval(-60)),
        ]
        #expect(OtherDeviceTimers.latestOther(in: entries, excluding: "me", at: now)?.model == "iPhone")
    }
}
