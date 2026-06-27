import Foundation

public struct SlateFrameRateOption: Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let value: Double?

    public init(id: String, label: String, value: Double?) {
        self.id = id
        self.label = label
        self.value = value
    }

    public static let presets: [SlateFrameRateOption] = [
        SlateFrameRateOption(id: "23.976", label: "23.976", value: 23.976),
        SlateFrameRateOption(id: "24", label: "24", value: 24),
        SlateFrameRateOption(id: "25", label: "25", value: 25),
        SlateFrameRateOption(id: "29.97", label: "29.97", value: 29.97),
        SlateFrameRateOption(id: "30", label: "30", value: 30),
        SlateFrameRateOption(id: "48", label: "48", value: 48),
        SlateFrameRateOption(id: "50", label: "50", value: 50),
        SlateFrameRateOption(id: "59.94", label: "59.94", value: 59.94),
        SlateFrameRateOption(id: "60", label: "60", value: 60),
        SlateFrameRateOption(id: "120", label: "120", value: 120),
        SlateFrameRateOption(id: "240", label: "240", value: 240),
        SlateFrameRateOption(id: "manual", label: "Manual", value: nil)
    ]
}

public struct SlateWhiteBalanceOption: Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let kelvin: Int?

    public init(id: String, label: String, kelvin: Int?) {
        self.id = id
        self.label = label
        self.kelvin = kelvin
    }

    public static let presets: [SlateWhiteBalanceOption] = [
        SlateWhiteBalanceOption(id: "3200", label: "3200K", kelvin: 3200),
        SlateWhiteBalanceOption(id: "4300", label: "4300K", kelvin: 4300),
        SlateWhiteBalanceOption(id: "4500", label: "4500K", kelvin: 4500),
        SlateWhiteBalanceOption(id: "5000", label: "5000K", kelvin: 5000),
        SlateWhiteBalanceOption(id: "5600", label: "5600K", kelvin: 5600),
        SlateWhiteBalanceOption(id: "6000", label: "6000K", kelvin: 6000),
        SlateWhiteBalanceOption(id: "6500", label: "6500K", kelvin: 6500),
        SlateWhiteBalanceOption(id: "manual", label: "Manual", kelvin: nil)
    ]
}

public enum SlateSettingsResolver {
    public static func resolvedFPS(presetID: String, manualFPS: Double) -> Double {
        if let preset = SlateFrameRateOption.presets.first(where: { $0.id == presetID }),
           let value = preset.value {
            return value
        }
        return max(manualFPS, 1)
    }

    public static func resolvedWhiteBalanceLabel(presetID: String, manualKelvin: Int) -> String {
        if let preset = SlateWhiteBalanceOption.presets.first(where: { $0.id == presetID }),
           preset.kelvin != nil {
            return preset.label
        }
        return "\(max(manualKelvin, 1000))K"
    }
}