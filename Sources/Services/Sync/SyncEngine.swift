import Foundation
import CloudKit
import CameraDataDomain

public struct PendingSyncOperation: Equatable, Sendable {
    public var entryId: UUID
    public var syncVersion: Int
    public var scene: String
    public var take: Int
    public var lens: String
    public var iso: Int
    public var productionCode: String
    public var enqueuedAt: Date

    public init(
        entryId: UUID,
        syncVersion: Int,
        scene: String = "",
        take: Int = 0,
        lens: String = "",
        iso: Int = 0,
        productionCode: String = "",
        enqueuedAt: Date = .now
    ) {
        self.entryId = entryId
        self.syncVersion = syncVersion
        self.scene = scene
        self.take = take
        self.lens = lens
        self.iso = iso
        self.productionCode = productionCode
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
    private let transport: CloudKitSyncTransport
    private var zoneInfo: CloudKitZoneInfo?
    private var lastShare: CKShare?
    public private(set) var flushInvocationCount: Int = 0
    public private(set) var modifyRecordsInvocationCount: Int = 0

    public init(transport: CloudKitSyncTransport = LiveCloudKitTransport()) {
        self.transport = transport
    }

    public func enqueue(entryId: UUID, syncVersion: Int) {
        pendingQueue.append(PendingSyncOperation(entryId: entryId, syncVersion: syncVersion))
    }

    public func enqueueLogEntry(
        entryId: UUID,
        syncVersion: Int,
        scene: String,
        take: Int,
        lens: String,
        iso: Int,
        productionCode: String
    ) {
        pendingQueue.append(
            PendingSyncOperation(
                entryId: entryId,
                syncVersion: syncVersion,
                scene: scene,
                take: take,
                lens: lens,
                iso: iso,
                productionCode: productionCode
            )
        )
    }

    public func pendingCount() -> Int {
        pendingQueue.count
    }

    public func flushOfflineQueue() async -> Int {
        flushInvocationCount += 1
        let operations = pendingQueue
        pendingQueue.removeAll()

        guard let zoneInfo else {
            return operations.count
        }

        let records = operations.map { operation -> CKRecord in
            let zoneID = CKRecordZone.ID(zoneName: zoneInfo.privateZoneName, ownerName: CKCurrentUserDefaultName)
            let recordID = CKRecord.ID(recordName: "entry-\(operation.entryId.uuidString)", zoneID: zoneID)
            let record = CKRecord(recordType: "LogEntry", recordID: recordID)
            record["scene"] = operation.scene as CKRecordValue
            record["take"] = operation.take as CKRecordValue
            record["lens"] = operation.lens as CKRecordValue
            record["iso"] = operation.iso as CKRecordValue
            record["syncVersion"] = operation.syncVersion as CKRecordValue
            record["productionCode"] = operation.productionCode as CKRecordValue
            return record
        }

        if !records.isEmpty {
            modifyRecordsInvocationCount += 1
            try? await transport.modifyRecords(saving: records, deleting: [])
        }

        return operations.count
    }

    public func prepareZones(for productionCode: String) async throws -> CloudKitZoneInfo {
        let privateZone = CKRecordZone(zoneName: "Production-\(productionCode)-Private")
        let sharedZone = CKRecordZone(zoneName: "Production-\(productionCode)-Shared")

        try await transport.modifyRecordZones(saving: [privateZone, sharedZone], deleting: [])

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

        try await transport.modifyRecords(saving: [root, share], deleting: [])
        lastShare = share
        return share
    }

    public nonisolated func makeInvite(for productionCode: String) -> ProductionInvite {
        let url = URL(string: "https://cameradata.app/join/\(productionCode)")!
        return ProductionInvite(productionCode: productionCode, shareURL: url)
    }

    public func acceptShare(metadata: CKShare.Metadata) async throws {
        try await transport.acceptShare(metadata: metadata)
    }

    public func currentZoneInfo() -> CloudKitZoneInfo? {
        zoneInfo
    }

    public func currentShare() -> CKShare? {
        lastShare
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