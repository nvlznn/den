import SwiftData
import SwiftUI

/// 「紀錄」分頁：一次看一週，依日分組。
struct RecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var sessions: [FocusSession]

    @State private var week = RecordWeek(containing: .now)
    @State private var isAdding = false

    private var days: [DayGroup<FocusSession>] {
        RecordGrouping.days(sessions, in: week.interval, startedAt: \.startedAt, duration: \.duration)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    weekNavigator
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if days.isEmpty {
                    ContentUnavailableView("這週沒有紀錄", systemImage: "book.closed")
                        .listRowBackground(Color.clear)
                }

                ForEach(days) { day in
                    Section {
                        ForEach(day.items) { session in
                            RecordRow(session: session)
                        }
                        .onDelete { offsets in
                            offsets.map { day.items[$0] }.forEach(modelContext.delete)
                            try? modelContext.save()
                        }
                    } header: {
                        DayHeader(day: day)
                    }
                }
            }
            .navigationTitle("紀錄")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAdding = true
                    } label: {
                        Label("新增紀錄", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                AddRecordSheet()
            }
        }
    }

    private var weekNavigator: some View {
        HStack {
            Button {
                week = week.shifted(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("上一週")

            Spacer()

            Text(RecordFormat.weekRange(week))
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Spacer()

            Button {
                week = week.shifted(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("下一週")
            .disabled(week.interval.end > .now)
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
            Text(RecordFormat.day(day.day))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primary)
            Text("\(DurationText.hoursAndMinutes(day.totalDuration))，\(day.count) 次")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }
}

private struct RecordRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "hourglass")
                .font(.title3)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.tag?.name ?? FocusSession.untaggedName)
                Text(RecordFormat.time(session.startedAt))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Text(DurationText.clock(Int(session.duration)))
                .font(.title3)
                .monospacedDigit()
                .foregroundStyle(.tint)
                .accessibilityLabel(DurationText.hoursAndMinutes(session.duration))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// 紀錄頁的日期格式。
enum RecordFormat {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = DurationText.locale
        formatter.dateFormat = format
        return formatter
    }

    private static let timeFormatter = formatter("HH:mm")
    private static let monthDayFormatter = formatter("M月d日")
    private static let weekdayFormatter = formatter("EEE")

    /// 「10月4日 ~ 10月10日」
    static func weekRange(_ week: RecordWeek) -> String {
        "\(monthDay(week.firstDay)) ~ \(monthDay(week.lastDay()))"
    }

    /// 「10月6日 週二」
    static func day(_ date: Date) -> String {
        "\(monthDay(date)) \(weekdayFormatter.string(from: date))"
    }

    /// 「11:33」
    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static func monthDay(_ date: Date) -> String {
        monthDayFormatter.string(from: date)
    }
}
