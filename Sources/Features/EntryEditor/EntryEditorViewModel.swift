import Foundation
import Observation
import CameraDataDomain
import CameraDataData
import CameraDataServices
import CameraDataDesignSystem

@MainActor
@Observable
public final class EntryEditorViewModel {
    public var draft: LogEntryDraft
    public var suggestions: [SmartSuggestion] = []
    public var validationMessage: String?
    public var isSaving: Bool = false

    private let useCase: LogTakeUseCase
    private let session: ProductionSession
    private let entryRepository: LogEntryRepositoryProtocol
    private let smartSuggestor: CoreMLSmartSuggestor?
    private var editingEntry: LogEntryModel?
    private var lastEntry: LogEntryDraft?

    public init(
        useCase: LogTakeUseCase,
        session: ProductionSession,
        entryRepository: LogEntryRepositoryProtocol,
        editingEntry: LogEntryModel? = nil,
        smartSuggestor: CoreMLSmartSuggestor? = nil
    ) {
        self.useCase = useCase
        self.session = session
        self.entryRepository = entryRepository
        self.editingEntry = editingEntry
        self.smartSuggestor = smartSuggestor
        self.draft = editingEntry.map(LogEntryMapper.toDraft) ?? LogEntryDraft()
    }

    public func onAppear() throws {
        guard let production = session.activeProduction,
              let camera = session.selectedCamera else { return }

        let entries = try entryRepository.fetchEntries(
            production: production,
            camera: camera,
            day: nil,
            limit: 1,
            offset: 0
        )
        lastEntry = entries.first.map(LogEntryMapper.toDraft)

        if draft.scene.isEmpty {
            draft.scene = session.slateScene.isEmpty ? (lastEntry?.scene ?? "") : session.slateScene
            draft.take = session.slateTake > 0 ? session.slateTake : TakeIncrementer.suggestedTake(
                for: draft.scene,
                existing: try entryRepository.fetchSceneTakes(production: production, camera: camera)
            )
        }

        applySmartFill()
        refreshSuggestions()
    }

    public func applySmartFill() {
        let cameraDefaults = session.selectedCamera.map { cam in
            LogEntryDraft(
                lens: cam.defaultLens,
                iso: cam.defaultISO,
                whiteBalance: cam.defaultWhiteBalance,
                fps: cam.defaultFPS,
                resolution: cam.defaultResolution,
                codec: cam.defaultCodec
            )
        }
        draft = useCase.prepareDraft(current: draft, lastEntry: lastEntry, cameraDefaults: cameraDefaults)
    }

    public func refreshSuggestions() {
        guard let production = session.activeProduction,
              let camera = session.selectedCamera else { return }
        let history = (try? entryRepository.fetchEntries(
            production: production, camera: camera, day: nil, limit: 200, offset: 0
        ).map(LogEntryMapper.toDraft)) ?? []

        if let smartSuggestor {
            suggestions = smartSuggestor.suggest(from: history, for: draft)
        } else {
            suggestions = SmartSuggestService.suggestions(from: history, for: draft)
        }
    }

    public func appendToScene(_ digit: String) {
        draft.scene += digit
        HapticManager.light()
    }

    public func appendToTake(_ digit: String) {
        let current = draft.take == 0 ? "" : String(draft.take)
        if let newValue = Int(current + digit) {
            draft.take = newValue
        }
        HapticManager.light()
    }

    public func toggleCircled() {
        draft.isCircled.toggle()
        if draft.isCircled { HapticManager.success() } else { HapticManager.light() }
    }

    public func logAndNext() throws {
        guard let production = session.activeProduction,
              let camera = session.selectedCamera,
              let day = session.selectedDay else { return }

        isSaving = true
        defer { isSaving = false }

        let result = try useCase.logAndNext(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: editingEntry,
            modifiedBy: "local-user"
        )
        HapticManager.medium()
        lastEntry = LogEntryMapper.toDraft(result.saved)
        draft = result.nextDraft
        session.slateScene = result.saved.scene
        session.slateTake = result.nextDraft.take
        editingEntry = nil
        validationMessage = nil
        refreshSuggestions()
    }

    public func applySuggestion(_ suggestion: SmartSuggestion) {
        switch suggestion.field {
        case "lens": draft.lens = suggestion.value
        case "iso": draft.iso = Int(suggestion.value) ?? draft.iso
        default: break
        }
        HapticManager.light()
    }
}