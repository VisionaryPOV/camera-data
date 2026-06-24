import SwiftUI
import CameraDataDesignSystem

public struct OnboardingView: View {
    public var onComplete: () -> Void

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Camera Data")
                .font(.largeTitle.bold())
                .foregroundStyle(ThemeTokens.textPrimary)
            Text("Log your first take in under 60 seconds.")
                .multilineTextAlignment(.center)
                .foregroundStyle(ThemeTokens.textSecondary)
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Start").font(.headline)
                    Text("• Choose a production template")
                    Text("• Tap + to log Scene / Take")
                    Text("• SmartFill carries lens & ISO forward")
                }
                .foregroundStyle(ThemeTokens.textPrimary)
            }
            GlassButton("Get Started", isPrimary: true, action: onComplete)
            Spacer()
        }
        .padding()
        .background(ThemeTokens.background)
    }
}