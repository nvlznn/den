import CloudKit
import CoreData
import Foundation
import Observation

/// 判斷「iCloud 上的資料已經下載過一次了沒」。
///
/// 重新安裝 app 時，iCloud 的標籤要過一下子才會下載下來。在那之前看到「0 個標籤」不代表這個人第一次使用，
/// 所以預設標籤要等這裡變成 ready 之後才判斷。用過 app 的帳號至少一定有一個標籤，
/// 下載完還是 0 個，才是真的第一次使用。
@MainActor
@Observable
final class CloudSyncMonitor {
    /// iCloud 第一次下載完成，或是根本沒有 iCloud（沒登入、或資料庫只存在本機）。
    private(set) var isReady = false

    @ObservationIgnored private var observer: NSObjectProtocol?

    init(usesCloud: Bool, containerID: String) {
        guard usesCloud else {
            isReady = true
            return
        }

        // SwiftData 底下用的是 NSPersistentCloudKitContainer，每次從 iCloud 下載完都會發這個通知。
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                event.type == .import,
                event.endDate != nil,
                event.succeeded
            else { return }
            MainActor.assumeIsolated {
                self?.isReady = true
            }
        }

        // 沒登入 iCloud 就不會有下載，直接當作 ready（資料只在這台裝置上）。
        Task { [weak self] in
            let status = try? await CKContainer(identifier: containerID).accountStatus()
            if status == .noAccount || status == .restricted {
                self?.isReady = true
            }
        }
    }
}
