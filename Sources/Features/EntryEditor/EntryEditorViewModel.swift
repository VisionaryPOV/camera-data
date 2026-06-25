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
    public var focusedField: EntryEditorFocus = .scene
    public var inputMode: EntryInputMode = .keypad
    public var fpsText: String = "24"

    private let useCase: LogTakeUseCase
    private let session: ProductionSession
    private let entryRepository: LogEntryRepositoryProtocol
    private let smartSuggestor: CoreMLSmartSuggestor?
    private var editingEntry: LogEntryModel?
    private var lastEntry: LogEntryDraft?
    private var takeEntryText: String = ""

    public var canEdit: Bool {
        session.currentRole.canEdit
    }

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
        self.fpsText = Self.formatFPS(self.draft.fps)
    }

    public func onAppear() throws {
        guard canEdit else {
            validationMessage = "Read-only access — logging disabled for \(session.currentRole.rawValue) role"
            return
        }

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

        if draft.rollNumber.isEmpty, let lastRoll = lastEntry?.rollNumber, !lastRoll.isEmpty {
            draft.rollNumber = lastRoll
        }

        fpsText = Self.formatFPS(draft.fps)
        applySmartFill()
        refreshSuggestions()
    }

    public func focus(_ field: EntryEditorFocus) {
        guard canEdit else { return }
        syncFPSTextToDraft()
        focusedField = field
        if field == .take {
            takeEntryText = ""
        }
        if field.usesNumericKeypad {
            inputMode = .keypad
        }
        HapticManager.light()
    }

    public func toggleInputMode() {
        guard canEdit else { return }
        syncFPSTextToDraft()
        inputMode = inputMode == .keypad ? .keyboard : .keypad
        HapticManager.light()
    }

    public func applySmartFill() {
        guard canEdit else { return }
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
        fpsText = Self.formatFPS(draft.fps)
        HapticManager.success()
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

    public func inputKey(_ key: String) {
        guard canEdit else { return }

        switch focusedField {
        case .scene:
            draft.scene += key
        case .take:
            takeEntryText += key
            draft.take = Int(takeEntryText) ?? 0
        case .rollNumber:
            draft.rollNumber += key.uppercased()
        case .lens:
            draft.lens += key
        case .filter:
            draft.filter += key
        case .iso:
            appendDigit(to: &draft.iso, key: key)
        case .fps:
            fpsText += key
            syncFPSTextToDraft()
        case .whiteBalance:
            draft.whiteBalance += key
        case .notes:
            draft.notes += key
        }
        HapticManager.light()
    }

    public func deleteBackward() {
        guard canEdit else { return }

        switch focusedField {
        case .scene:
            if !draft.scene.isEmpty { draft.scene.removeLast() }
        case .take:
            if !takeEntryText.isEmpty { takeEntryText.removeLast() }
            draft.take = Int(takeEntryText) ?? 0
        case .rollNumber:
            if !draft.rollNumber.isEmpty { draft.rollNumber.removeLast() }
        case .lens:
            if !draft.lens.isEmpty { draft.lens.removeLast() }
        case .filter:
            if !draft.filter.isEmpty { draft.filter.removeLast() }
        case .iso:
            removeLastDigit(from: &draft.iso)
        case .fps:
            if !fpsText.isEmpty { fpsText.removeLast() }
            syncFPSTextToDraft()
        case .whiteBalance:
            if !draft.whiteBalance.isEmpty { draft.whiteBalance.removeLast() }
        case .notes:
            if !draft.notes.isEmpty { draft.notes.removeLast() }
        }
        HapticManager.light()
    }

    public func advanceRollNumber() {
        guard canEdit else { return }
        draft.rollNumber = RollNumberHelper.increment(draft.rollNumber)
        HapticManager.medium()
    }

    public func toggleCircled() {
        guard canEdit else { return }
        draft.isCircled.toggle()
        if draft.isCircled { HapticManager.success() } else { HapticManager.light() }
    }

    public func syncFPSTextToDraft() {
        if let value = Double(fpsText) {
            draft.fps = value
        }
    }

    public func logAndNext() async throws {
        guard canEdit else {
            validationMessage = "Read-only access — cannot log takes"
            return
        }

        guard let production = session.activeProduction,
              let camera = session.selectedCamera,
              let day = session.selectedDay else { return }

        syncFPSTextToDraft()
        isSaving = true
        defer { isSaving = false }

        let result = try await useCase.logAndNext(
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
        fpsText = Self.formatFPS(draft.fps)
        session.slateScene = result.saved.scene
        session.slateTake = result.nextDraft.take
        editingEntry = nil
        validationMessage = nil
        refreshSuggestions()
    }

    public func applySuggestion(_ suggestion: SmartSuggestion) {
        guard canEdit else { return }
        switch suggestion.field {
        case "lens": draft.lens = suggestion.value
        case "iso":
            draft.iso = Int(suggestion.value) ?? draft.iso
        case "roll", "rollNumber":
            draft.rollNumber = suggestion.value
        default: break
        }
        HapticManager.light()
    }

    public func displayValue(for field: EntryEditorFocus) -> String {
        switch field {
        case .scene: draft.scene.isEmpty ? "—" : draft.scene
        case .take:
            if focusedField == .take, !takeEntryText.isEmpty {
                takeEntryText
            } else {
                "\(draft.take)"
            }
        case .rollNumber: draft.rollNumber.isEmpty ? "—" : draft.rollNumber
        case .lens: draft.lens.isEmpty ? "—" : draft.lens
        case .filter: draft.filter.isEmpty ? "—" : draft.filter
        case .iso: "\(draft.iso)"
        case .fps: fpsText
        case .whiteBalance: draft.whiteBalance.isEmpty ? "—" : draft.whiteBalance
        case .notes: draft.notes.isEmpty ? "—" : draft.notes
        }
    }

    private func appendDigit(to value: inout Int, key: String) {
        guard let digit = Int(key) else { return }
        let current = value == 0 ? "" : String(value)
        if let newValue = Int(current + String(digit)) {
            value = newValue
        }
    }

    private func removeLastDigit(from value: inout Int) {
        let current = value == 0 ? "" : String(value)
        guard !current.isEmpty else {
            value = 0
            return
        }
        let trimmed = String(current.dropLast())
        value = Int(trimmed) ?? 0
    }

    private static func formatFPS(_ fps: Double) -> String {
        if fps == floor(fps) {
            return String(format: "%.0f", fps)
        }
        return String(fps)
    }
}