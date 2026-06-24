import Foundation
import CameraDataDomain

public struct FrameIOExportPayload: Codable, Sendable, Equatable {
    public var productionName: String
    public var exportFormat: String
    public var entryCount: Int
    public var webhookURL: String?
    public var timestamp: Date

    public init(productionName: String, format: ExportFormat, entryCount: Int, webhookURL: String? = nil) {
        self.productionName = productionName
        self.exportFormat = format.rawValue
        self.entryCount = entryCount
        self.webhookURL = webhookURL
        self.timestamp = .now
    }
}

public enum FrameIOExportHook {
    public static func buildPayload(
        productionName: String,
        entries: [LogEntryDraft],
        format: ExportFormat,
        webhookURL: String? = nil
    ) -> FrameIOExportPayload {
        FrameIOExportPayload(
            productionName: productionName,
            format: format,
            entryCount: entries.count,
            webhookURL: webhookURL
        )
    }

    public static func encode(_ payload: FrameIOExportPayload) throws -> Data {
        try JSONEncoder().encode(payload)
    }
}