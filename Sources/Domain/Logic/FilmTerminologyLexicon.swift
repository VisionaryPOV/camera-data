import Foundation

/// Film-specific terminology for voice-to-log processing.
public enum FilmTerminologyLexicon {
    public static let replacements: [String: String] = [
        "mos": "MOS",
        "m.o.s": "MOS",
        "pickup": "PU",
        "p.u.": "PU",
        "pu": "PU",
        "tails": "TAILS",
        "tail": "TAILS",
        "circle take": "CIRCLED",
        "circled": "CIRCLED",
        "hold": "HOLD",
        "bad take": "BAD",
        "series": "SERIES",
        "jam sync": "JAM SYNC",
        "timecode": "TC",
        "four k": "4K",
        "six k": "6K",
        "eight k": "8K",
        "prores": "ProRes",
        "arri": "ARRI",
        "zeiss": "Zeiss",
        "cooke": "Cooke",
        "anamorphic": "Anamorphic",
        "super thirty five": "Super35",
        "super 35": "Super35"
    ]

    public static func processTranscript(_ text: String) -> VoiceLogParseResult {
        var normalized = text.lowercased()
        var flags: Set<String> = []
        var scene: String?
        var take: Int?

        for (spoken, canonical) in replacements {
            if normalized.contains(spoken) {
                normalized = normalized.replacingOccurrences(of: spoken, with: canonical.lowercased())
                if ["MOS", "PU", "TAILS", "CIRCLED", "HOLD", "BAD", "SERIES"].contains(canonical) {
                    flags.insert(canonical)
                }
            }
        }

        if let sceneMatch = normalized.range(of: #"scene\s+(\w+)"#, options: .regularExpression) {
            let segment = String(normalized[sceneMatch])
            let parts = segment.split(separator: " ")
            if parts.count >= 2 { scene = String(parts[1]).uppercased() }
        }

        if let takeMatch = normalized.range(of: #"take\s+(\d+)"#, options: .regularExpression) {
            let segment = String(normalized[takeMatch])
            let parts = segment.split(separator: " ")
            if parts.count >= 2, let num = Int(parts[1]) { take = num }
        }

        return VoiceLogParseResult(
            normalizedText: normalized,
            scene: scene,
            take: take,
            flags: Array(flags).sorted()
        )
    }
}

public struct VoiceLogParseResult: Equatable, Sendable {
    public var normalizedText: String
    public var scene: String?
    public var take: Int?
    public var flags: [String]

    public init(normalizedText: String, scene: String?, take: Int?, flags: [String]) {
        self.normalizedText = normalizedText
        self.scene = scene
        self.take = take
        self.flags = flags
    }
}