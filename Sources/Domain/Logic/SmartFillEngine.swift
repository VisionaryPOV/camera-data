import Foundation

public enum SmartFillEngine {
    /// Rule-based SmartFill v1: carry forward from last entry and camera defaults.
    public static func apply(
        to draft: LogEntryDraft,
        lastEntry: LogEntryDraft?,
        cameraDefaults: LogEntryDraft?
    ) -> LogEntryDraft {
        var result = draft
        let source = lastEntry ?? cameraDefaults
        guard let source else { return result }

        if result.lens.isEmpty, !source.lens.isEmpty { result.lens = source.lens }
        if result.filter.isEmpty, !source.filter.isEmpty { result.filter = source.filter }
        if result.iso == 800, source.iso != 800 { result.iso = source.iso }
        if result.whiteBalance == "5600K", source.whiteBalance != "5600K" { result.whiteBalance = source.whiteBalance }
        if result.fps == 24, source.fps != 24 { result.fps = source.fps }
        if result.resolution == "4K", source.resolution != "4K" { result.resolution = source.resolution }
        if result.codec == "ProRes", source.codec != "ProRes" { result.codec = source.codec }
        if result.rollNumber.isEmpty, !source.rollNumber.isEmpty { result.rollNumber = source.rollNumber }
        if result.shutterAngle == nil { result.shutterAngle = source.shutterAngle }
        if result.shutterSpeed == nil { result.shutterSpeed = source.shutterSpeed }

        for (key, value) in source.customValues where result.customValues[key] == nil {
            result.customValues[key] = value
        }
        return result
    }
}

public enum SmartSuggestEngine {
    /// ML-based SmartSuggest 2.0 stub: frequency analysis from historical entries.
    public static func suggest(
        from history: [LogEntryDraft],
        for draft: LogEntryDraft
    ) -> [SmartSuggestion] {
        guard !history.isEmpty else { return [] }

        var suggestions: [SmartSuggestion] = []

        let sameScene = history.filter { $0.scene == draft.scene }
        if draft.lens.isEmpty {
            let lensCounts = Dictionary(grouping: sameScene.map(\.lens).filter { !$0.isEmpty }, by: { $0 })
            if let top = lensCounts.max(by: { $0.value.count < $1.value.count }) {
                let confidence = Double(top.value.count) / Double(max(1, sameScene.count))
                suggestions.append(SmartSuggestion(field: "lens", value: top.key, confidence: confidence))
            }
        }

        if draft.iso == 800 {
            let isoCounts = Dictionary(grouping: sameScene.map(\.iso), by: { $0 })
            if let top = isoCounts.max(by: { $0.value.count < $1.value.count }) {
                let confidence = Double(top.value.count) / Double(max(1, sameScene.count))
                suggestions.append(SmartSuggestion(field: "iso", value: String(top.key), confidence: confidence))
            }
        }

        return suggestions.filter { $0.confidence >= 0.3 }
    }
}