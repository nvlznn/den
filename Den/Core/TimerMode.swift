import Foundation

/// 計時的兩種模式。
///
/// 兩者的差別只有「什麼時候結束」和「畫面顯示哪個數字」，
/// 累積時數的算法完全一樣。
enum TimerMode: Codable, Hashable, Sendable {
    /// 正計時，沒有目標。
    case stopwatch
    /// 倒數，`planned` 是預定時長（秒）。
    case countdown(planned: TimeInterval)

    var kind: Kind {
        switch self {
        case .stopwatch: .stopwatch
        case .countdown: .countdown
        }
    }

    /// 不帶時長的模式種類，給模式選擇與記住上次選擇用。
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case stopwatch
        case countdown

        var id: Self { self }
    }
}
