import Foundation

public enum TakeIncrementer {
    public static func nextTake(after current: Int, existingTakesForScene: [Int]) -> Int {
        guard !existingTakesForScene.isEmpty else {
            return max(1, current + 1)
        }
        let maxExisting = existingTakesForScene.max() ?? current
        return max(current + 1, maxExisting + 1)
    }

    public static func suggestedTake(for scene: String, existing: [(scene: String, take: Int)]) -> Int {
        let sceneTakes = existing.filter { $0.scene == scene }.map(\.take)
        if sceneTakes.isEmpty { return 1 }
        return (sceneTakes.max() ?? 0) + 1
    }
}