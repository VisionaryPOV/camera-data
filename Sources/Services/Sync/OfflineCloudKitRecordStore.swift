import Foundation
import CloudKit

public struct PersistedCloudKitRecord: Equatable, Sendable, Codable {
    public var recordType: String
    public var recordName: String
    public var scene: String?
    public var take: Int?
    public var lens: String?
    public var iso: Int?
    public var syncVersion: Int?
    public var productionCode: String?
    public var pushedToCloudKit: Bool

    public init(
        recordType: String,
        recordName: String,
        scene: String? = nil,
        take: Int? = nil,
        lens: String? = nil,
        iso: Int? = nil,
        syncVersion: Int? = nil,
        productionCode: String? = nil,
        pushedToCloudKit: Bool
    ) {
        self.recordType = recordType
        self.recordName = recordName
        self.scene = scene
        self.take = take
        self.lens = lens
        self.iso = iso
        self.syncVersion = syncVersion
        self.productionCode = productionCode
        self.pushedToCloudKit = pushedToCloudKit
    }

    public func toCKRecord(zoneName: String) -> CKRecord {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: recordName, zoneID: zoneID))
        if let scene { record["scene"] = scene as CKRecordValue }
        if let take { record["take"] = take as CKRecordValue }
        if let lens { record["lens"] = lens as CKRecordValue }
        if let iso { record["iso"] = iso as CKRecordValue }
        if let syncVersion { record["syncVersion"] = syncVersion as CKRecordValue }
        if let productionCode { record["productionCode"] = productionCode as CKRecordValue }
        return record
    }
}

public struct PersistedCloudKitZone: Equatable, Sendable, Codable {
    public var zoneName: String
    public var pushedToCloudKit: Bool
}

private struct OfflineCloudKitSnapshot: Codable {
    var pendingOperations: [PendingSyncOperation]
    var records: [PersistedCloudKitRecord]
    var zones: [PersistedCloudKitZone]
}

public actor OfflineCloudKitRecordStore {
    private let storageURL: URL?
    private var snapshot: OfflineCloudKitSnapshot

    public init(storageURL: URL? = nil, inMemoryOnly: Bool = false) {
        if inMemoryOnly {
            self.storageURL = nil
            self.snapshot = OfflineCloudKitSnapshot(pendingOperations: [], records: [], zones: [])
        } else {
            let url = storageURL ?? Self.defaultStorageURL()
            self.storageURL = url
            self.snapshot = Self.loadSnapshot(from: url) ?? OfflineCloudKitSnapshot(pendingOperations: [], records: [], zones: [])
        }
    }

    public var records: [PersistedCloudKitRecord] { snapshot.records }
    public var zones: [PersistedCloudKitZone] { snapshot.zones }

    public func reset() {
        snapshot = OfflineCloudKitSnapshot(pendingOperations: [], records: [], zones: [])
        persistToDisk()
    }

    public func pendingOperations() -> [PendingSyncOperation] {
        snapshot.pendingOperations
    }

    public func setPendingOperations(_ operations: [PendingSyncOperation]) {
        snapshot.pendingOperations = operations
        persistToDisk()
    }

    public func persist(records ckRecords: [CKRecord], pushedToCloudKit: Bool) {
        for record in ckRecords {
            let persisted = PersistedCloudKitRecord(
                recordType: record.recordType,
                recordName: record.recordID.recordName,
                scene: record.ckString("scene"),
                take: record.ckInt("take"),
                lens: record.ckString("lens"),
                iso: record.ckInt("iso"),
                syncVersion: record.ckInt("syncVersion"),
                productionCode: record.ckString("productionCode"),
                pushedToCloudKit: pushedToCloudKit
            )
            if let index = snapshot.records.firstIndex(where: { $0.recordName == persisted.recordName }) {
                snapshot.records[index] = persisted
            } else {
                snapshot.records.append(persisted)
            }
        }
        persistToDisk()
    }

    public func persist(zones ckZones: [CKRecordZone], pushedToCloudKit: Bool) {
        for zone in ckZones {
            let persisted = PersistedCloudKitZone(zoneName: zone.zoneID.zoneName, pushedToCloudKit: pushedToCloudKit)
            if let index = snapshot.zones.firstIndex(where: { $0.zoneName == persisted.zoneName }) {
                snapshot.zones[index] = persisted
            } else {
                snapshot.zones.append(persisted)
            }
        }
        persistToDisk()
    }

    public func logEntries() -> [PersistedCloudKitRecord] {
        snapshot.records.filter { $0.recordType == "LogEntry" }
    }

    public func unpushedLogEntries() -> [PersistedCloudKitRecord] {
        logEntries().filter { !$0.pushedToCloudKit }
    }

    public func markRecordsPushed(recordNames: [String]) {
        for name in recordNames {
            if let index = snapshot.records.firstIndex(where: { $0.recordName == name }) {
                snapshot.records[index].pushedToCloudKit = true
            }
        }
        persistToDisk()
    }

    public func logEntryCKRecords(in zoneName: String) -> [CKRecord] {
        logEntries().map { $0.toCKRecord(zoneName: zoneName) }
    }

    private func persistToDisk() {
        guard let storageURL else { return }
        let directory = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private static func defaultStorageURL() -> URL {
        let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.visionarypov.cameradata"
        ) ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("offline-cloudkit-store.json")
    }

    private static func loadSnapshot(from url: URL) -> OfflineCloudKitSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(OfflineCloudKitSnapshot.self, from: data)
    }
}

extension CKRecord {
    public func ckString(_ key: String) -> String? {
        object(forKey: key) as? String
    }

    public func ckInt(_ key: String) -> Int? {
        if let value = object(forKey: key) as? Int {
            return value
        }
        if let value = object(forKey: key) as? Int64 {
            return Int(value)
        }
        if let value = object(forKey: key) as? NSNumber {
            return value.intValue
        }
        return nil
    }
}