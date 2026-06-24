import Foundation

public struct ParsedSearchQuery: Equatable, Sendable {
    public var scene: String?
    public var lensContains: String?
    public var circledOnly: Bool
    public var rawTerms: [String]

    public init(scene: String? = nil, lensContains: String? = nil, circledOnly: Bool = false, rawTerms: [String] = []) {
        self.scene = scene
        self.lensContains = lensContains
        self.circledOnly = circledOnly
        self.rawTerms = rawTerms
    }
}

/// Natural language search parser (Phase 3).
public enum NLPQueryParser {
    public static func parse(_ query: String) -> ParsedSearchQuery {
        let lowered = query.lowercased()
        var result = ParsedSearchQuery(rawTerms: query.split(separator: " ").map(String.init))

        if let sceneRange = lowered.range(of: #"scene\s+(\w+)"#, options: .regularExpression) {
            let match = String(lowered[sceneRange])
            let parts = match.split(separator: " ")
            if parts.count >= 2 { result.scene = String(parts[1]).uppercased() }
        }

        if lowered.contains("anamorphic") || lowered.contains("lens") {
            if lowered.contains("anamorphic") {
                result.lensContains = "anamorphic"
            }
        }

        if lowered.contains("circled") {
            result.circledOnly = true
        }

        return result
    }

    public static func matches(_ draft: LogEntryDraft, query: ParsedSearchQuery) -> Bool {
        if let scene = query.scene, draft.scene.uppercased() != scene { return false }
        if query.circledOnly, !draft.isCircled { return false }
        if let lens = query.lensContains {
            guard draft.lens.lowercased().contains(lens) else { return false }
        }
        if !query.rawTerms.isEmpty, query.scene == nil, !query.circledOnly, query.lensContains == nil {
            let haystack = "\(draft.scene) \(draft.lens) \(draft.notes)".lowercased()
            return query.rawTerms.allSatisfy { haystack.contains($0.lowercased()) }
        }
        return true
    }
}