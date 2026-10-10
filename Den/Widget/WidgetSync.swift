import SwiftData
import SwiftUI
import WidgetKit

/// 把今天的專注摘要寫給 Widget，紀錄或角色一變就更新。掛在最外層，不管在哪個分頁都會執行。
struct WidgetSync: ViewModifier {
    @Query(sort: [SortDescriptor(\CharacterLibrary.createdAt), SortDescriptor(\CharacterLibrary.id)]) private var libraries: [CharacterLibrary]
    @Query private var sessions: [FocusSession]
    @AppStorage(DayBoundary.key, store: DayBoundary.store) private var dayStartHour = DayBoundary.defaultHour
    @AppStorage("characterID") private var characterID = PetSprites.defaultCharacterID

    func body(content: Content) -> some View {
        content.task(id: snapshot) {
            guard WidgetSnapshot.load() != snapshot else { return }
            snapshot.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// 和 Focus 頁的「Today」一樣：今天開始的紀錄都算（包含手動補的）；等級只算這隻角色、不含手動補的。
    private var snapshot: WidgetSnapshot {
        let boundary = DayBoundary(hour: dayStartHour)
        let today = sessions.filter { boundary.isSameDay($0.startedAt, .now) }
        let character = PetSprites.character(id: characterID)
        let level = Level(totalSeconds: Level.totalSeconds(
            of: character.id,
            defaultID: PetSprites.defaultCharacterID,
            in: sessions,
            characterOf: \.characterID,
            isManual: \.isManual,
            duration: \.duration
        ))
        return WidgetSnapshot(
            day: boundary.startOfDay(.now),
            todaySeconds: today.reduce(0) { $0 + $1.duration },
            todaySessions: today.count,
            characterID: libraries.first?.collection.displayID(for: character.id) ?? "egg",
            level: level.number,
            progressToNext: level.progressToNext,
            secondsToNext: level.secondsToNext
        )
    }
}

extension View {
    func syncsWidgets() -> some View {
        modifier(WidgetSync())
    }
}
