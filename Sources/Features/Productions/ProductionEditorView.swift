import SwiftUI
import CameraDataDesignSystem

public struct ProductionEditorView: View {
    @Bindable public var viewModel: ProductionEditorViewModel
    public var onManageProductions: () -> Void

    public init(viewModel: ProductionEditorViewModel, onManageProductions: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onManageProductions = onManageProductions
    }

    public var body: some View {
        Group {
            Section {
                metadataField("Production Title", text: $viewModel.productionTitle, prompt: "e.g. Night Shoot")
                metadataField("Director", text: $viewModel.directorName, prompt: "Director name")
                metadataField("DP", text: $viewModel.dpName, prompt: "Director of Photography")
                metadataField("Episode / Production #", text: $viewModel.episodeOrProductionNumber, prompt: "e.g. 104 or Pilot")
            } header: {
                Text("Production")
            } footer: {
                Text("Saved production info appears on reports and is recalled when you switch back to this show.")
            }

            Section {
                Stepper("Day \(viewModel.dayNumber)", value: $viewModel.dayNumber, in: 1...999)
                DatePicker("Shoot Date", selection: $viewModel.shootDate, displayedComponents: .date)
                metadataField("Location", text: $viewModel.locationName, prompt: "Stage, address, or unit base")
                metadataField("Day Notes", text: $viewModel.dayNotes, prompt: "Optional notes for this shoot day")
                Button("Start New Shoot Day") {
                    try? viewModel.startNewShootDay()
                }
            } header: {
                Text("Shoot Day")
            } footer: {
                Text("Use a new shoot day when you return to the same production on another day.")
            }

            Section {
                Button("Save Production Info", role: .none) {
                    try? viewModel.save()
                }
                .disabled(viewModel.isSaving)

                Button("Manage All Productions", action: onManageProductions)

                if let message = viewModel.saveMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.accent)
                }
            }
        }
        .onAppear { viewModel.reloadFromSession() }
    }

    private func metadataField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        TextField(title, text: text, prompt: Text(prompt))
            .textInputAutocapitalization(.words)
    }
}