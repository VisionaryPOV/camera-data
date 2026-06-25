import Foundation
import CameraDataDomain
import CameraDataData

@MainActor
public final class LogTakeUseCase {
    private let entryRepository: LogEntryRepositoryProtocol
    private let postSaveCoordinator: LogPostSaveCoordinator
    private let metadataProvider: any MetadataProviding

    public init(
        entryRepository: LogEntryRepositoryProtocol,
        postSaveCoordinator: LogPostSaveCoordinator,
        metadataProvider: any MetadataProviding
    ) {
        self.entryRepository = entryRepository
        self.postSaveCoordinator = postSaveCoordinator
        self.metadataProvider = metadataProvider
    }

    public func prepareDraft(
        current: LogEntryDraft,
        lastEntry: LogEntryDraft?,
        cameraDefaults: LogEntryDraft?
    ) -> LogEntryDraft {
        SmartFillEngine.apply(to: current, lastEntry: lastEntry, cameraDefaults: cameraDefaults)
    }

    public func applyVoiceAudio(
        _ data: Data,
        to draft: LogEntryDraft,
        transcriber: SpeechTranscribing
    ) async throws -> (draft: LogEntryDraft, flags: [String]) {
        let (voiceDraft, flags) = try await VoiceLoggingService.processAudio(data, transcriber: transcriber)
        var merged = draft
        if !voiceDraft.scene.isEmpty { merged.scene = voiceDraft.scene }
        if voiceDraft.take > 0 { merged.take = voiceDraft.take }
        merged.isCircled = merged.isCircled || voiceDraft.isCircled
        merged.isMOS = merged.isMOS || voiceDraft.isMOS
        merged.isPickup = merged.isPickup || voiceDraft.isPickup
        merged.isTail = merged.isTail || voiceDraft.isTail
        merged.isHold = merged.isHold || voiceDraft.isHold
        merged.isBad = merged.isBad || voiceDraft.isBad
        merged.isSeries = merged.isSeries || voiceDraft.isSeries
        return (merged, flags)
    }

    public func logAndNext(
        draft: LogEntryDraft,
        production: ProductionModel,
        camera: CameraUnitModel,
        day: ShootDayModel,
        existing: LogEntryModel?,
        modifiedBy: String
    ) async throws -> (saved: LogEntryModel, nextDraft: LogEntryDraft) {
        let captureContext = metadataProvider.captureContext()
        let saved = try entryRepository.save(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: existing,
            modifiedBy: modifiedBy,
            captureContext: captureContext,
            preferredId: nil
        )

        await postSaveCoordinator.handle(
            entryId: saved.id,
            syncVersion: saved.syncVersion,
            scene: saved.scene,
            take: saved.take,
            lens: saved.lens,
            iso: saved.iso,
            productionCode: production.code
        )

        let sceneTakes = try entryRepository.fetchSceneTakes(production: production, camera: camera)
        let nextTake = TakeIncrementer.nextTake(
            after: draft.take,
            existingTakesForScene: sceneTakes.filter { $0.scene == draft.scene }.map(\.take)
        )

        var next = LogEntryDraft(scene: draft.scene, take: nextTake)
        next = SmartFillEngine.apply(to: next, lastEntry: draft, cameraDefaults: cameraDefaults(from: camera))
        return (saved, next)
    }

    private func cameraDefaults(from camera: CameraUnitModel) -> LogEntryDraft {
        LogEntryDraft(
            lens: camera.defaultLens,
            iso: camera.defaultISO,
            whiteBalance: camera.defaultWhiteBalance,
            fps: camera.defaultFPS,
            resolution: camera.defaultResolution,
            codec: camera.defaultCodec
        )
    }
}