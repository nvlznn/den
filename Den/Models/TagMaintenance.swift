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

    /// 順序最前面的標籤；一個都沒有就建一個「Study」。每筆紀錄都一定要有標籤，所以存檔前用它補底。
    static func fallbackTag(context: ModelContext) -> FocusTag {
        let descriptor = FetchDescriptor<FocusTag>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.name)])
        if let first = (try? context.fetch(descriptor))?.first {
            return first
        }
        let tag = FocusTag(name: FocusTag.defaultNames[0], order: 0)
        context.insert(tag)
        return tag
    }

    /// 刪掉標籤。底下的紀錄不搬走，改成記住原本的標籤名稱，所以在紀錄和統計裡仍然顯示原名。
    /// 至少要留一個標籤：只剩一個時什麼都不做、回傳 nil。成功時回傳剩下的第一個標籤，
    /// 給「目前選的標籤就是被刪掉的那個」時改選用。
    @discardableResult
    static func delete(_ tag: FocusTag, context: ModelContext) -> FocusTag? {
        let descriptor = FetchDescriptor<FocusTag>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.name)])
        guard let next = (try? context.fetch(descriptor))?.first(where: { $0.id != tag.id }) else { return nil }
        for session in tag.sessions ?? [] {
            session.tagName = tag.name
            session.tag = nil
        }
        context.delete(tag)
        try? context.save()
        return next
    }

    /// 標籤被刪掉的紀錄（孤兒）只記得原本的名字。有同名的標籤時，這些紀錄就歸到它底下。
    /// 新增標籤、改名、或 iCloud 同步進新標籤之後都會呼叫。
    static func adoptOrphans(context: ModelContext) {
        let tagDescriptor = FetchDescriptor<FocusTag>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.name)])
        guard let tags = try? context.fetch(tagDescriptor), !tags.isEmpty else { return }

        var byName: [String: FocusTag] = [:]
        for tag in tags where byName[normalized(tag.name)] == nil {
            byName[normalized(tag.name)] = tag
        }

        let orphanDescriptor = FetchDescriptor<FocusSession>(predicate: #Predicate { $0.tag == nil })
        guard let orphans = try? context.fetch(orphanDescriptor) else { return }

        var changed = false
        for session in orphans {
            guard let name = session.tagName, let tag = byName[normalized(name)] else { continue }
            session.tag = tag
            session.tagName = tag.name
            changed = true
        }
        if changed {
            try? context.save()
        }
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
                session.tagName = keeper.name
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
