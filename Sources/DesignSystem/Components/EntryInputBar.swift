import SwiftUI
import CameraDataDomain

public struct EntryInputBar: View {
    public let inputMode: EntryInputMode
    public let focusedField: EntryEditorFocus
    public let canEdit: Bool
    public var onKey: (String) -> Void
    public var onDelete: () -> Void
    public var onToggleInputMode: () -> Void
    public var onSmartFill: () -> Void
    public var onNextRoll: () -> Void

    private let digitRows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["⌫", "0", "•"]]
    private let letterRow = ["A", "B", "C", "D", "E", "F"]

    public init(
        inputMode: EntryInputMode,
        focusedField: EntryEditorFocus,
        canEdit: Bool,
        onKey: @escaping (String) -> Void,
        onDelete: @escaping () -> Void,
        onToggleInputMode: @escaping () -> Void,
        onSmartFill: @escaping () -> Void,
        onNextRoll: @escaping () -> Void
    ) {
        self.inputMode = inputMode
        self.focusedField = focusedField
        self.canEdit = canEdit
        self.onKey = onKey
        self.onDelete = onDelete
        self.onToggleInputMode = onToggleInputMode
        self.onSmartFill = onSmartFill
        self.onNextRoll = onNextRoll
    }

    public var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("Editing: \(focusedField.label)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ThemeTokens.accent)
                Spacer()
                if focusedField == .rollNumber {
                    Button("Next Roll", action: onNextRoll)
                        .font(.caption.weight(.semibold))
                        .disabled(!canEdit)
                }
                Button(inputMode == .keypad ? "ABC" : "123", action: onToggleInputMode)
                    .font(.caption.weight(.semibold))
                    .frame(minWidth: 44, minHeight: ThemeTokens.minTapTarget)
                Button("SmartFill", action: onSmartFill)
                    .font(.caption.weight(.semibold))
                    .disabled(!canEdit)
            }

            if inputMode == .keypad {
                if focusedField.supportsLetterRow {
                    HStack(spacing: 6) {
                        ForEach(letterRow, id: \.self) { letter in
                            keypadKey(letter)
                        }
                    }
                }

                ForEach(digitRows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { key in
                            if key == "⌫" {
                                keypadKey("⌫", action: onDelete)
                            } else if key == "•" {
                                keypadKey(".", action: { onKey(".") })
                                    .opacity(focusedField == .fps || focusedField == .scene ? 1 : 0.35)
                                    .disabled(!(focusedField == .fps || focusedField == .scene))
                            } else {
                                keypadKey(key)
                            }
                        }
                    }
                }
            } else {
                Text("Use the system keyboard for \(focusedField.label)")
                    .font(.caption)
                    .foregroundStyle(ThemeTokens.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(ThemeTokens.surface)
    }

    private func keypadKey(_ label: String, action: (() -> Void)? = nil) -> some View {
        Button(action: { (action ?? { onKey(label) })() }) {
            Text(label)
                .font(.title3.monospacedDigit().weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: ThemeTokens.minTapTarget)
                .glassSurface(interactive: true)
        }
        .buttonStyle(.plain)
        .disabled(!canEdit)
    }
}