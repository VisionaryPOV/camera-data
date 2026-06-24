import Foundation

public enum SortKeyGenerator {
    /// Produces a lexicographically sortable key with natural numeric scene ordering.
    /// Scene "2" sorts before "10"; take is zero-padded.
    public static func make(scene: String, take: Int) -> String {
        let scenePart = naturalSceneKey(scene)
        let takePart = String(format: "%04d", max(0, take))
        return "\(scenePart)#\(takePart)"
    }

    public static func compare(_ lhs: String, _ rhs: String) -> Bool {
        lhs < rhs
    }

    /// Converts scene labels like "2", "10", "12A" into a sortable segment.
    public static func naturalSceneKey(_ scene: String) -> String {
        let normalized = scene.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return "000000" }

        let digits = normalized.prefix(while: \.isNumber)
        let suffix = String(normalized.dropFirst(digits.count))
        let numeric = Int(digits) ?? 0
        return String(format: "%06d", numeric) + suffix
    }
}