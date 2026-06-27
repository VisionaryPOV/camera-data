import Foundation

public enum EntryEditorFocus: String, Equatable, CaseIterable, Sendable {
    case scene
    case take
    case rollNumber
    case lens
    case filter
    case iso
    case fps
    case shutterAngle
    case shutterSpeed
    case whiteBalance
    case resolution
    case codec
    case timecodeIn
    case timecodeOut
    case duration
    case notes

    public var label: String {
        switch self {
        case .scene: "Scene"
        case .take: "Take"
        case .rollNumber: "Roll"
        case .lens: "Lens"
        case .filter: "Filter"
        case .iso: "ISO"
        case .fps: "FPS"
        case .shutterAngle: "Shutter °"
        case .shutterSpeed: "Shutter"
        case .whiteBalance: "WB"
        case .resolution: "Resolution"
        case .codec: "Codec"
        case .timecodeIn: "TC In"
        case .timecodeOut: "TC Out"
        case .duration: "Duration"
        case .notes: "Notes"
        }
    }

    public var usesNumericKeypad: Bool {
        switch self {
        case .take, .iso, .fps, .shutterAngle: true
        case .scene, .rollNumber, .lens, .filter, .shutterSpeed, .whiteBalance,
             .resolution, .codec, .timecodeIn, .timecodeOut, .duration, .notes: false
        }
    }

    public var supportsLetterRow: Bool {
        switch self {
        case .scene, .rollNumber, .resolution, .codec: true
        default: false
        }
    }

    public var supportsTimecodeInput: Bool {
        switch self {
        case .timecodeIn, .timecodeOut, .duration: true
        default: false
        }
    }
}

public enum EntryInputMode: Equatable, Sendable {
    case keypad
    case keyboard
}