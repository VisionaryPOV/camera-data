import SwiftUI
import CameraDataDesignSystem
import CameraDataDomain

public struct ConflictResolutionView: View {
    public let conflicts: [ConflictField]
    @State public var resolutions: [String: ConflictResolutionChoice] = [:]
    public var onResolve: ([String: ConflictResolutionChoice]) -> Void

    public init(
        conflicts: [ConflictField],
        onResolve: @escaping ([String: ConflictResolutionChoice]) -> Void
    ) {
        self.conflicts = conflicts
        self.onResolve = onResolve
    }

    public var body: some View {
        List {
            ForEach(conflicts, id: \.key) { conflict in
                VStack(alignment: .leading, spacing: 8) {
                    Text(conflict.key.capitalized).font(.headline)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Local").font(.caption)
                            Text(conflict.localValue)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Remote").font(.caption)
                            Text(conflict.remoteValue)
                        }
                    }
                    Picker("Resolution", selection: binding(for: conflict.key)) {
                        Text("Keep Local").tag(ConflictResolutionChoice.local)
                        Text("Keep Remote").tag(ConflictResolutionChoice.remote)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Resolve Conflicts")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") { onResolve(resolutions) }
            }
        }
        .onAppear {
            for conflict in conflicts where resolutions[conflict.key] == nil {
                resolutions[conflict.key] = .local
            }
        }
    }

    private func binding(for key: String) -> Binding<ConflictResolutionChoice> {
        Binding(
            get: { resolutions[key] ?? .local },
            set: { resolutions[key] = $0 }
        )
    }
}