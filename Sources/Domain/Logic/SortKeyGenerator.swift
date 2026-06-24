import Foundation

public enum SortKeyGenerator {
    /// Produces a lexicographically sortable key: scene padded + take padded.
    public static func make(scene: String, take: Int) -> String {
        let normalizedScene = scene.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let scenePart = normalizedScene.isEmpty ? "000" : normalizedScene
        let takePart = String(format: "%04d", max(0, take))
        return "\(scenePart)#\(takePart)"
    }

    public static func compare(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
}