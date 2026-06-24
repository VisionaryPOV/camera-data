import SwiftUI
import CameraDataDomain

public enum ThemeTokens {
    public static let background = Color(red: 0.04, green: 0.04, blue: 0.05)
    public static let surface = Color(red: 0.08, green: 0.08, blue: 0.09)
    public static let accent = Color(red: 0.91, green: 0.66, blue: 0.22)
    public static let accentRed = Color(red: 0.77, green: 0.12, blue: 0.23)
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.7)
    public static let circled = accent
    public static let minTapTarget: CGFloat = 48
    public static let gloveTapTarget: CGFloat = 56

    public static func accent(for mode: ThemeMode) -> Color {
        mode == .nightRed ? accentRed : accent
    }
}

public struct CinematicTheme: EnvironmentKey {
    public static let defaultValue: ThemeMode = .cinematicDark
}

public extension EnvironmentValues {
    var cinematicTheme: ThemeMode {
        get { self[CinematicTheme.self] }
        set { self[CinematicTheme.self] = newValue }
    }
}