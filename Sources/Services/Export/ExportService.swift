import Foundation
import PDFKit
import UIKit
import CameraDataDomain

public struct ExportBranding: Sendable {
    public var productionName: String
    public var directorName: String
    public var dpName: String
    public var episodeOrProductionNumber: String
    public var logoText: String
    public var crewCredits: String
    public var accentHex: String

    public init(
        productionName: String,
        directorName: String = "",
        dpName: String = "",
        episodeOrProductionNumber: String = "",
        logoText: String = "",
        crewCredits: String = "",
        accentHex: String = "#E8A838"
    ) {
        self.productionName = productionName
        self.directorName = directorName
        self.dpName = dpName
        self.episodeOrProductionNumber = episodeOrProductionNumber
        self.logoText = logoText
        self.crewCredits = crewCredits.isEmpty
            ? Self.defaultCrewCredits(director: directorName, dp: dpName, episode: episodeOrProductionNumber)
            : crewCredits
        self.accentHex = accentHex
    }

    public static func from(metadata: ProductionMetadata) -> ExportBranding {
        ExportBranding(
            productionName: metadata.productionTitle.isEmpty ? "Production" : metadata.productionTitle,
            directorName: metadata.directorName,
            dpName: metadata.dpName,
            episodeOrProductionNumber: metadata.episodeOrProductionNumber
        )
    }

    private static func defaultCrewCredits(director: String, dp: String, episode: String) -> String {
        ProductionMetadata(
            directorName: director,
            dpName: dp,
            episodeOrProductionNumber: episode
        ).crewCreditsLine
    }

    public var reportHeaderLines: [String] {
        var lines: [String] = []
        if !episodeOrProductionNumber.isEmpty {
            lines.append("Episode / Production #: \(episodeOrProductionNumber)")
        }
        if !directorName.isEmpty { lines.append("Director: \(directorName)") }
        if !dpName.isEmpty { lines.append("DP: \(dpName)") }
        if !crewCredits.isEmpty, lines.isEmpty { lines.append(crewCredits) }
        return lines
    }
}

public struct DailyWrapSummary: Sendable {
    public var productionName: String
    public var dayNumber: Int
    public var takeCount: Int
    public var circledCount: Int
    public var dominantLens: String?

    public init(productionName: String, dayNumber: Int, stats: DashboardStats) {
        self.productionName = productionName
        self.dayNumber = dayNumber
        self.takeCount = stats.takeCount
        self.circledCount = stats.circledCount
        self.dominantLens = stats.dominantLens
    }
}

public enum ExportService {
    public static func csvData(from entries: [LogEntryDraft]) -> Data {
        var lines: [String] = []
        lines.append(VESFieldMapper.csvHeader().joined(separator: ","))
        for entry in entries {
            let row = VESFieldMapper.csvRow(from: entry).map { escapeCSV($0) }
            lines.append(row.joined(separator: ","))
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    public static func jsonData(from entries: [LogEntryDraft]) -> Data {
        let array = entries.map { VESFieldMapper.jsonDictionary(from: $0) }
        return (try? JSONSerialization.data(withJSONObject: array, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    public static func pdfData(
        from entries: [LogEntryDraft],
        branding: ExportBranding,
        title: String = "Camera Report"
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()
            let inset: CGFloat = 40
            var y = inset

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.white
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.white
            ]

            UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1).setFill()
            context.fill(pageRect)

            branding.productionName.draw(at: CGPoint(x: inset, y: y), withAttributes: titleAttrs)
            y += 28
            title.draw(at: CGPoint(x: inset, y: y), withAttributes: bodyAttrs)
            y += 24

            for line in branding.reportHeaderLines where !line.isEmpty {
                line.draw(at: CGPoint(x: inset, y: y), withAttributes: bodyAttrs)
                y += 16
            }

            let header = VESFieldMapper.csvHeader().joined(separator: " | ")
            header.draw(at: CGPoint(x: inset, y: y), withAttributes: bodyAttrs)
            y += 16

            for entry in entries {
                if y > pageRect.height - 60 {
                    context.beginPage()
                    y = inset
                }
                let line = VESFieldMapper.csvRow(from: entry).joined(separator: " | ")
                line.draw(at: CGPoint(x: inset, y: y), withAttributes: bodyAttrs)
                y += 14
            }
        }
    }

    public static func dailyWrapPDF(summary: DailyWrapSummary) -> Data {
        let branding = ExportBranding(
            productionName: summary.productionName,
            crewCredits: "Day \(summary.dayNumber) Wrap Summary"
        )
        let draft = LogEntryDraft(
            scene: "WRAP",
            take: 1,
            notes: "Takes: \(summary.takeCount), Circled: \(summary.circledCount), Lens: \(summary.dominantLens ?? "—")"
        )
        return pdfData(from: [draft], branding: branding, title: "Daily Wrap")
    }

    public static func csvReportPreamble(branding: ExportBranding) -> String {
        branding.reportHeaderLines.joined(separator: "\n")
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}