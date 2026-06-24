import Foundation
import CloudKit

public struct PersistedCloudKitRecord: Equatable, Sendable {
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
}

public struct PersistedCloudKitZone: Equatable, Sendable {
    public var zoneName: String
    public var pushedToCloudKit: Bool
}

public actor OfflineCloudKitRecordStore {
    public static let shared = OfflineCloudKitRecordStore()

    public init() {}

    public private(set) var records: [PersistedCloudKitRecord] = []
    public private(set) var zones: [PersistedCloudKitZone] = []

    public func reset() {
        records.removeAll()
        zones.removeAll()
    }

    public func persist(records ckRecords: [CKRecord], pushedToCloudKit: Bool) {
        for record in ckRecords {
            records.append(
                PersistedCloudKitRecord(
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
            )
        }
    }

    public func persist(zones ckZones: [CKRecordZone], pushedToCloudKit: Bool) {
        for zone in ckZones {
            zones.append(
                PersistedCloudKitZone(
                    zoneName: zone.zoneID.zoneName,
                    pushedToCloudKit: pushedToCloudKit
                )
            )
        }
    }

    public func logEntries() -> [PersistedCloudKitRecord] {
        records.filter { $0.recordType == "LogEntry" }
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