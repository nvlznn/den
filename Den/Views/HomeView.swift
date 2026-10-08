import SwiftData
import SwiftUI

/// 「專注」分頁：上面是 LCD，下面是今天的累積與專注設定。
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusController.self) private var controller
    @Query(sort: [SortDescriptor(\CharacterLibrary.createdAt), SortDescriptor(\CharacterLibrary.id)]) private var libraries: [CharacterLibrary]
    @Query private var sessions: [FocusSession]
    @Query(sort: \FocusTag.order) private var tags: [FocusTag]

    @AppStorage("focusMinutes") private var focusMinutes = 25
    @AppStorage("selectedTagID") private var selectedTagID = ""
    @AppStorage("characterID") private var characterID = PetSprites.defaultCharacterID

    @State private var isChoosingCharacter = false
    @State private var isChoosingTag = false
    @State private var isChoosingDuration = false

    private var timer: FocusTimer { controller.timer }

    /// 計時中顯示開始時的那隻；平常顯示目前選的那隻。
    private var character: PetCharacter {
        PetSprites.character(id: timer.active?.characterID ?? characterID)
    }

    private var displayedCharacter: PetCharacter {
        let id = libraries.first?.collection.displayID(for: character.id) ?? "egg"
        return PetSprites.character(id: id)
    }

    /// 每個角色的等級各自計算。專注中也把正在進行的這一段算進去，所以會每秒跟著變。
    private func level(at date: Date) -> Level {
        let saved = Level.totalSeconds(
            of: character.id,
            defaultID: PetSprites.defaultCharacterID,
            in: sessions,
            characterOf: \.characterID,
            isManual: \.isManual,
            duration: \.duration
        )
        return Level(totalSeconds: saved + (timer.active?.elapsed(at: date) ?? 0))
    }

    /// 一定有一個標籤：沒選或選的已經被刪掉時，用第一個。
    private var selectedTag: FocusTag? {
        tags.first { $0.id.uuidString == selectedTagID } ?? tags.first
    }

    private var today: (count: Int, duration: TimeInterval) {
        let calendar = Calendar.current
        let todays = sessions.filter { calendar.isDateInToday($0.startedAt) }
        return (todays.count, todays.reduce(0) { $0 + $1.duration })
    }

    var body: some View {
        List {
            Section {
                // 每秒更新一次，專注中的 Lv 才會即時變化。TimelineView 放在內容裡，
                // 不要包住整個 Section，不然 List 會把進度條和文字整個框進灰色的卡片。
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    LCDScreenView(
                        character: displayedCharacter,
                        level: level(at: context.date).number,
                        pet: PetState(isTiming: timer.isRunning, happySince: controller.happySince),
                        levelFlashSince: nil,
                        onPetTap: controller.petTapped
                    )
                    .onChange(of: level(at: context.date).number, initial: true) { _, number in
                        guard number >= 1 else { return }
                        controller.hatchActiveEgg(totalSeconds: level(at: context.date).totalSeconds, context: modelContext)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                // 進度條和剩餘時間也每秒更新。
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    levelProgress(level(at: context.date))
                }
            }

            if let active = timer.active {
                Section {
                    RunningTime(session: active, tagName: tagName(for: active)) {
                        isChoosingTag = true
                    }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            } else {
                Section("Today") {
                    LabeledContent("Sessions", value: "\(today.count)")
                    LabeledContent("Time", value: DurationText.hoursAndMinutes(today.duration))
                }

                Section("Focus") {
                    SettingRow(title: "Character", value: displayedCharacter.name) {
                        isChoosingCharacter = true
                    }
                    SettingRow(title: "Tag", value: selectedTag?.name ?? "–") {
                        isChoosingTag = true
                    }
                    SettingRow(title: "Duration", value: DurationSheet.rowLabel(focusMinutes)) {
                        isChoosingDuration = true
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            primaryButton
                .padding(.bottom, 8)
        }
        .animation(.default, value: timer.isRunning)
        .sheet(isPresented: $isChoosingCharacter) {
            CharacterSheet(characterID: $characterID)
        }
        .sheet(isPresented: $isChoosingTag) {
            TagSheet(selectedTagID: tagSelection)
        }
        .sheet(isPresented: $isChoosingDuration) {
            DurationSheet(minutes: $focusMinutes)
        }
    }

    private func levelProgress(_ level: Level) -> some View {
        // 剩下的時間無條件進位到分鐘，避免最後一分鐘顯示「0 min」。
        let minutesLeft = (level.secondsToNext / 60).rounded(.up) * 60
        let timeLeft = DurationText.hoursAndMinutes(minutesLeft)

        return VStack(alignment: .leading, spacing: 8) {
            SegmentedProgressBar(progress: level.progressToNext)
                .frame(height: 18)
            Text(displayedCharacter.isEgg ? String(localized: "\(timeLeft) to hatch") : String(localized: "\(timeLeft) to Lv \(level.number + 1)"))
        }
        .padding(.top, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress to Lv \(level.number + 1)")
        .accessibilityValue("Focus \(timeLeft) more to evolve")
    }

    @ViewBuilder
    private var primaryButton: some View {
        if timer.isRunning {
            let isPaused = timer.active?.isPaused ?? false
            HStack(spacing: 12) {
                // 暫停 ⏸ / 繼續 ▶。暫停時大數字變灰。
                Button {
                    controller.togglePause()
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.title3.weight(.semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.extraLarge)
                .background(Color(.systemBackground), in: Circle())
                .accessibilityLabel(isPaused ? String(localized: "Resume") : String(localized: "Pause"))

                // 結束不是破壞性操作，用次要樣式，不用紅色。
                Button {
                    controller.endTapped(context: modelContext)
                } label: {
                    Text("End")
                        .fontWeight(.bold)
                        .padding(.horizontal, 48)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .background(Color(.systemBackground), in: Capsule())
            }
        } else {
            Button {
                controller.start(focusMinutes: focusMinutes, tag: selectedTag, character: character, displayCharacterID: displayedCharacter.id)
            } label: {
                Text("Start")
                    .fontWeight(.bold)
                    .padding(.horizontal, 48)
            }
            .disabled(libraries.first == nil || libraries.first?.collection.needsFirstEgg == true)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
        }
    }

    /// 專注中選標籤是換進行中計時的標籤，同時記成下次的預設；沒在專注就只是改預設。
    private var tagSelection: Binding<String> {
        Binding {
            timer.active?.tagID?.uuidString ?? selectedTagID
        } set: { newID in
            selectedTagID = newID
            if timer.isRunning {
                controller.changeTag(to: tags.first { $0.id.uuidString == newID })
            }
        }
    }

    private func tagName(for session: ActiveSession) -> String? {
        guard let id = session.tagID else { return nil }
        return tags.first { $0.id == id }?.name
    }
}

/// 外框裡一格一格填滿的進度條，像老式的 loading bar。
private struct SegmentedProgressBar: View {
    static let segments = 20

    let progress: Double

    var body: some View {
        // 每一格代表 10 / 20 小時；進行中的那一格依比例部分填滿，所以每分鐘都看得到變化。
        let position = min(max(progress, 0), 1) * Double(Self.segments)
        HStack(spacing: 2) {
            ForEach(0..<Self.segments, id: \.self) { index in
                let fill = min(max(position - Double(index), 0), 1)
                Rectangle()
                    .fill(Color.clear)
                    .overlay(alignment: .leading) {
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Color.secondary)
                                .frame(width: geometry.size.width * fill)
                        }
                    }
            }
        }
        .padding(4)
        .overlay {
            Rectangle()
                .strokeBorder(Color.secondary, lineWidth: 2)
        }
    }
}

/// 「名稱　值 ›」的設定列，點了開 sheet。
private struct SettingRow: View {
    let title: LocalizedStringKey
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                // 用具體的 Color；`.primary` 這類樣式在 List 的按鈕裡會被換成 tint 色。
                Text(title)
                    .foregroundStyle(Color.primary)
                Spacer()
                Text(value)
                    .foregroundStyle(Color.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityAddTraits(.isButton)
    }
}

/// 專注中的大數字。正計時顯示經過時間，倒數顯示剩餘時間。
private struct RunningTime: View {
    let session: ActiveSession
    let tagName: String?
    /// 點標籤名字：專注中換標籤，紀錄歸在結束時的標籤。
    let onTagTap: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = 76

    var body: some View {
        VStack(spacing: 4) {
            TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                let seconds = session.displayedSeconds(at: context.date)
                let overtime = session.overtimeSeconds(at: context.date)
                // 倒數到了之後只剩一個大數字：從 +0:00 開始往上數超時的部分。
                // 暫停時數字變灰，讓人知道計時停著。
                Text(overtime > 0 ? "+\(DurationText.clock(overtime))" : DurationText.clock(seconds))
                    .font(.system(size: fontSize, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(session.isPaused ? Color.secondary : Color.primary)
                    .accessibilityLabel(accessibilityText(seconds, overtime: overtime))
            }
            Button(action: onTagTap) {
                Text(tagName ?? "–")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Tag, \(tagName ?? String(localized: "none"))"))
            .accessibilityHint("Change tag")
        }
        .padding(.top, 32)
    }

    private func accessibilityText(_ seconds: Int, overtime: Int) -> String {
        if session.isPaused { return String(localized: "Paused, \(DurationText.hoursAndMinutes(TimeInterval(session.plannedEnd == nil ? seconds : max(seconds, overtime))))") }
        let text = DurationText.hoursAndMinutes(TimeInterval(seconds))
        if session.plannedEnd == nil { return String(localized: "Focused for \(text)") }
        if overtime > 0 { return String(localized: "Time is up, \(DurationText.hoursAndMinutes(TimeInterval(overtime))) over") }
        return String(localized: "\(text) left")
    }
}

#Preview {
    HomeView()
        .environment(FocusController(timer: FocusTimer(defaults: UserDefaults(suiteName: "preview")!)))
        .modelContainer(for: [FocusSession.self, FocusTag.self], inMemory: true)
}
