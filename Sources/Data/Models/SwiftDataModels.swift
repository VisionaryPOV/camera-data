import Foundation
import SwiftData
import CameraDataDomain

@Model
public final class ProductionModel {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var code: String
    public var createdAt: Date
    public var archivedAt: Date?
    public var schemaVersion: Int
    public var ckRecordName: String?
    public var shareURL: String?
    public var syncRevision: Int
    public var brandingJSON: String?
    public var settingsJSON: String?

    @Relationship(deleteRule: .cascade, inverse: \CameraUnitModel.production)
    public var cameras: [CameraUnitModel]

    @Relationship(deleteRule: .cascade, inverse: \ShootDayModel.production)
    public var days: [ShootDayModel]

    @Relationship(deleteRule: .cascade, inverse: \CustomFieldDefinitionModel.production)
    public var customFields: [CustomFieldDefinitionModel]

    @Relationship(deleteRule: .cascade, inverse: \ProductionMemberModel.production)
    public var members: [ProductionMemberModel]

    public init(
        id: UUID = UUID(),
        name: String,
        code: String = "",
        createdAt: Date = .now,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.name = name
        self.code = code.isEmpty ? String(name.prefix(6)).uppercased() : code
        self.createdAt = createdAt
        self.schemaVersion = schemaVersion
        self.syncRevision = 0
        self.cameras = []
        self.days = []
        self.customFields = []
        self.members = []
    }
}

@Model
public final class CameraUnitModel {
    @Attribute(.unique) public var id: UUID
    public var label: String
    public var sortOrder: Int
    public var isActive: Bool
    public var defaultLens: String
    public var defaultISO: Int
    public var defaultFPS: Double
    public var defaultWhiteBalance: String
    public var defaultCodec: String
    public var defaultResolution: String

    public var production: ProductionModel?

    @Relationship(deleteRule: .cascade, inverse: \LogEntryModel.camera)
    public var entries: [LogEntryModel]

    @Relationship(deleteRule: .cascade, inverse: \RollModel.camera)
    public var rolls: [RollModel]

    public init(label: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.label = label
        self.sortOrder = sortOrder
        self.isActive = true
        self.defaultLens = ""
        self.defaultISO = 800
        self.defaultFPS = 24
        self.defaultWhiteBalance = "5600K"
        self.defaultCodec = "ProRes"
        self.defaultResolution = "4K"
        self.entries = []
        self.rolls = []
    }
}

@Model
public final class ShootDayModel {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var dayNumber: Int
    public var locationName: String
    public var notes: String
    public var cachedTakeCount: Int

    public var production: ProductionModel?

    @Relationship(deleteRule: .cascade, inverse: \LogEntryModel.day)
    public var entries: [LogEntryModel]

    public init(date: Date = .now, dayNumber: Int = 1, locationName: String = "") {
        self.id = UUID()
        self.date = date
        self.dayNumber = dayNumber
        self.locationName = locationName
        self.notes = ""
        self.cachedTakeCount = 0
        self.entries = []
    }
}

@Model
public final class LogEntryModel {
    @Attribute(.unique) public var id: UUID
    public var scene: String
    public var take: Int
    public var setup: String?
    public var sortKey: String
    public var lens: String
    public var filter: String
    public var iso: Int
    public var shutterAngle: Double?
    public var shutterSpeed: String?
    public var whiteBalance: String
    public var fps: Double
    public var resolution: String
    public var codec: String
    public var rollNumber: String
    public var timecodeIn: String
    public var timecodeOut: String
    public var notes: String
    public var scriptNotes: String
    public var vfxNotes: String
    public var isCircled: Bool
    public var isMOS: Bool
    public var isPickup: Bool
    public var isTail: Bool
    public var isHold: Bool
    public var isBad: Bool
    public var isSeries: Bool
    public var modifiedAt: Date
    public var modifiedBy: String
    public var syncVersion: Int
    public var isDeleted: Bool
    public var deviceId: String
    public var latitude: Double?
    public var longitude: Double?
    public var altitude: Double?
    public var pitch: Double?
    public var roll: Double?
    public var yaw: Double?

    public var camera: CameraUnitModel?
    public var day: ShootDayModel?
    public var production: ProductionModel?

    @Relationship(deleteRule: .cascade, inverse: \CustomFieldValueModel.entry)
    public var customValues: [CustomFieldValueModel]

    @Relationship(deleteRule: .cascade, inverse: \AttachmentModel.entry)
    public var attachments: [AttachmentModel]

    @Relationship(deleteRule: .cascade, inverse: \AuditEventModel.entry)
    public var auditTrail: [AuditEventModel]

    public init(scene: String, take: Int, modifiedBy: String = "local") {
        self.id = UUID()
        self.scene = scene
        self.take = take
        self.sortKey = SortKeyGenerator.make(scene: scene, take: take)
        self.lens = ""
        self.filter = ""
        self.iso = 800
        self.whiteBalance = "5600K"
        self.fps = 24
        self.resolution = "4K"
        self.codec = "ProRes"
        self.rollNumber = ""
        self.timecodeIn = "00:00:00:00"
        self.timecodeOut = ""
        self.notes = ""
        self.scriptNotes = ""
        self.vfxNotes = ""
        self.isCircled = false
        self.isMOS = false
        self.isPickup = false
        self.isTail = false
        self.isHold = false
        self.isBad = false
        self.isSeries = false
        self.modifiedAt = .now
        self.modifiedBy = modifiedBy
        self.syncVersion = 0
        self.isDeleted = false
        self.deviceId = UUID().uuidString
        self.customValues = []
        self.attachments = []
        self.auditTrail = []
    }
}

@Model
public final class CustomFieldDefinitionModel {
    @Attribute(.unique) public var id: UUID
    public var key: String
    public var label: String
    public var fieldTypeRaw: String
    public var pickerOptionsJSON: String?
    public var defaultValue: String?
    public var isRequired: Bool
    public var sortOrder: Int
    public var scope: String
    public var visibilityRolesJSON: String?

    public var production: ProductionModel?

    @Relationship(deleteRule: .cascade, inverse: \CustomFieldValueModel.definition)
    public var values: [CustomFieldValueModel]

    public init(key: String, label: String, fieldType: CustomFieldType, sortOrder: Int = 0) {
        self.id = UUID()
        self.key = key
        self.label = label
        self.fieldTypeRaw = fieldType.rawValue
        self.isRequired = false
        self.sortOrder = sortOrder
        self.scope = "production"
        self.values = []
    }
}

@Model
public final class CustomFieldValueModel {
    @Attribute(.unique) public var id: UUID
    public var stringValue: String?
    public var numberValue: Double?
    public var boolValue: Bool?
    public var dateValue: Date?

    public var definition: CustomFieldDefinitionModel?
    public var entry: LogEntryModel?

    public init() {
        self.id = UUID()
    }
}

@Model
public final class RollModel {
    @Attribute(.unique) public var id: UUID
    public var rollNumber: String
    public var mediaType: String
    public var capacity: String
    public var remaining: String
    public var labRoll: String

    public var camera: CameraUnitModel?

    public init(rollNumber: String) {
        self.id = UUID()
        self.rollNumber = rollNumber
        self.mediaType = "CFexpress"
        self.capacity = ""
        self.remaining = ""
        self.labRoll = ""
    }
}

@Model
public final class AttachmentModel {
    @Attribute(.unique) public var id: UUID
    public var typeRaw: String
    public var localPath: String?
    public var thumbnailPath: String?
    public var exifJSON: String?
    public var capturedAt: Date?
    public var fileSize: Int

    public var entry: LogEntryModel?

    public init(type: AttachmentType) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.fileSize = 0
    }
}

@Model
public final class ProductionMemberModel {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var displayName: String
    public var roleRaw: String
    public var joinedAt: Date

    public var production: ProductionModel?

    public init(userId: String, displayName: String, role: ProductionRole) {
        self.id = UUID()
        self.userId = userId
        self.displayName = displayName
        self.roleRaw = role.rawValue
        self.joinedAt = .now
    }
}

@Model
public final class AuditEventModel {
    @Attribute(.unique) public var id: UUID
    public var fieldKey: String
    public var oldValue: String
    public var newValue: String
    public var userId: String
    public var timestamp: Date
    public var deviceId: String

    public var entry: LogEntryModel?

    public init(fieldKey: String, oldValue: String, newValue: String, userId: String, deviceId: String) {
        self.id = UUID()
        self.fieldKey = fieldKey
        self.oldValue = oldValue
        self.newValue = newValue
        self.userId = userId
        self.timestamp = .now
        self.deviceId = deviceId
    }
}

@Model
public final class PresenceRecordModel {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var displayName: String
    public var editingEntryLabel: String?
    public var lastHeartbeat: Date
    public var productionId: UUID

    public init(userId: String, displayName: String, productionId: UUID) {
        self.id = UUID()
        self.userId = userId
        self.displayName = displayName
        self.lastHeartbeat = .now
        self.productionId = productionId
    }
}