import Foundation

/// 等級改成所有角色共用之後，提示一次「Levels Are Now Shared」。
/// 只給從舊版更新上來、而且兩隻以上的角色陪過專注（等級真的變了）的人；每台裝置最多一次。
enum SharedLevelNotice {
    static let key = "sharedLevelNotice"
    private static let pending = "pending"
    private static let done = "done"

    /// 要在 app 寫入任何設定之前呼叫。`onboardingGuidePending` 只有在這台裝置上選過第一顆蛋才會存在，
    /// 而且不會從 iCloud 同步進來，所以新安裝、換新手機的人都不會看到提示。
    static func prepare(defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: key) == nil else { return }
        let isUpdate = defaults.object(forKey: "onboardingGuidePending") != nil
        defaults.set(isUpdate ? pending : done, forKey: key)
    }

    static func isPending(defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: key) == pending
    }

    static func markDone(defaults: UserDefaults = .standard) {
        defaults.set(done, forKey: key)
    }

    /// 只陪過一隻角色的人，等級和以前一樣，不用提示。
    static func levelChanged(totals: [String: TimeInterval]) -> Bool {
        totals.values.filter { $0 > 0 }.count >= 2
    }
}
