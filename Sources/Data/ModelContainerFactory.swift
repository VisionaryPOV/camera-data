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

    public static let cloudKitContainerIdentifier = "iCloud.com.visionarypov.cameradata"

    public static func makeInMemory() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    public static func makePersistent(cloudKitEnabled: Bool = false) throws -> ModelContainer {
        if cloudKitEnabled {
            let privateConfig = ModelConfiguration(
                "CameraData-Private",
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
            return try ModelContainer(for: schema, configurations: [privateConfig])
        }
        let config = ModelConfiguration("CameraData", cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}