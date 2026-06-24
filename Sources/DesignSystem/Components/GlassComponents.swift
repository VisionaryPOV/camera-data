import SwiftUI

public struct GlassSurface: ViewModifier {
    public var interactive: Bool

    public init(interactive: Bool = false) {
        self.interactive = interactive
    }

    public func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(interactive ? .regular.interactive() : .regular)
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

public extension View {
    public func glassSurface(interactive: Bool = false) -> some View {
        modifier(GlassSurface(interactive: interactive))
    }
}

public struct GlassButton: View {
    public let title: String
    public let action: () -> Void
    public var isPrimary: Bool

    public init(_ title: String, isPrimary: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isPrimary = isPrimary
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: ThemeTokens.minTapTarget)
                .foregroundStyle(isPrimary ? Color.black : ThemeTokens.textPrimary)
                .glassSurface(interactive: true)
                .background(isPrimary ? ThemeTokens.accent : Color.clear, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

public struct GlassKeypadKey: View {
    public let label: String
    public let action: () -> Void

    public init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(label)
                .font(.title2.monospacedDigit())
                .frame(width: 72, height: ThemeTokens.minTapTarget)
                .glassSurface(interactive: true)
        }
        .buttonStyle(.plain)
    }
}

public struct GlassChip: View {
    public let title: String
    public var isSelected: Bool

    public init(_ title: String, isSelected: Bool = false) {
        self.title = title
        self.isSelected = isSelected
    }

    public var body: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.black : ThemeTokens.textPrimary)
            .glassSurface(interactive: isSelected)
            .background(isSelected ? ThemeTokens.accent : Color.clear, in: Capsule())
    }
}

public struct GlassCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface()
            .background(ThemeTokens.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
    }
}

public struct FloatingLogButton: View {
    public let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.black)
                .frame(width: 60, height: 60)
                .background(ThemeTokens.accent, in: Circle())
                .glassSurface(interactive: true)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log Take")
    }
}