import Foundation

public enum AppGroupStore {
    public static let suiteName = "group.com.visionarypov.cameradata"
    private static let takeCountKey = "widgetTakeCount"
    private static let productionNameKey = "widgetProductionName"

    public static func writeWidgetSnapshot(takeCount: Int, productionName: String) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(takeCount, forKey: takeCountKey)
        defaults.set(productionName, forKey: productionNameKey)
    }

    public static func readWidgetSnapshot() -> (takeCount: Int, productionName: String) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return (0, "Camera Data")
        }
        let count = defaults.integer(forKey: takeCountKey)
        let name = defaults.string(forKey: productionNameKey) ?? "Camera Data"
        return (count, name)
    }
}