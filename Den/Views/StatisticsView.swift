import Charts
import SwiftData
import SwiftUI

/// 「Statistics」分頁：日、週、月、年的專注數據。
struct StatisticsView: View {
    @Query private var sessions: [FocusSession]

    @AppStorage(DayBoundary.key, store: DayBoundary.store) private var dayStartHour = DayBoundary.defaultHour
    @State private var range = StatsRange(period: .day, containing: DayBoundary.current.shift(.now))

    private var boundary: DayBoundary { DayBoundary(hour: dayStartHour) }

    private var stats: FocusStats {
        let boundary = boundary
        let items = sessions.map {
            FocusStats.Item(
                startedAt: boundary.shift($0.startedAt),
                duration: $0.duration,
                tagName: $0.displayTagName
            )
        }
        return FocusStats(items: items, range: range, now: boundary.shift(.now))
    }

    var body: some View {
        let stats = stats

        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: period) {
                        ForEach(StatsPeriod.allCases) { period in
                            Text(StatsFormat.title(period)).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    periodNavigator
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

                Section("Overview") {
                    LabeledContent("Sessions", value: "\(stats.totalSessions)")
                    LabeledContent("Time", value: DurationText.hoursAndMinutes(stats.totalDuration))
                }

                if let title = StatsFormat.summaryTitle(range.period) {
                    Section(title) {
                        VStack(spacing: 16) {
                            FocusDaysView(stats: stats)
                            if range.period != .year {
                                Divider()
                            }
                            StatsGrid(stats: stats)
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section("Focus Time") {
                    DistributionChart(stats: stats)
                }

                Section("Tags") {
                    if stats.tags.isEmpty {
                        Text("No sessions")
                            .foregroundStyle(.secondary)
                    } else {
                        BreakdownView(stats: stats)
                    }
                }
            }
            .navigationTitle("Statistics")
        }
    }

    /// 換單位時停在包含「現在看的這段期間開頭」的那一段；看的是本期就留在今天。
    private var period: Binding<StatsPeriod> {
        Binding {
            range.period
        } set: { newPeriod in
            let now = boundary.shift(.now)
            let anchor = range.contains(now) ? now : range.interval.start
            range = StatsRange(period: newPeriod, containing: anchor)
        }
    }

    private var periodNavigator: some View {
        HStack {
            Button {
                range = range.shifted(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous")

            Spacer()

            Text(StatsFormat.rangeTitle(range))
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Spacer()

            Button {
                range = range.shifted(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next")
            .disabled(range.interval.end > boundary.shift(.now))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .padding(.vertical, 8)
    }
}

// MARK: - Focus Days

/// 週：七個圓圈；月：完整月曆。有專注的日子實心，下面顯示時長，今天下面有一個小點。年不顯示。
private struct FocusDaysView: View {
    let stats: FocusStats

    var body: some View {
        switch stats.range.period {
        case .week:
            HStack(alignment: .top, spacing: 0) {
                ForEach(stats.days) { day in
                    VStack(spacing: 6) {
                        Text(StatsFormat.weekdayInitial(day.start))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        DayMark(isFocused: day.duration > 0)
                            .frame(width: 34, height: 34)
                        DayCaption(day: day)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(StatsFormat.dayAccessibility(day))
                }
            }

        case .month:
            MonthGrid(days: stats.days)

        case .day, .year:
            EmptyView()
        }
    }
}

/// 圓圈下面的時長，今天再加一個小點。固定高度，沒專注的日子也佔位，格子才不會跳動。
private struct DayCaption: View {
    @AppStorage(DayBoundary.key, store: DayBoundary.store) private var dayStartHour = DayBoundary.defaultHour
    let day: FocusStats.Bucket

    var body: some View {
        VStack(spacing: 3) {
            Text(day.duration > 0 ? StatsFormat.shortDuration(day.duration) : " ")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Circle()
                .fill(Calendar.current.isDate(day.start, inSameDayAs: DayBoundary(hour: dayStartHour).shift(.now)) ? Color.accentColor : Color.clear)
                .frame(width: 5, height: 5)
        }
    }
}

private struct MonthGrid: View {
    let days: [FocusStats.Bucket]

    var body: some View {
        let calendar = Calendar.current
        let leadingBlanks = days.first.map {
            (calendar.component(.weekday, from: $0.start) - calendar.firstWeekday + 7) % 7
        } ?? 0

        // The month has at most six rows. Eager rows keep its height stable inside List.
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(StatsFormat.weekdayInitials(), id: \.offset) { item in
                    Text(item.element)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<((leadingBlanks + days.count + 6) / 7), id: \.self) { row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        let index = row * 7 + column - leadingBlanks
                        if days.indices.contains(index) {
                            let day = days[index]
                            let number = calendar.component(.day, from: day.start)
                            let isFocused = day.duration > 0
                            VStack(spacing: 4) {
                                Text("\(number)")
                                    .font(.body.weight(isFocused ? .semibold : .regular))
                                    .monospacedDigit()
                                    .foregroundStyle(isFocused ? Color.white : Color.primary)
                                    .frame(width: 34, height: 34)
                                    .background {
                                        if isFocused { Circle().fill(Color.accentColor) }
                                    }
                                DayCaption(day: day)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(StatsFormat.dayAccessibility(day))
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 34)
                        }
                    }
                }
            }
        }
    }
}

/// 有專注：實心圓加勾；沒有：空心圓。
private struct DayMark: View {
    let isFocused: Bool

    var body: some View {
        if isFocused {
            Circle()
                .fill(Color.accentColor)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                }
        } else {
            Circle()
                .strokeBorder(Color(.separator), lineWidth: 1.5)
        }
    }
}

private struct StatsGrid: View {
    let stats: FocusStats

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
            GridRow {
                StatCell(title: "Daily Average", value: DurationText.hoursAndMinutes(stats.dailyAverage))
                StatCell(title: "Per Active Day", value: DurationText.hoursAndMinutes(stats.perActiveDay))
            }
        }
    }
}

private struct StatCell: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Distribution

/// 單一系列的長條圖，用主色、不放圖例。點長條看數值。
private struct DistributionChart: View {
    @AppStorage(DayBoundary.key, store: DayBoundary.store) private var dayStartHour = DayBoundary.defaultHour
    let stats: FocusStats

    @State private var selectedDate: Date?

    /// 「日」用分鐘，其他用小時。
    private var usesMinutes: Bool { stats.range.period == .day }
    private var unitName: LocalizedStringResource { usesMinutes ? "Minutes" : "Hours" }
    private var unitNameLowercased: String { usesMinutes ? String(localized: "minutes") : String(localized: "hours") }

    private func value(_ bucket: FocusStats.Bucket) -> Double {
        bucket.duration / (usesMinutes ? 60 : 3600)
    }

    private var selectedBucket: FocusStats.Bucket? {
        guard let selectedDate else { return nil }
        let component = stats.range.period.bucketComponent
        return stats.buckets.first {
            Calendar.current.isDate($0.start, equalTo: selectedDate, toGranularity: component)
        }
    }

    var body: some View {
        Chart {
            ForEach(stats.buckets) { bucket in
                BarMark(
                    x: .value("Time", bucket.start, unit: stats.range.period.bucketComponent),
                    y: .value(unitName, value(bucket))
                )
                .foregroundStyle(Color.accentColor.opacity(selectedBucket == nil || selectedBucket == bucket ? 1 : 0.35))
                .cornerRadius(4)
            }

            if let selectedBucket {
                RuleMark(x: .value("Time", selectedBucket.start, unit: stats.range.period.bucketComponent))
                    .foregroundStyle(Color.clear)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 2) {
                            Text(StatsFormat.bucketTitle(selectedBucket.start, period: stats.range.period, boundary: DayBoundary(hour: dayStartHour)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(DurationText.hoursAndMinutes(selectedBucket.duration))
                                .font(.callout.weight(.semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis { xAxis }
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 220)
        .padding(.vertical, 8)
        .accessibilityLabel(String(localized: "Focus time distribution in \(unitNameLowercased)"))
    }

    @AxisContentBuilder
    private var xAxis: some AxisContent {
        switch stats.range.period {
        case .day:
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisGridLine()
                // 橫軸的時間是挪過的，標籤要還原成真正的幾點。
                if let date = value.as(Date.self) {
                    AxisValueLabel(StatsFormat.hourLabel(DayBoundary(hour: dayStartHour).unshift(date)))
                }
            }
        case .week:
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
            }
        case .month:
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
            }
        case .year:
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
            }
        }
    }
}

// MARK: - Breakdown

/// 依標籤的甜甜圈圖，加上同時當圖例和表格用的明細。
private struct BreakdownView: View {
    let stats: FocusStats

    private static let tagLimit = 7

    private static var isChinese: Bool { Locale.current.language.languageCode?.identifier == "zh" }

    var body: some View {
        let shares = stats.foldedTags(limit: Self.tagLimit)

        Chart(Array(shares.enumerated()), id: \.element.id) { index, share in
            SectorMark(
                angle: .value("Duration", share.duration),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(color(index: index, share: share))
        }
        .chartBackground { proxy in
            GeometryReader { geometry in
                if let frame = proxy.plotFrame {
                    let rect = geometry[frame]
                    VStack(spacing: 0) {
                        Text(DurationText.hoursAndMinutes(stats.totalDuration))
                            // 中文字比較寬，同樣的字級會頂到圓環，所以縮小一級。
                            .font(Self.isChinese ? .subheadline.weight(.semibold) : .headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: rect.width * 0.55)
                        Text("total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .frame(height: 200)
        .padding(.vertical, 8)
        .accessibilityHidden(true)

        ForEach(Array(shares.enumerated()), id: \.element.id) { index, share in
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Circle()
                    .fill(color(index: index, share: share))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(share.name)
                    Text("\(RecordFormat.sessions(share.count)) | \(DurationText.hoursAndMinutes(share.duration)) | \(Int((share.fraction * 100).rounded()))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func color(index: Int, share: FocusStats.TagShare) -> Color {
        index >= Self.tagLimit ? ChartPalette.other : ChartPalette.color(at: index)
    }
}

// MARK: - Format

enum StatsFormat {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        if format.contains(":") {
            formatter.dateFormat = format
        } else {
            formatter.setLocalizedDateFormatFromTemplate(format)
        }
        return formatter
    }

    private static let monthYear = formatter("yMMMM")
    private static let year = formatter("y")
    private static let hourFormatter = formatter("HH:00")

    static func title(_ period: StatsPeriod) -> String {
        switch period {
        case .day: String(localized: "Day")
        case .week: String(localized: "Week")
        case .month: String(localized: "Month")
        case .year: String(localized: "Year")
        }
    }

    /// 日檢視沒有這一區。
    static func summaryTitle(_ period: StatsPeriod) -> String? {
        switch period {
        case .day: nil
        case .week: String(localized: "Weekly Focus Days")
        case .month: String(localized: "Monthly Focus Calendar")
        case .year: String(localized: "Yearly Summary")
        }
    }

    static func rangeTitle(_ range: StatsRange) -> String {
        switch range.period {
        case .day: RecordFormat.day(range.interval.start)
        case .week: RecordFormat.weekRange(RecordWeek(containing: range.interval.start))
        case .month: monthYear.string(from: range.interval.start)
        case .year: year.string(from: range.interval.start)
        }
    }

    /// 長條圖上被點到的那一根的名稱。
    static func bucketTitle(_ date: Date, period: StatsPeriod, boundary: DayBoundary) -> String {
        switch period {
        case .day: hourFormatter.string(from: boundary.unshift(date))
        case .week, .month: RecordFormat.day(date)
        case .year: monthYear.string(from: date)
        }
    }

    /// 橫軸的整點標籤，例如「4」。
    static func hourLabel(_ date: Date) -> String {
        String(Calendar.current.component(.hour, from: date))
    }

    /// 「S」「M」「T」…
    static func weekdayInitial(_ date: Date) -> String {
        let calendar = Calendar.current
        return calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
    }

    /// 依日曆的一週起始日排好的星期縮寫。
    static func weekdayInitials() -> [EnumeratedSequence<[String]>.Element] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array((symbols[first...] + symbols[..<first]).enumerated())
    }

    /// 「5:25」= 5 小時 25 分。
    static func shortDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    static func dayAccessibility(_ day: FocusStats.Bucket) -> String {
        let date = RecordFormat.day(day.start)
        return day.duration > 0 ? String(localized: "\(date), \(DurationText.hoursAndMinutes(day.duration))") : String(localized: "\(date), no focus")
    }
}
