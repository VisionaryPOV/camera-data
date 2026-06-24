import Foundation
import CloudKit
import CameraDataDomain

public struct PendingSyncOperation: Equatable, Sendable {
    public var entryId: UUID
    public var syncVersion: Int
    public var enqueuedAt: Date

    public init(entryId: UUID, syncVersion: Int, enqueuedAt: Date = .now) {
        self.entryId = entryId
        self.syncVersion = syncVersion
        self.enqueuedAt = enqueuedAt
    }
}

public actor SyncEngine {
    public static let containerIdentifier = "iCloud.com.visionarypov.cameradata"

    private var pendingQueue: [PendingSyncOperation] = []
    private var isCloudKitAvailable: Bool

    public init(cloudKitAvailable: Bool = true) {
        self.isCloudKitAvailable = cloudKitAvailable
    }

    public func enqueue(entryId: UUID, syncVersion: Int) {
        pendingQueue.append(PendingSyncOperation(entryId: entryId, syncVersion: syncVersion))
    }

    public func pendingCount() -> Int {
        pendingQueue.count
    }

    public func flushOfflineQueue() async -> Int {
        guard isCloudKitAvailable else { return 0 }
        let count = pendingQueue.count
        pendingQueue.removeAll()
        return count
    }

    public func resolveConflict(
        local: LogEntryDraft,
        remote: LogEntryDraft,
        preferRemote: Bool
    ) -> LogEntryDraft {
        let conflicts = ConflictMerger.detectConflicts(local: local, remote: remote)
        var resolutions: [String: ConflictResolutionChoice] = [:]
        for conflict in conflicts {
            resolutions[conflict.key] = preferRemote ? .remote : .local
        }
        return ConflictMerger.merge(local: local, remote: remote, resolutions: resolutions)
    }

    public func makeShareMetadata(productionName: String, code: String) -> SyncMetadata {
        SyncMetadata(
            ckRecordName: "production-\(code)",
            shareURL: "https://cameradata.app/join/\(code)",
            revision: 1
        )
    }
}