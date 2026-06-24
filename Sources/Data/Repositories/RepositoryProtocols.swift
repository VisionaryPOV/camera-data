import Foundation
import SwiftData
import CameraDataDomain

@MainActor
public protocol ProductionRepositoryProtocol {
    func fetchAll() throws -> [ProductionModel]
    func fetchActive() throws -> ProductionModel?
    func create(name: String) throws -> ProductionModel
    func setActive(_ production: ProductionModel) throws
}

@MainActor
public protocol LogEntryRepositoryProtocol {
    func fetchEntries(
        production: ProductionModel,
        camera: CameraUnitModel?,
        day: ShootDayModel?,
        limit: Int,
        offset: Int
    ) throws -> [LogEntryModel]

    func fetchSceneTakes(production: ProductionModel, camera: CameraUnitModel?) throws -> [(scene: String, take: Int)]

    func save(
        draft: LogEntryDraft,
        production: ProductionModel,
        camera: CameraUnitModel,
        day: ShootDayModel,
        existing: LogEntryModel?,
        modifiedBy: String
    ) throws -> LogEntryModel

    func softDelete(_ entry: LogEntryModel) throws
}

@MainActor
public protocol ProductionTemplateRepositoryProtocol {
    func cloneProduction(from source: ProductionModel, newName: String) throws -> ProductionModel
}