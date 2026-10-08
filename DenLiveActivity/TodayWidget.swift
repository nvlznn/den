import SwiftUI
import WidgetKit

/// 主畫面與鎖定畫面的 Widget：角色和今天的專注時間、次數。
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DenToday", provider: TodayProvider()) { entry in
            TodayWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Den")
        .description("Your friend and focus time.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

// MARK: - Timeline

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// 內容由 app 寫入的摘要決定；app 改了資料就會叫 Widget 重新整理。
/// 另外在午夜排一筆，讓「今天」自動歸零，不必先打開 app。
struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: .empty())
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        let snapshot = (WidgetSnapshot.load() ?? .empty()).asOf(.now)
        completion(TodayEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date.now
        let stored = WidgetSnapshot.load() ?? .empty()
        let midnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(24 * 3600)
        let entries = [
            TodayEntry(date: now, snapshot: stored.asOf(now)),
            TodayEntry(date: midnight, snapshot: stored.asOf(midnight)),
        ]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

// MARK: - Views

struct TodayWidgetView: View {
    let snapshot: WidgetSnapshot

    @Environment(\.widgetFamily) private var family

    private var character: PetCharacter { PetSprites.character(id: snapshot.characterID) }
    private var duration: String { DurationText.hoursAndMinutes(snapshot.todaySeconds) }
    private var sessions: String {
        String(localized: "\(snapshot.todaySessions) sessions")
    }

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        case .systemLarge: large
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: small
        }
    }

    // 小：上面是角色，下面是今天的時間和次數。
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            LCDTile(character: character, level: nil)
                .frame(height: 64)
            Spacer(minLength: 8)
            Text(duration)
                .font(.title3.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(sessions)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    // 中：左邊是角色和等級，右邊是今天的時間、次數和升級進度。
    private var medium: some View {
        HStack(spacing: 16) {
            LCDTile(character: character, level: snapshot.level)
                .aspectRatio(1, contentMode: .fit)
            VStack(alignment: .leading, spacing: 2) {
                Text(duration)
                    .font(.title.weight(.bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(sessions)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                EvolveProgress(snapshot: snapshot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    // 大：上面是大螢幕，下面是今天的時間、次數和升級進度。
    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            LCDTile(character: character, level: snapshot.level)
                .frame(maxHeight: .infinity)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(duration)
                        .font(.title.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer()
                Text(sessions)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            EvolveProgress(snapshot: snapshot)
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    // 鎖定畫面・圓形：角色和今天的時間（h:mm）。
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                PixelSprite(pixels: character.idle)
                    .fill(.primary)
                    .frame(width: 20, height: 20)
                Text(shortDuration)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(duration) focused")
        .containerBackground(for: .widget) {}
    }

    // 鎖定畫面・長方形：角色、今天的時間和次數。
    private var rectangular: some View {
        HStack(spacing: 8) {
            PixelSprite(pixels: character.idle)
                .fill(.primary)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(duration)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(sessions)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) {}
    }

    // 鎖定畫面・單行（時鐘上方那一行）。
    private var inline: some View {
        Text("\(duration) focused")
            .containerBackground(for: .widget) {}
    }

    /// 圓形放不下「1 hr 35 min」，改成「1:35」。
    private var shortDuration: String {
        let minutes = Int(snapshot.todaySeconds) / 60
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

/// LCD 底色上的角色，可以帶「Lv N」。
private struct LCDTile: View {
    let character: PetCharacter
    let level: Int?

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LCDPalette.background)
            PixelSprite(pixels: character.idle)
                .fill(LCDPalette.pixelOn)
                .padding(level == nil ? 10 : 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let level {
                Text("Lv \(level)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(LCDPalette.pixelOn)
                    .padding(8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(level.map { String(localized: "\(character.name), level \($0)") } ?? character.name)
    }
}

/// 升級進度只用進度條顯示。
private struct EvolveProgress: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        ProgressView(value: snapshot.progressToNext)
            .tint(.secondary)
    }
}

#Preview("Small", as: .systemSmall) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: WidgetSnapshot(day: .now, todaySeconds: 5700, todaySessions: 3, characterID: "fangfang", level: 2, progressToNext: 0.4, secondsToNext: 21600))
}

#Preview("Medium", as: .systemMedium) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: WidgetSnapshot(day: .now, todaySeconds: 5700, todaySessions: 3, characterID: "mochi", level: 2, progressToNext: 0.4, secondsToNext: 21600))
}
