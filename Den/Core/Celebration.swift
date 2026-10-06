import Foundation

/// 專注結束後的慶祝畫面要顯示的內容。
struct Celebration: Identifiable, Equatable, Sendable {
    let id = UUID()
    let characterID: String
    let duration: TimeInterval
    let levelBefore: Int
    let levelAfter: Int
    let message: String

    var didLevelUp: Bool { levelAfter > levelBefore }

    private static let messages = [
        "Yay! Nicely done!",
        "Yay! That was a great session!",
        "Yay! You showed up and it counted!",
        "Yay! Time well spent!",
        "Yay! Take a deep breath, you earned it!",
        "Yay! One more step forward!",
    ]

    init(characterID: String, duration: TimeInterval, levelBefore: Int, levelAfter: Int, characterName: String) {
        self.characterID = characterID
        self.duration = duration
        self.levelBefore = levelBefore
        self.levelAfter = levelAfter
        message = levelAfter > levelBefore
            ? "Yay! \(characterName) evolved to Lv \(levelAfter)!"
            : Self.messages.randomElement() ?? Self.messages[0]
    }
}
