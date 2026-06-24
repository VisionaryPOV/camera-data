import Foundation
import CloudKit
import CameraDataDomain

public struct PendingSyncOperation: Equatable, Sendable, Codable {
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

public struct RemoteLogEntryChange: Equatable, Sendable {
    public var entryId: UUID
    public var draft: LogEntryDraft
    public var syncVersion: Int

    public init(entryId: UUID, draft: LogEntryDraft, syncVersion: Int) {
        self.entryId = entryId
        self.draft = draft
        self.syncVersion = syncVersion
    }
}

public actor SyncEngine {
    public static let containerIdentifier = "iCloud.com.visionarypov.cameradata"

    private var pendingQueue: [PendingSyncOperation] = []
    private let transport: CloudKitSyncTransport
    private let offlineStore: OfflineCloudKitRecordStore?
    private var zoneInfo: CloudKitZoneInfo?
    private var lastShare: CKShare?
    private var queueHydrated = false
    public private(set) var flushInvocationCount: Int = 0
    public private(set) var modifyRecordsInvocationCount: Int = 0

    public init(transport: CloudKitSyncTransport, offlineStore: OfflineCloudKitRecordStore? = nil) {
        self.transport = transport
        self.offlineStore = offlineStore
    }

    public func enqueue(entryId: UUID, syncVersion: Int) async {
        await hydratePendingQueueIfNeeded()
        upsertPending(
            PendingSyncOperation(entryId: entryId, syncVersion: syncVersion)
        )
        await persistPendingQueue()
    }

    public func enqueueLogEntry(
        entryId: UUID,
        syncVersion: Int,
        scene: String,
        take: Int,
        lens: String,
        iso: Int,
        productionCode: String
    ) async {
        await hydratePendingQueueIfNeeded()
        upsertPending(
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
        await persistPendingQueue()
    }

    public func pendingCount() -> Int {
        pendingQueue.count
    }

    public func flushOfflineQueue() async -> Int {
        await hydratePendingQueueIfNeeded()
        flushInvocationCount += 1

        guard let zoneInfo, !pendingQueue.isEmpty else {
            return 0
        }

        let operations = pendingQueue
        let records = operations.map { makeCKRecord(from: $0, zoneName: zoneInfo.privateZoneName) }

        do {
            modifyRecordsInvocationCount += 1
            try await transport.modifyRecords(saving: records, deleting: [])
            pendingQueue.removeAll()
            await persistPendingQueue()
            return operations.count
        } catch {
            await persistPendingQueue()
            return 0
        }
    }

    public func replayUnpushedOfflineRecords() async throws -> Int {
        await hydratePendingQueueIfNeeded()
        guard let zoneInfo, let offlineStore else { return 0 }

        let unpushed = await offlineStore.unpushedLogEntries()
        guard !unpushed.isEmpty else { return 0 }

        let records = unpushed.map { $0.toCKRecord(zoneName: zoneInfo.privateZoneName) }
        modifyRecordsInvocationCount += 1
        try await transport.modifyRecords(saving: records, deleting: [])
        await offlineStore.markRecordsPushed(recordNames: unpushed.map(\.recordName))
        return unpushed.count
    }

    public func pullRemoteLogEntries() async throws -> [RemoteLogEntryChange] {
        await hydratePendingQueueIfNeeded()
        guard let zoneInfo else { return [] }

        let records = try await transport.fetchLogEntries(in: zoneInfo.privateZoneName)
        return records.compactMap { record in
            guard let entryId = Self.parseEntryId(from: record.recordID.recordName) else { return nil }
            let draft = LogEntryDraft(
                scene: record.ckString("scene") ?? "",
                take: record.ckInt("take") ?? 0,
                lens: record.ckString("lens") ?? "",
                iso: record.ckInt("iso") ?? 0
            )
            return RemoteLogEntryChange(
                entryId: entryId,
                draft: draft,
                syncVersion: record.ckInt("syncVersion") ?? 0
            )
        }
    }

    public func prepareZones(for productionCode: String) async throws -> CloudKitZoneInfo {
        let privateZone = CKRecordZone(zoneName: "Production-\(productionCode)-Private")
        let sharedZone = CKRecordZone(zoneName: "Production-\(productionCode)-Shared")

        try await transport.modifyRecordZones(saving: [privateZone, sharedZone], deleting: [])

        let info = CloudKitZoneInfo(
            privateZoneName: privateZone.zoneID.zoneName,
            sharedZoneName: sharedZone.zoneID.zoneName,
            containerIdentifier: Self.containerIdentifier,
            shareURL: nil
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
        if var info = zoneInfo {
            info.shareURL = share.url?.absoluteString
            zoneInfo = info
        }
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

    private func hydratePendingQueueIfNeeded() async {
        guard !queueHydrated, let offlineStore else { return }
        pendingQueue = await offlineStore.pendingOperations()
        queueHydrated = true
    }

    private func persistPendingQueue() async {
        guard let offlineStore else { return }
        await offlineStore.setPendingOperations(pendingQueue)
    }

    private func upsertPending(_ operation: PendingSyncOperation) {
        if let index = pendingQueue.firstIndex(where: { $0.entryId == operation.entryId }) {
            pendingQueue[index] = operation
        } else {
            pendingQueue.append(operation)
        }
    }

    private func makeCKRecord(from operation: PendingSyncOperation, zoneName: String) -> CKRecord {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
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

    private static func parseEntryId(from recordName: String) -> UUID? {
        guard recordName.hasPrefix("entry-") else { return nil }
        return UUID(uuidString: String(recordName.dropFirst("entry-".count)))
    }
}