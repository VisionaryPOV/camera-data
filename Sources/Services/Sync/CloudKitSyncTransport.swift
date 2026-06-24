import Foundation
import CloudKit

public protocol CloudKitSyncTransport: Sendable {
    func modifyRecordZones(saving zones: [CKRecordZone], deleting zoneIDs: [CKRecordZone.ID]) async throws
    func modifyRecords(saving records: [CKRecord], deleting recordIDs: [CKRecord.ID]) async throws
    func acceptShare(metadata: CKShare.Metadata) async throws
}

public final class LiveCloudKitTransport: CloudKitSyncTransport, @unchecked Sendable {
    private let container: CKContainer
    private let offlineStore: OfflineCloudKitRecordStore
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }

    public private(set) var cloudKitPushAttemptCount: Int = 0
    public private(set) var cloudKitPushSuccessCount: Int = 0

    public init(
        containerIdentifier: String = SyncEngine.containerIdentifier,
        offlineStore: OfflineCloudKitRecordStore = OfflineCloudKitRecordStore()
    ) {
        container = CKContainer(identifier: containerIdentifier)
        self.offlineStore = offlineStore
    }

    public func modifyRecordZones(
        saving zones: [CKRecordZone],
        deleting zoneIDs: [CKRecordZone.ID]
    ) async throws {
        var pushed = false
        if try await isAccountAvailable() {
            cloudKitPushAttemptCount += 1
            _ = try await privateDatabase.modifyRecordZones(saving: zones, deleting: zoneIDs)
            cloudKitPushSuccessCount += 1
            pushed = true
        }
        await offlineStore.persist(zones: zones, pushedToCloudKit: pushed)
    }

    public func modifyRecords(
        saving records: [CKRecord],
        deleting recordIDs: [CKRecord.ID]
    ) async throws {
        var pushed = false
        if try await isAccountAvailable() {
            cloudKitPushAttemptCount += 1
            _ = try await privateDatabase.modifyRecords(saving: records, deleting: recordIDs)
            cloudKitPushSuccessCount += 1
            pushed = true
        }
        await offlineStore.persist(records: records, pushedToCloudKit: pushed)
    }

    public func acceptShare(metadata: CKShare.Metadata) async throws {
        guard try await isAccountAvailable() else { return }
        cloudKitPushAttemptCount += 1
        _ = try await container.accept(metadata)
        cloudKitPushSuccessCount += 1
    }

    private func isAccountAvailable() async throws -> Bool {
        let status = try await container.accountStatus()
        return status == .available
    }
}

public actor RecordingCloudKitTransport: CloudKitSyncTransport {
    public init() {}

    public private(set) var savedZones: [CKRecordZone] = []
    public private(set) var deletedZoneIDs: [CKRecordZone.ID] = []
    public private(set) var savedRecords: [CKRecord] = []
    public private(set) var deletedRecordIDs: [CKRecord.ID] = []
    public private(set) var modifyRecordZonesInvocationCount: Int = 0
    public private(set) var modifyRecordsInvocationCount: Int = 0

    public func modifyRecordZones(
        saving zones: [CKRecordZone],
        deleting zoneIDs: [CKRecordZone.ID]
    ) async throws {
        modifyRecordZonesInvocationCount += 1
        savedZones.append(contentsOf: zones)
        deletedZoneIDs.append(contentsOf: zoneIDs)
    }

    public func modifyRecords(
        saving records: [CKRecord],
        deleting recordIDs: [CKRecord.ID]
    ) async throws {
        modifyRecordsInvocationCount += 1
        savedRecords.append(contentsOf: records)
        deletedRecordIDs.append(contentsOf: recordIDs)
    }

    public func acceptShare(metadata: CKShare.Metadata) async throws {}
}