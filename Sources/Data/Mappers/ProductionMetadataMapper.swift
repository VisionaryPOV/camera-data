import Foundation
import CameraDataDomain

public extension ProductionModel {
    var metadata: ProductionMetadata {
        ProductionMetadata(
            productionTitle: name,
            directorName: directorName,
            dpName: dpName,
            episodeOrProductionNumber: episodeOrProductionNumber
        )
    }

    func applyMetadata(_ metadata: ProductionMetadata) {
        name = metadata.productionTitle
        directorName = metadata.directorName
        dpName = metadata.dpName
        episodeOrProductionNumber = metadata.episodeOrProductionNumber
    }

    var displayTitle: String {
        name.isEmpty ? "Untitled Production" : name
    }

    var latestShootDay: ShootDayModel? {
        days.sorted(by: { $0.dayNumber < $1.dayNumber }).last
    }
}