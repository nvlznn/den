import CryptoKit
import Foundation
import SwiftData

/// Immutable outbox separate from editable/deletable focus records. Stable IDs
/// make uploads idempotent across retries, reinstall and private iCloud sync.
@Model
final class FocusContribution {
    var key: String = ""
    var seconds: Double = 0
    var uploaded: Bool = false

    init(key: String, seconds: Double) {
        self.key = key
        self.seconds = seconds
    }

    @MainActor
    static func capture(_ session: FocusSession, context: ModelContext) {
        guard !session.isManual, session.duration > 0, session.duration.isFinite,
              session.contributionKey == nil else { return }
        // Legacy records have no UUID. Equal synced records derive equal keys.
        let source = "\(session.startedAt.timeIntervalSinceReferenceDate)|\(session.endedAt.timeIntervalSinceReferenceDate)|\(session.characterID ?? PetSprites.defaultCharacterID)"
        let key = SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
        session.contributionKey = key
        context.insert(FocusContribution(key: key, seconds: session.duration))
    }
}
