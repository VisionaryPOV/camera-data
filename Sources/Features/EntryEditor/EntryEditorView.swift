import SwiftUI
import CameraDataDesignSystem
import CameraDataDomain

public struct EntryEditorView: View {
    @Bindable public var viewModel: EntryEditorViewModel
    public var onDismiss: () -> Void
    @FocusState private var keyboardFocus: EntryEditorFocus?

    public init(viewModel: EntryEditorViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                primaryFieldsRow
                secondaryFieldsGrid
                suggestionsSection
                flagsSection

                if let message = viewModel.validationMessage {
                    Text(message).foregroundStyle(.red).font(.caption)
                }
                if let voiceStatus = viewModel.voiceStatusMessage {
                    Text(voiceStatus).foregroundStyle(ThemeTokens.accent).font(.caption)
                }

                GlassButton("Log & Next", isPrimary: true) {
                    Task { try? await viewModel.logAndNext() }
                }
                .disabled(viewModel.isSaving || !viewModel.canEdit)
            }
            .padding()
            .padding(.bottom, viewModel.inputMode == .keypad ? 220 : 120)
        }
        .background(ThemeTokens.background)
        .navigationTitle("Log Take")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: onDismiss)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await viewModel.processVoiceLog() }
                } label: {
                    Image(systemName: viewModel.isProcessingVoice ? "waveform.circle.fill" : "mic.circle")
                }
                .disabled(!viewModel.canEdit || viewModel.isProcessingVoice)
                .accessibilityLabel("Voice to log")
                Button("SmartFill") { viewModel.applySmartFill() }
                    .disabled(!viewModel.canEdit)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.inputMode == .keypad {
                EntryInputBar(
                    inputMode: viewModel.inputMode,
                    focusedField: viewModel.focusedField,
                    canEdit: viewModel.canEdit,
                    onKey: { viewModel.inputKey($0) },
                    onDelete: { viewModel.deleteBackward() },
                    onToggleInputMode: { viewModel.toggleInputMode() },
                    onSmartFill: { viewModel.applySmartFill() },
                    onNextRoll: { viewModel.advanceRollNumber() }
                )
            } else {
                keyboardInputBar
            }
        }
        .onAppear { try? viewModel.onAppear() }
        .onChange(of: viewModel.focusedField) { _, field in
            if viewModel.inputMode == .keyboard {
                keyboardFocus = field
            }
        }
        .onChange(of: viewModel.inputMode) { _, mode in
            keyboardFocus = mode == .keyboard ? viewModel.focusedField : nil
        }
    }

    private var primaryFieldsRow: some View {
        HStack(spacing: 10) {
            fieldCard(.scene)
            fieldCard(.take)
            fieldCard(.rollNumber)
        }
    }

    private var secondaryFieldsGrid: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                fieldCard(.lens)
                fieldCard(.iso)
                fieldCard(.fps)
                fieldCard(.filter)
                fieldCard(.shutterAngle)
                fieldCard(.shutterSpeed)
                fieldCard(.whiteBalance)
                fieldCard(.resolution)
                fieldCard(.codec)
                fieldCard(.timecodeIn)
                fieldCard(.timecodeOut)
                fieldCard(.duration)
            }
            fieldCard(.notes)
        }
    }

    private func fieldCard(_ field: EntryEditorFocus) -> some View {
        let isFocused = viewModel.focusedField == field

        return Button {
            viewModel.focus(field)
            if viewModel.inputMode == .keyboard {
                keyboardFocus = field
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(field.label)
                    .font(.caption)
                    .foregroundStyle(ThemeTokens.textSecondary)
                if viewModel.inputMode == .keyboard, isFocused, field != .take, field != .iso {
                    keyboardField(for: field)
                } else {
                    Text(viewModel.displayValue(for: field))
                        .font(field == .notes ? .body : .title2.monospacedDigit())
                        .foregroundStyle(ThemeTokens.textPrimary)
                        .lineLimit(field == .notes ? 3 : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: ThemeTokens.minTapTarget, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? ThemeTokens.accent : Color.white.opacity(0.15), lineWidth: isFocused ? 2 : 1)
            )
            .glassSurface(interactive: isFocused)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canEdit)
    }

    @ViewBuilder
    private func keyboardField(for field: EntryEditorFocus) -> some View {
        switch field {
        case .scene:
            TextField("Scene", text: $viewModel.draft.scene)
                .focused($keyboardFocus, equals: .scene)
        case .rollNumber:
            TextField("Roll", text: $viewModel.draft.rollNumber)
                .textInputAutocapitalization(.characters)
                .focused($keyboardFocus, equals: .rollNumber)
        case .lens:
            TextField("Lens", text: $viewModel.draft.lens)
                .focused($keyboardFocus, equals: .lens)
        case .filter:
            TextField("Filter", text: $viewModel.draft.filter)
                .focused($keyboardFocus, equals: .filter)
        case .fps:
            TextField("FPS", text: $viewModel.fpsText)
                .keyboardType(.decimalPad)
                .focused($keyboardFocus, equals: .fps)
                .onChange(of: viewModel.fpsText) { _, _ in viewModel.syncFPSTextToDraft() }
        case .shutterAngle:
            TextField("Shutter °", text: $viewModel.shutterAngleText)
                .keyboardType(.decimalPad)
                .focused($keyboardFocus, equals: .shutterAngle)
                .onChange(of: viewModel.shutterAngleText) { _, _ in viewModel.syncShutterAngleTextToDraft() }
        case .shutterSpeed:
            TextField("Shutter", text: Binding(
                get: { viewModel.draft.shutterSpeed ?? "" },
                set: { viewModel.draft.shutterSpeed = $0.isEmpty ? nil : $0 }
            ))
            .focused($keyboardFocus, equals: .shutterSpeed)
        case .resolution:
            TextField("Resolution", text: $viewModel.draft.resolution)
                .focused($keyboardFocus, equals: .resolution)
        case .codec:
            TextField("Codec", text: $viewModel.draft.codec)
                .focused($keyboardFocus, equals: .codec)
        case .timecodeIn:
            TextField("TC In", text: $viewModel.draft.timecodeIn)
                .focused($keyboardFocus, equals: .timecodeIn)
        case .timecodeOut:
            TextField("TC Out", text: $viewModel.draft.timecodeOut)
                .focused($keyboardFocus, equals: .timecodeOut)
        case .duration:
            TextField("Duration", text: $viewModel.draft.duration)
                .focused($keyboardFocus, equals: .duration)
        case .whiteBalance:
            TextField("WB", text: $viewModel.draft.whiteBalance)
                .focused($keyboardFocus, equals: .whiteBalance)
        case .notes:
            TextField("Notes", text: $viewModel.draft.notes, axis: .vertical)
                .lineLimit(2...4)
                .focused($keyboardFocus, equals: .notes)
        case .take, .iso:
            EmptyView()
        }
    }

    private var keyboardInputBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Editing: \(viewModel.focusedField.label)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ThemeTokens.accent)
                Spacer()
                Button("123") { viewModel.toggleInputMode() }
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal)
            .padding(.top, 8)
            Text("System keyboard active — tap 123 to return to keypad")
                .font(.caption2)
                .foregroundStyle(ThemeTokens.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .background(ThemeTokens.surface)
    }

    private var suggestionsSection: some View {
        Group {
            if !viewModel.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(viewModel.suggestions, id: \.field) { suggestion in
                            Button {
                                viewModel.applySuggestion(suggestion)
                            } label: {
                                GlassChip("\(suggestion.field): \(suggestion.value)")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var flagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Circled", isOn: Binding(
                get: { viewModel.draft.isCircled },
                set: { _ in viewModel.toggleCircled() }
            ))
            .tint(ThemeTokens.accent)
            Toggle("MOS", isOn: $viewModel.draft.isMOS)
            Toggle("Pickup", isOn: $viewModel.draft.isPickup)
        }
    }
}