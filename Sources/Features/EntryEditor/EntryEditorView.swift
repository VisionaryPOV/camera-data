import SwiftUI
import CameraDataDesignSystem
import CameraDataDomain

public struct EntryEditorView: View {
    @Bindable public var viewModel: EntryEditorViewModel
    public var onDismiss: () -> Void

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
            .padding(.bottom, 260)
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
        }
        .onAppear { try? viewModel.onAppear() }
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
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(field.label)
                    .font(.caption)
                    .foregroundStyle(ThemeTokens.textSecondary)
                Text(viewModel.displayValue(for: field))
                    .font(field == .notes ? .body : .title2.monospacedDigit())
                    .foregroundStyle(ThemeTokens.textPrimary)
                    .lineLimit(field == .notes ? 3 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
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