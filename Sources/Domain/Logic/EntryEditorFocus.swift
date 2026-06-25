import Foundation

public enum EntryEditorFocus: String, Equatable, CaseIterable, Sendable {
    case scene
    case take
    case rollNumber
    case lens
    case filter
    case iso
    case fps
    case whiteBalance
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
        case .whiteBalance: "WB"
        case .notes: "Notes"
        }
    }

    public var usesNumericKeypad: Bool {
        switch self {
        case .take, .iso, .fps: true
        case .scene, .rollNumber, .lens, .filter, .whiteBalance, .notes: false
        }
    }

    public var supportsLetterRow: Bool {
        switch self {
        case .scene, .rollNumber: true
        default: false
        }
    }
}

public enum EntryInputMode: Equatable, Sendable {
    case keypad
    case keyboard
}