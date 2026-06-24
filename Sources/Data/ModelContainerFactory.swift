import Foundation
import SwiftData

public enum ModelContainerFactory {
    public static let schema = Schema([
        ProductionModel.self,
        CameraUnitModel.self,
        ShootDayModel.self,
        LogEntryModel.self,
        CustomFieldDefinitionModel.self,
        CustomFieldValueModel.self,
        RollModel.self,
        AttachmentModel.self,
        ProductionMemberModel.self,
        AuditEventModel.self,
        PresenceRecordModel.self
    ])

    public static func makeInMemory() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    public static func makePersistent(cloudKitEnabled: Bool = false) throws -> ModelContainer {
        if cloudKitEnabled {
            let config = ModelConfiguration(
                "CameraData",
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: [config])
        }
        let config = ModelConfiguration("CameraData")
        return try ModelContainer(for: schema, configurations: [config])
    }
}