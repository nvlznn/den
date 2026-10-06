import Foundation
import SwiftData

/// 預設標籤的建立與 iCloud 同步後的整理。
@MainActor
enum TagMaintenance {
    /// 記在 iCloud Key-Value 裡，刪掉 app 重裝也記得已經建過預設標籤。
    private static let seededKey = "didSeedTags"

    /// 第一次使用時放幾個預設標籤。回傳新建的第一個標籤，給畫面當作預設選擇。
    static func seedIfNeeded(context: ModelContext) -> FocusTag? {
        let cloud = NSUbiquitousKeyValueStore.default
        cloud.synchronize()
        let local = UserDefaults.standard
        guard !cloud.bool(forKey: seededKey), !local.bool(forKey: seededKey) else { return nil }

        cloud.set(true, forKey: seededKey)
        local.set(true, forKey: seededKey)

        let existing = (try? context.fetchCount(FetchDescriptor<FocusTag>())) ?? 0
        guard existing == 0 else { return nil }

        let tags = FocusTag.defaultNames.enumerated().map { FocusTag(name: $1, order: $0) }
        tags.forEach(context.insert)
        try? context.save()
        return tags.first
    }

    /// 同名的標籤合併成一個（例如重裝後 iCloud 還沒同步完就先建了預設標籤）。
    /// 留下順序最前面的那個，其他的紀錄改掛到它身上後刪除。
    /// 回傳被合併掉的標籤 id → 留下來的標籤 id。
    @discardableResult
    static func mergeDuplicates(context: ModelContext) -> [UUID: UUID] {
        let descriptor = FetchDescriptor<FocusTag>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.name)])
        guard let tags = try? context.fetch(descriptor) else { return [:] }

        var keepers: [String: FocusTag] = [:]
        var replaced: [UUID: UUID] = [:]
        for tag in tags {
            let key = tag.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let keeper = keepers[key] else {
                keepers[key] = tag
                continue
            }
            for session in tag.sessions ?? [] {
                session.tag = keeper
            }
            replaced[tag.id] = keeper.id
            context.delete(tag)
        }
        if !replaced.isEmpty {
            try? context.save()
        }
        return replaced
    }
}
