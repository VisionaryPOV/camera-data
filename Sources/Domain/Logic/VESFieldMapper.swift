import Foundation

/// VES-style standardized camera report field mapping for exports.
public enum VESFieldMapper {
    public static let standardFieldOrder: [String] = [
        "Scene", "Take", "Lens", "Filter", "ISO", "Shutter", "WhiteBalance",
        "FPS", "Resolution", "Codec", "Roll", "TimecodeIn", "TimecodeOut", "Duration", "Notes"
    ]

    public static func csvRow(from draft: LogEntryDraft) -> [String] {
        [
            draft.scene,
            String(draft.take),
            draft.lens,
            draft.filter,
            String(draft.iso),
            shutterDisplay(draft),
            draft.whiteBalance,
            String(draft.fps),
            draft.resolution,
            draft.codec,
            draft.rollNumber,
            draft.timecodeIn,
            draft.timecodeOut,
            draft.duration,
            draft.notes
        ]
    }

    public static func csvHeader() -> [String] { standardFieldOrder }

    public static func jsonDictionary(from draft: LogEntryDraft) -> [String: Any] {
        var dict: [String: Any] = [
            "scene": draft.scene,
            "take": draft.take,
            "lens": draft.lens,
            "filter": draft.filter,
            "iso": draft.iso,
            "shutter": shutterDisplay(draft),
            "whiteBalance": draft.whiteBalance,
            "fps": draft.fps,
            "resolution": draft.resolution,
            "codec": draft.codec,
            "roll": draft.rollNumber,
            "timecodeIn": draft.timecodeIn,
            "timecodeOut": draft.timecodeOut,
            "duration": draft.duration,
            "notes": draft.notes,
            "flags": flagsDictionary(from: draft)
        ]
        if !draft.customValues.isEmpty {
            dict["customFields"] = draft.customValues
        }
        return dict
    }

    public static func flagsDictionary(from draft: LogEntryDraft) -> [String: Bool] {
        [
            "circled": draft.isCircled,
            "mos": draft.isMOS,
            "pickup": draft.isPickup,
            "tail": draft.isTail,
            "hold": draft.isHold,
            "bad": draft.isBad,
            "series": draft.isSeries
        ]
    }

    private static func shutterDisplay(_ draft: LogEntryDraft) -> String {
        if let angle = draft.shutterAngle {
            return "\(angle)°"
        }
        return draft.shutterSpeed ?? ""
    }
}