import XCTest
import SwiftData
@testable import CameraDataData
import CameraDataDomain
import CameraDataServices

@MainActor
final class ProductionMetadataTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: ProductionRepository!

    override func setUp() async throws {
        container = try ModelContainerFactory.makeInMemory()
        repository = ProductionRepository(context: container.mainContext)
    }

    func testUpdateMetadataPersistsAndRecalls() throws {
        let production = try repository.create(name: "Pilot")
        try repository.updateMetadata(
            production,
            metadata: ProductionMetadata(
                productionTitle: "Night Shoot",
                directorName: "Jane Director",
                dpName: "Alex DP",
                episodeOrProductionNumber: "104"
            )
        )

        let fetched = try repository.fetchActive()
        XCTAssertEqual(fetched?.name, "Night Shoot")
        XCTAssertEqual(fetched?.directorName, "Jane Director")
        XCTAssertEqual(fetched?.dpName, "Alex DP")
        XCTAssertEqual(fetched?.episodeOrProductionNumber, "104")
        XCTAssertEqual(fetched?.metadata.crewCreditsLine, "Director: Jane Director  •  DP: Alex DP  •  Ep/Prod: 104")
    }

    func testAddShootDayIncrementsDayNumber() throws {
        let production = try repository.create(name: "Season One")
        XCTAssertEqual(production.days.count, 1)

        let day2 = try repository.addShootDay(to: production, locationName: "Stage 4")
        XCTAssertEqual(day2.dayNumber, 2)
        XCTAssertEqual(day2.locationName, "Stage 4")
        XCTAssertEqual(production.days.count, 2)
    }

    func testSetActiveRecallsProduction() throws {
        let first = try repository.create(name: "Show A")
        try repository.updateMetadata(first, metadata: ProductionMetadata(productionTitle: "Show A", directorName: "Dir A"))
        let second = try repository.create(name: "Show B")
        try repository.updateMetadata(second, metadata: ProductionMetadata(productionTitle: "Show B", directorName: "Dir B"))

        try repository.setActive(first)
        let active = try repository.fetchActive()
        XCTAssertEqual(active?.name, "Show A")
        XCTAssertEqual(active?.directorName, "Dir A")
    }

    func testExportBrandingFromMetadata() {
        let branding = ExportBranding.from(
            metadata: ProductionMetadata(
                productionTitle: "Feature",
                directorName: "Sam",
                dpName: "Chris",
                episodeOrProductionNumber: "Pilot"
            )
        )
        XCTAssertEqual(branding.productionName, "Feature")
        XCTAssertTrue(branding.reportHeaderLines.contains("Director: Sam"))
        XCTAssertTrue(branding.reportHeaderLines.contains("DP: Chris"))
        XCTAssertTrue(branding.reportHeaderLines.contains("Episode / Production #: Pilot"))
    }

    func testArchiveHidesProductionFromList() throws {
        let production = try repository.create(name: "Old Show")
        try repository.archive(production)
        let visible = try repository.fetchAll(includeArchived: false)
        XCTAssertTrue(visible.isEmpty)
        let all = try repository.fetchAll(includeArchived: true)
        XCTAssertEqual(all.count, 1)
    }
}