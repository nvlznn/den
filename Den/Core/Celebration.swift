import Foundation

/// 專注結束後的慶祝畫面要顯示的內容。
struct Celebration: Identifiable, Equatable, Sendable {
    let id = UUID()
    let characterID: String
    let duration: TimeInterval
    let levelBefore: Int
    let levelAfter: Int
    let message: String
    var didHatch: Bool = false

    var didLevelUp: Bool { levelAfter > levelBefore }

    private static let messages = [
        String(localized: "Yay! Nicely done!"),
        String(localized: "Yay! That was a great session!"),
        String(localized: "Yay! You showed up and it counted!"),
        String(localized: "Yay! Time well spent!"),
        String(localized: "Yay! Take a deep breath, you earned it!"),
        String(localized: "Yay! One more step forward!"),
    ]

    init(characterID: String, duration: TimeInterval, levelBefore: Int, levelAfter: Int, characterName: String, didHatch: Bool = false) {
        self.characterID = characterID
        self.duration = duration
        self.levelBefore = levelBefore
        self.levelAfter = levelAfter
        self.didHatch = didHatch
        message = didHatch ? String(localized: "Your egg hatched!") : levelAfter > levelBefore
            ? String(localized: "Yay! \(characterName) evolved to Lv \(levelAfter)!")
            : Self.messages.randomElement() ?? Self.messages[0]
    }
}
