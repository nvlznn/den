import CloudKit
import CryptoKit
import Foundation
import Observation
import SwiftData

/// Public CloudKit contains only measured seconds and opaque IDs. The private
/// records, tag names, characters and dates are never copied to that database.
@MainActor
@Observable
final class CommunityFocusStore {
    private(set) var totalSeconds: Double?
    private(set) var updatedAt: Date?
    private(set) var isRefreshing = false
    private(set) var status: String?
    private let container = CKContainer(identifier: DenApp.cloudContainerID)

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "communityTotalSeconds") != nil {
            totalSeconds = defaults.double(forKey: "communityTotalSeconds")
            updatedAt = defaults.object(forKey: "communityUpdatedAt") as? Date
        }
    }

    func refresh(context: ModelContext) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let accountStatus = try await container.accountStatus()
            if accountStatus == .available {
                let user = try await container.userRecordID()
                let pending = try context.fetch(FetchDescriptor<FocusContribution>(predicate: #Predicate { !$0.uploaded }))
                for item in pending {
                    try Task.checkCancellation()
                    // Namespaced by iCloud account, so unrelated users cannot collide.
                    let source = user.recordName + ":" + item.key
                    let key = SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
                    let record = CKRecord(recordType: "FocusContribution", recordID: CKRecord.ID(recordName: key))
                    record["seconds"] = item.seconds as CKRecordValue
                    do {
                        _ = try await container.publicCloudDatabase.save(record)
                    } catch let error as CKError where error.code == .serverRecordChanged {
                        // An identical contribution already exists: never increment twice.
                    }
                    item.uploaded = true
                    try context.save()
                }
                status = nil
            } else {
                status = "Sign in to iCloud to include your focus time. Saved time will be contributed when you reconnect."
            }
            var sum = 0.0
            let database = container.publicCloudDatabase
            var page = try await database.records(matching: CKQuery(recordType: "FocusContribution", predicate: NSPredicate(value: true)), desiredKeys: ["seconds"])
            while true {
                for (_, result) in page.matchResults {
                    let record = try result.get()
                    let seconds = (record["seconds"] as? NSNumber)?.doubleValue ?? 0
                    if seconds.isFinite && seconds > 0 { sum += seconds }
                }
                guard let cursor = page.queryCursor else { break }
                try Task.checkCancellation()
                page = try await database.records(continuingMatchFrom: cursor, desiredKeys: ["seconds"])
            }
            try Task.checkCancellation()
            totalSeconds = sum
            updatedAt = .now
            UserDefaults.standard.set(sum, forKey: "communityTotalSeconds")
            UserDefaults.standard.set(updatedAt, forKey: "communityUpdatedAt")
        } catch is CancellationError {
            // Keep the last successful value. Pending uploads remain retryable.
        } catch {
            status = "Community total is unavailable. Your focus time is saved and will sync later."
        }
    }
}
