import SwiftUI
import CameraDataDesignSystem

public struct DigitalSlateView: View {
    @Binding public var scene: String
    @Binding public var take: Int
    @Binding public var isRolling: Bool
    public var onIncrementTake: () -> Void

    public init(
        scene: Binding<String>,
        take: Binding<Int>,
        isRolling: Binding<Bool>,
        onIncrementTake: @escaping () -> Void
    ) {
        self._scene = scene
        self._take = take
        self._isRolling = isRolling
        self.onIncrementTake = onIncrementTake
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                Text("DIGITAL SLATE")
                    .font(.caption)
                    .foregroundStyle(ThemeTokens.textSecondary)
                Text("SCENE")
                    .font(.title3)
                    .foregroundStyle(ThemeTokens.accent)
                Text(scene.isEmpty ? "—" : scene)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("TAKE")
                    .font(.title3)
                    .foregroundStyle(ThemeTokens.accent)
                Text("\(take)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if isRolling {
                    HStack(spacing: 8) {
                        Circle().fill(Color.red).frame(width: 16, height: 16)
                        Text("ROLLING").foregroundStyle(.red).font(.headline)
                    }
                }
                GlassButton("Next Take", isPrimary: true) {
                    onIncrementTake()
                    HapticManager.medium()
                }
                .frame(maxWidth: 280)
            }
        }
    }
}