import Foundation

public enum ProductionRole: String, Codable, CaseIterable, Sendable {
    case admin
    case editor
    case readOnly
    case vfx

    public var canEdit: Bool {
        switch self {
        case .admin, .editor: true
        case .readOnly, .vfx: false
        }
    }

    public var seesVFXNotes: Bool {
        self == .vfx || self == .admin || self == .editor
    }
}

public enum CustomFieldType: String, Codable, CaseIterable, Sendable {
    case text, number, picker, bool, date, timecode
}

public enum AttachmentType: String, Codable, Sendable {
    case photo, video, reference
}

public enum ExportFormat: String, Codable, Sendable {
    case pdf, csv, json
}

public enum ThemeMode: String, Codable, Sendable {
    case cinematicDark
    case nightRed
}

public struct ProductionMetadata: Equatable, Sendable, Codable {
    public var productionTitle: String
    public var directorName: String
    public var dpName: String
    public var episodeOrProductionNumber: String

    public init(
        productionTitle: String = "",
        directorName: String = "",
        dpName: String = "",
        episodeOrProductionNumber: String = ""
    ) {
        self.productionTitle = productionTitle
        self.directorName = directorName
        self.dpName = dpName
        self.episodeOrProductionNumber = episodeOrProductionNumber
    }

    public var crewCreditsLine: String {
        var parts: [String] = []
        if !directorName.isEmpty { parts.append("Director: \(directorName)") }
        if !dpName.isEmpty { parts.append("DP: \(dpName)") }
        if !episodeOrProductionNumber.isEmpty { parts.append("Ep/Prod: \(episodeOrProductionNumber)") }
        return parts.joined(separator: "  •  ")
    }
}

public struct SyncMetadata: Codable, Equatable, Sendable {
    public var ckRecordName: String?
    public var shareURL: String?
    public var revision: Int

    public init(ckRecordName: String? = nil, shareURL: String? = nil, revision: Int = 0) {
        self.ckRecordName = ckRecordName
        self.shareURL = shareURL
        self.revision = revision
    }
}

public struct LogEntryDraft: Equatable, Sendable {
    public var scene: String
    public var take: Int
    public var setup: String?
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
    public var duration: String
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
    public var customValues: [String: String]

    public init(
        scene: String = "",
        take: Int = 1,
        setup: String? = nil,
        lens: String = "",
        filter: String = "",
        iso: Int = 800,
        shutterAngle: Double? = 180,
        shutterSpeed: String? = nil,
        whiteBalance: String = "5600K",
        fps: Double = 24,
        resolution: String = "4K",
        codec: String = "ProRes",
        rollNumber: String = "",
        timecodeIn: String = "00:00:00:00",
        timecodeOut: String = "",
        duration: String = "",
        notes: String = "",
        scriptNotes: String = "",
        vfxNotes: String = "",
        isCircled: Bool = false,
        isMOS: Bool = false,
        isPickup: Bool = false,
        isTail: Bool = false,
        isHold: Bool = false,
        isBad: Bool = false,
        isSeries: Bool = false,
        customValues: [String: String] = [:]
    ) {
        self.scene = scene
        self.take = take
        self.setup = setup
        self.lens = lens
        self.filter = filter
        self.iso = iso
        self.shutterAngle = shutterAngle
        self.shutterSpeed = shutterSpeed
        self.whiteBalance = whiteBalance
        self.fps = fps
        self.resolution = resolution
        self.codec = codec
        self.rollNumber = rollNumber
        self.timecodeIn = timecodeIn
        self.timecodeOut = timecodeOut
        self.duration = duration
        self.notes = notes
        self.scriptNotes = scriptNotes
        self.vfxNotes = vfxNotes
        self.isCircled = isCircled
        self.isMOS = isMOS
        self.isPickup = isPickup
        self.isTail = isTail
        self.isHold = isHold
        self.isBad = isBad
        self.isSeries = isSeries
        self.customValues = customValues
    }
}

public struct CaptureContext: Codable, Equatable, Sendable {
    public var latitude: Double?
    public var longitude: Double?
    public var altitude: Double?
    public var pitch: Double?
    public var roll: Double?
    public var yaw: Double?

    public init(
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil,
        pitch: Double? = nil,
        roll: Double? = nil,
        yaw: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
    }
}

public struct DashboardStats: Equatable, Sendable {
    public var takeCount: Int
    public var circledCount: Int
    public var dominantLens: String?
    public var takesPerHour: Double

    public init(takeCount: Int, circledCount: Int, dominantLens: String?, takesPerHour: Double) {
        self.takeCount = takeCount
        self.circledCount = circledCount
        self.dominantLens = dominantLens
        self.takesPerHour = takesPerHour
    }
}

public struct PresenceInfo: Equatable, Sendable {
    public var userId: String
    public var displayName: String
    public var editingEntryLabel: String?
    public var lastHeartbeat: Date

    public init(userId: String, displayName: String, editingEntryLabel: String? = nil, lastHeartbeat: Date) {
        self.userId = userId
        self.displayName = displayName
        self.editingEntryLabel = editingEntryLabel
        self.lastHeartbeat = lastHeartbeat
    }
}

public struct ConflictField: Equatable, Sendable {
    public var key: String
    public var localValue: String
    public var remoteValue: String

    public init(key: String, localValue: String, remoteValue: String) {
        self.key = key
        self.localValue = localValue
        self.remoteValue = remoteValue
    }
}

public struct SmartSuggestion: Equatable, Sendable {
    public var field: String
    public var value: String
    public var confidence: Double

    public init(field: String, value: String, confidence: Double) {
        self.field = field
        self.value = value
        self.confidence = confidence
    }
}