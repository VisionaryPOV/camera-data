import Foundation
import Observation
import CameraDataDomain
import CameraDataData
import CameraDataDesignSystem

@MainActor
@Observable
public final class ProductionEditorViewModel {
    public var productionTitle: String = ""
    public var directorName: String = ""
    public var dpName: String = ""
    public var episodeOrProductionNumber: String = ""
    public var dayNumber: Int = 1
    public var shootDate: Date = .now
    public var locationName: String = ""
    public var dayNotes: String = ""
    public var saveMessage: String?
    public var isSaving: Bool = false

    private let productionRepository: ProductionRepositoryProtocol
    private let session: ProductionSession

    public init(productionRepository: ProductionRepositoryProtocol, session: ProductionSession) {
        self.productionRepository = productionRepository
        self.session = session
        reloadFromSession()
    }

    public func reloadFromSession() {
        guard let production = session.activeProduction else { return }
        let metadata = production.metadata
        productionTitle = metadata.productionTitle
        directorName = metadata.directorName
        dpName = metadata.dpName
        episodeOrProductionNumber = metadata.episodeOrProductionNumber

        if let day = session.selectedDay {
            dayNumber = day.dayNumber
            shootDate = day.date
            locationName = day.locationName
            dayNotes = day.notes
        }
    }

    public func save() throws {
        guard let production = session.activeProduction else { return }
        isSaving = true
        defer { isSaving = false }

        let metadata = ProductionMetadata(
            productionTitle: productionTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            directorName: directorName.trimmingCharacters(in: .whitespacesAndNewlines),
            dpName: dpName.trimmingCharacters(in: .whitespacesAndNewlines),
            episodeOrProductionNumber: episodeOrProductionNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try productionRepository.updateMetadata(production, metadata: metadata)

        if let day = session.selectedDay {
            try productionRepository.updateShootDay(
                day,
                dayNumber: dayNumber,
                date: shootDate,
                locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: dayNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        saveMessage = "Production saved"
        HapticManager.success()
    }

    public func startNewShootDay() throws {
        guard let production = session.activeProduction else { return }
        let day = try productionRepository.addShootDay(to: production, locationName: locationName)
        session.selectedDay = day
        dayNumber = day.dayNumber
        shootDate = day.date
        locationName = day.locationName
        dayNotes = day.notes
        saveMessage = "Started Day \(day.dayNumber)"
        HapticManager.medium()
    }
}