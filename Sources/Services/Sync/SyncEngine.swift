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

public struct CloudKitZoneInfo: Equatable, Sendable {
    public var privateZoneName: String
    public var sharedZoneName: String
    public var containerIdentifier: String
    public var shareURL: String?

    public init(privateZoneName: String, sharedZoneName: String, containerIdentifier: String, shareURL: String? = nil) {
        self.privateZoneName = privateZoneName
        self.sharedZoneName = sharedZoneName
        self.containerIdentifier = containerIdentifier
        self.shareURL = shareURL
    }
}

public struct ProductionInvite: Equatable, Sendable {
    public var productionCode: String
    public var shareURL: URL
    public var qrPayload: String

    public init(productionCode: String, shareURL: URL) {
        self.productionCode = productionCode
        self.shareURL = shareURL
        self.qrPayload = "cameradata://join/\(productionCode)"
    }
}

public actor SyncEngine {
    public static let containerIdentifier = "iCloud.com.visionarypov.cameradata"

    private var pendingQueue: [PendingSyncOperation] = []
    private var isCloudKitAvailable: Bool
    private var container: CKContainer?
    private var privateDatabase: CKDatabase?
    private var sharedDatabase: CKDatabase?
    private var zoneInfo: CloudKitZoneInfo?

    public init(cloudKitAvailable: Bool = true) {
        self.isCloudKitAvailable = cloudKitAvailable
        if cloudKitAvailable {
            let ckContainer = CKContainer(identifier: Self.containerIdentifier)
            self.container = ckContainer
            self.privateDatabase = ckContainer.privateCloudDatabase
            self.sharedDatabase = ckContainer.sharedCloudDatabase
        }
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

    public func prepareZones(for productionCode: String) async throws -> CloudKitZoneInfo {
        let privateZone = CKRecordZone(zoneName: "Production-\(productionCode)-Private")
        let sharedZone = CKRecordZone(zoneName: "Production-\(productionCode)-Shared")

        if isCloudKitAvailable, let privateDatabase {
            _ = try await privateDatabase.modifyRecordZones(saving: [privateZone, sharedZone], deleting: [])
        }

        let info = CloudKitZoneInfo(
            privateZoneName: privateZone.zoneID.zoneName,
            sharedZoneName: sharedZone.zoneID.zoneName,
            containerIdentifier: Self.containerIdentifier,
            shareURL: "https://cameradata.app/join/\(productionCode)"
        )
        zoneInfo = info
        return info
    }

    public func createShare(for productionCode: String, productionName: String) async throws -> CKShare {
        let zoneID = CKRecordZone.ID(zoneName: "Production-\(productionCode)-Shared", ownerName: CKCurrentUserDefaultName)
        let root = CKRecord(recordType: "Production", recordID: CKRecord.ID(recordName: "production-\(productionCode)", zoneID: zoneID))
        root["name"] = productionName as CKRecordValue
        root["code"] = productionCode as CKRecordValue

        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = productionName as CKRecordValue
        share.publicPermission = .readWrite

        if isCloudKitAvailable, let privateDatabase {
            _ = try await privateDatabase.modifyRecords(saving: [root, share], deleting: [])
        }
        return share
    }

    public nonisolated func makeInvite(for productionCode: String) -> ProductionInvite {
        let url = URL(string: "https://cameradata.app/join/\(productionCode)")!
        return ProductionInvite(productionCode: productionCode, shareURL: url)
    }

    public func acceptShare(metadata: CKShare.Metadata) async throws {
        guard isCloudKitAvailable, let container else { return }
        _ = try await container.accept(metadata)
    }

    public func currentZoneInfo() -> CloudKitZoneInfo? {
        zoneInfo
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