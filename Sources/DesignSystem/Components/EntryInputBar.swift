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
    private let alphabetDigitRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private let qwertyRows = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]

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
            toolbar

            if inputMode == .keypad {
                numericKeypad
            } else {
                alphabeticKeypad
            }
        }
        .padding()
        .background(ThemeTokens.surface)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("Editing: \(focusedField.label)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ThemeTokens.accent)
            Spacer()
            if !canEdit {
                Text("Read-only")
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.9))
            }
            if focusedField == .rollNumber {
                Button("Next Roll", action: onNextRoll)
                    .font(.caption.weight(.semibold))
                    .disabled(!canEdit)
            }
            Button(inputMode == .keypad ? "ABC" : "123", action: onToggleInputMode)
                .font(.caption.weight(.semibold))
                .frame(minWidth: 44, minHeight: ThemeTokens.minTapTarget)
                .buttonStyle(.plain)
                .disabled(!canEdit)
            Button("SmartFill", action: onSmartFill)
                .font(.caption.weight(.semibold))
                .disabled(!canEdit)
        }
    }

    @ViewBuilder
    private var numericKeypad: some View {
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
                        timecodeOrDecimalKey
                    } else {
                        keypadKey(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var timecodeOrDecimalKey: some View {
        if focusedField.supportsTimecodeInput {
            keypadKey(":", action: { onKey(":") })
        } else {
            keypadKey(".", action: { onKey(".") })
                .opacity(focusedField == .fps || focusedField == .scene ? 1 : 0.35)
                .disabled(!(focusedField == .fps || focusedField == .scene))
        }
    }

    private var alphabeticKeypad: some View {
        VStack(spacing: 8) {
            ForEach(qwertyRows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { key in
                        keypadKey(key)
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(alphabetDigitRow, id: \.self) { digit in
                    keypadKey(digit)
                }
            }

            HStack(spacing: 8) {
                keypadKey("⌫", action: onDelete)
                    .frame(maxWidth: 72)
                keypadKey("Space", label: "␣", action: { onKey(" ") })
                if focusedField == .scene || focusedField == .rollNumber || focusedField == .fps {
                    keypadKey(".", action: { onKey(".") })
                        .frame(maxWidth: 56)
                }
                if focusedField.supportsTimecodeInput {
                    keypadKey(":", action: { onKey(":") })
                        .frame(maxWidth: 56)
                }
                keypadKey("-", action: { onKey("-") })
                    .frame(maxWidth: 56)
            }
        }
    }

    private func keypadKey(_ label: String, action: (() -> Void)? = nil) -> some View {
        keypadKey(label, label: label, action: action)
    }

    private func keypadKey(_ label: String, label display: String, action: (() -> Void)? = nil) -> some View {
        Button(action: { (action ?? { onKey(label) })() }) {
            Text(display)
                .font(.title3.monospacedDigit().weight(.medium))
                .foregroundStyle(ThemeTokens.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: ThemeTokens.minTapTarget)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.borderless)
        .disabled(!canEdit)
    }
}