import SwiftData
import SwiftUI

/// 「紀錄」分頁：一次看一週，依日分組。
struct RecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var sessions: [FocusSession]

    @State private var range = StatsRange(period: .week, containing: .now)
    @State private var isAdding = false
    @State private var editing: FocusSession?

    private var days: [DayGroup<FocusSession>] {
        RecordGrouping.days(sessions, in: range.interval, startedAt: \.startedAt, duration: \.duration)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    periodNavigator
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if days.isEmpty {
                    ContentUnavailableView("No Records", systemImage: "book.closed")
                        .listRowBackground(Color.clear)
                }

                ForEach(days) { day in
                    Section {
                        ForEach(day.items) { session in
                            // 用點擊手勢而不是 Button：Button 會把刪除時的點擊也接走，編輯頁就跳出來了。
                            RecordRow(session: session)
                                .onTapGesture {
                                    editing = session
                                }
                                .accessibilityAddTraits(.isButton)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(session)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        DayHeader(day: day)
                    }
                }
            }
            .navigationTitle("Records")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAdding = true
                    } label: {
                        Label("Add Record", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                RecordSheet()
            }
            .sheet(item: $editing) { session in
                RecordSheet(editing: session)
            }
        }
    }

    /// 直接刪掉，不開任何畫面。
    private func delete(_ session: FocusSession) {
        if editing == session {
            editing = nil
        }
        modelContext.delete(session)
        try? modelContext.save()
    }

    private var periodNavigator: some View {
        HStack {
            Button {
                range = range.shifted(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Color.primary)
            }
            .accessibilityLabel("Previous Period")

            Spacer()

            Text(StatsFormat.rangeTitle(range))
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Spacer()

            Button {
                range = range.shifted(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.primary)
            }
            .accessibilityLabel("Next Period")
            .disabled(range.interval.end > .now)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .padding(.vertical, 4)
    }
}

private struct DayHeader: View {
    let day: DayGroup<FocusSession>

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // 不指定字級，跟 Focus 頁的「Today」、「Focus Settings」一樣用系統預設的區段標題樣式。
            Text(RecordFormat.day(day.day))
                .fontWeight(.semibold)
            Text("\(DurationText.hoursAndMinutes(day.totalDuration)), \(RecordFormat.sessions(day.count))")
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }
}

private struct RecordRow: View {
    let session: FocusSession

    var body: some View {
        // 字級跟 Focus 頁的列一樣（系統預設的 body），不自己指定大小。
        HStack(spacing: 12) {
            // 手動補的用鉛筆，和計時的沙漏區分。
            Image(systemName: session.isManual ? "pencil" : "hourglass")
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(session.displayTagName)
                    .foregroundStyle(Color.primary)
                Text(session.isManual ? String(localized: "\(RecordFormat.time(session.startedAt)) · Added manually") : RecordFormat.time(session.startedAt))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Text(DurationText.clock(Int(session.duration)))
                .monospacedDigit()
                .foregroundStyle(.tint)
                .accessibilityLabel(DurationText.hoursAndMinutes(session.duration))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit record")
    }
}

/// 紀錄頁的日期格式。
enum RecordFormat {
    private static func formatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private static let timeFormatter = formatter("Hm")
    private static let monthDayFormatter = formatter("MMMd")
    private static let dayFormatter = formatter("MMMEd")

    /// 「Oct 4 ~ Oct 10」
    static func weekRange(_ week: RecordWeek) -> String {
        "\(monthDay(week.firstDay)) ~ \(monthDay(week.lastDay()))"
    }

    /// 「Tue, Oct 6」
    static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// 「1 session」、「3 sessions」
    static func sessions(_ count: Int) -> String {
        String(localized: "\(count) sessions")
    }

    /// 「11:33」
    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static func monthDay(_ date: Date) -> String {
        monthDayFormatter.string(from: date)
    }
}
