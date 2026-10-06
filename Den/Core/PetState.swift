import Foundation

/// 寵物正在做的事。沒有任何負面狀態。
enum PetActivity: Equatable, Sendable {
    /// 白天、沒在計時。
    case idle
    /// 23:00–07:00、沒在計時。
    case sleeping
    /// 計時中，不分日夜、不分模式。
    case studying
    /// 被點到、剛升級、倒數完成。約 1.5 秒後回到原狀態。
    case happy
}

/// 依時間與計時狀態決定寵物在做什麼。
struct PetState: Equatable, Sendable {
    static let frameInterval: TimeInterval = 0.6
    static let happyDuration: TimeInterval = 1.5
    static let sleepStartHour = 23
    static let sleepEndHour = 7

    var isTiming: Bool
    /// 最近一次開心的開始時間。
    var happySince: Date?

    func activity(at date: Date, calendar: Calendar = .current) -> PetActivity {
        if let happySince, (0..<Self.happyDuration).contains(date.timeIntervalSince(happySince)) {
            return .happy
        }
        if isTiming {
            return .studying
        }
        let hour = calendar.component(.hour, from: date)
        if hour >= Self.sleepStartHour || hour < Self.sleepEndHour {
            return .sleeping
        }
        return .idle
    }
}
