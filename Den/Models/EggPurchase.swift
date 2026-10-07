import Foundation
import SwiftData

/// Private, synced purchase intent and delivery receipt. Save before asking Apple
/// to charge; finish only after the verified transaction has been saved here.
@Model
final class EggPurchase {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var colorRaw: String = "white"
    var characterID: String = ""
    var transactionID: String = ""
    var state: String = "requested"
    var revoked: Bool = false

    init(color: EggColor, characterID: String) {
        self.colorRaw = color.rawValue
        self.characterID = characterID
    }

    var reservesCharacter: Bool { !revoked && (state == "requested" || state == "pending") }
    var isDelivered: Bool { state == "delivered" && !revoked }

    static func reservedIDs(in purchases: [EggPurchase]) -> Set<String> {
        Set(purchases.filter(\.reservesCharacter).map(\.characterID))
    }
}
