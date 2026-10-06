import SwiftData
import SwiftUI

/// 「專注」分頁：上面是 LCD，下面是今天的累積與專注設定。
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusController.self) private var controller
    @Query private var sessions: [FocusSession]
    @Query(sort: \FocusTag.order) private var tags: [FocusTag]

    @AppStorage("focusMinutes") private var focusMinutes = 25
    @AppStorage("selectedTagID") private var selectedTagID = ""

    @State private var isChoosingTag = false
    @State private var isChoosingDuration = false

    private var timer: FocusTimer { controller.timer }

    private var level: Level {
        Level(totalSeconds: sessions.reduce(0) { $0 + $1.duration })
    }

    private var selectedTag: FocusTag? {
        tags.first { $0.id.uuidString == selectedTagID }
    }

    private var today: (count: Int, duration: TimeInterval) {
        let calendar = Calendar.current
        let todays = sessions.filter { calendar.isDateInToday($0.startedAt) }
        return (todays.count, todays.reduce(0) { $0 + $1.duration })
    }

    var body: some View {
        List {
            Section {
                LCDScreenView(
                    level: level.number,
                    pet: PetState(isTiming: timer.isRunning, happySince: controller.happySince),
                    levelFlashSince: controller.levelFlashSince,
                    onPetTap: controller.petTapped
                )
                .aspectRatio(1, contentMode: .fit)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                if !timer.isRunning {
                    levelProgress
                }
            }

            if let active = timer.active {
                Section {
                    RunningTime(session: active, tagName: tagName(for: active))
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            } else {
                Section("今天") {
                    LabeledContent("專注次數", value: "\(today.count)")
                    LabeledContent("專注時長", value: DurationText.hoursAndMinutes(today.duration))
                }

                Section("專注設定") {
                    SettingRow(title: "專注標籤", value: selectedTag?.name ?? "無") {
                        isChoosingTag = true
                    }
                    SettingRow(title: "專注時長", value: DurationSheet.rowLabel(focusMinutes)) {
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
        .sheet(isPresented: $isChoosingTag) {
            TagSheet(selectedTagID: $selectedTagID)
        }
        .sheet(isPresented: $isChoosingDuration) {
            DurationSheet(minutes: $focusMinutes)
        }
    }

    private var levelProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: level.progressToNext)
                .accessibilityLabel("距離 Lv \(level.number + 1) 的進度")
            Text("累積 \(DurationText.hoursAndMinutes(level.totalSeconds))")
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var primaryButton: some View {
        if timer.isRunning {
            // 結束不是破壞性操作，用次要樣式，不用紅色。
            Button {
                controller.endTapped(context: modelContext)
            } label: {
                Text("結束")
                    .padding(.horizontal, 48)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
            .background(Color(.systemBackground), in: Capsule())
        } else {
            Button {
                controller.start(focusMinutes: focusMinutes, tag: selectedTag)
            } label: {
                Text("開始專注")
                    .padding(.horizontal, 48)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
        }
    }

    private func tagName(for session: ActiveSession) -> String? {
        guard let id = session.tagID else { return nil }
        return tags.first { $0.id == id }?.name
    }
}

/// 「名稱　值 ›」的設定列，點了開 sheet。
private struct SettingRow: View {
    let title: String
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

    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = 76

    var body: some View {
        VStack(spacing: 4) {
            TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                let seconds = session.displayedSeconds(at: context.date)
                Text(DurationText.clock(seconds))
                    .font(.system(size: fontSize, weight: .light))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .accessibilityLabel(accessibilityText(seconds))
            }
            if let tagName {
                Label(tagName, systemImage: "tag.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func accessibilityText(_ seconds: Int) -> String {
        let text = DurationText.hoursAndMinutes(TimeInterval(seconds))
        return session.plannedEnd == nil ? "已專注 \(text)" : "還剩 \(text)"
    }
}

#Preview {
    HomeView()
        .environment(FocusController(timer: FocusTimer(defaults: UserDefaults(suiteName: "preview")!)))
        .modelContainer(for: [FocusSession.self, FocusTag.self], inMemory: true)
}
