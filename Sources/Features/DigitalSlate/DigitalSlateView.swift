import SwiftUI
import CameraDataDesignSystem
import CameraDataDomain

public struct DigitalSlateView: View {
    @Binding public var scene: String
    @Binding public var take: Int
    @Binding public var isRolling: Bool
    public var onIncrementTake: () -> Void
    public var onDismiss: () -> Void

    public init(
        scene: Binding<String>,
        take: Binding<Int>,
        isRolling: Binding<Bool>,
        onIncrementTake: @escaping () -> Void,
        onDismiss: @escaping () -> Void = {}
    ) {
        self._scene = scene
        self._take = take
        self._isRolling = isRolling
        self.onIncrementTake = onIncrementTake
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(SlateTimeFormatter.timeOfDay(from: context.date))
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .foregroundStyle(ThemeTokens.textSecondary)
                        .monospacedDigit()
                }
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
                HStack(spacing: 16) {
                    GlassButton(isRolling ? "Stop Rolling" : "Start Rolling", isPrimary: false) {
                        isRolling.toggle()
                        HapticManager.light()
                    }
                    .frame(maxWidth: 160)
                    GlassButton("Next Take", isPrimary: true) {
                        onIncrementTake()
                        HapticManager.medium()
                    }
                    .frame(maxWidth: 160)
                }
            }
            .padding()
        }
        .onAppear {
            NSLog(
                "[CameraData] slate_view_appeared=true scene=%@ take=%d rolling=%@",
                scene,
                take,
                isRolling ? "true" : "false"
            )
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(24)
            .accessibilityLabel("Close slate")
        }
    }
}