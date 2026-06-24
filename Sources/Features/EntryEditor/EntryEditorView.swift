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
            VStack(spacing: 20) {
                sceneTakeSection
                suggestionsSection
                fieldsSection
                flagsSection
                if let message = viewModel.validationMessage {
                    Text(message).foregroundStyle(.red).font(.caption)
                }
                GlassButton("Log & Next", isPrimary: true) {
                    try? viewModel.logAndNext()
                }
                .disabled(viewModel.isSaving)
            }
            .padding()
        }
        .background(ThemeTokens.background)
        .navigationTitle("Log Take")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: onDismiss)
            }
        }
        .onAppear { try? viewModel.onAppear() }
    }

    private var sceneTakeSection: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scene").font(.caption).foregroundStyle(ThemeTokens.textSecondary)
                    Text(viewModel.draft.scene.isEmpty ? "—" : viewModel.draft.scene)
                        .font(.largeTitle.monospacedDigit())
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Take").font(.caption).foregroundStyle(ThemeTokens.textSecondary)
                    Text("\(viewModel.draft.take)")
                        .font(.largeTitle.monospacedDigit())
                }
            }
            keypad
        }
    }

    private var keypad: some View {
        VStack(spacing: 8) {
            ForEach([["1","2","3"], ["4","5","6"], ["7","8","9"], ["0"]], id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        GlassKeypadKey(key) {
                            if viewModel.draft.scene.count < viewModel.draft.take.description.count + 2 {
                                viewModel.appendToScene(key)
                            } else {
                                viewModel.appendToTake(key)
                            }
                        }
                    }
                }
            }
        }
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

    private var fieldsSection: some View {
        VStack(spacing: 12) {
            fieldRow("Lens", text: $viewModel.draft.lens)
            fieldRow("ISO", value: "\(viewModel.draft.iso)")
            fieldRow("FPS", value: String(format: "%.3f", viewModel.draft.fps))
            fieldRow("WB", text: $viewModel.draft.whiteBalance)
            fieldRow("Notes", text: $viewModel.draft.notes)
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

    private func fieldRow(_ label: String, text: Binding<String>) -> some View {
        GlassCard {
            VStack(alignment: .leading) {
                Text(label).font(.caption).foregroundStyle(ThemeTokens.textSecondary)
                TextField(label, text: text)
                    .foregroundStyle(ThemeTokens.textPrimary)
            }
        }
    }

    private func fieldRow(_ label: String, value: String) -> some View {
        GlassCard {
            VStack(alignment: .leading) {
                Text(label).font(.caption).foregroundStyle(ThemeTokens.textSecondary)
                Text(value).font(.body.monospacedDigit())
            }
        }
    }
}