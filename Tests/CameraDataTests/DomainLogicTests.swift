import XCTest
@testable import CameraDataDomain

final class DomainLogicTests: XCTestCase {
    func testSortKeyGeneratorOrdersScenesAndTakes() {
        let keyA1 = SortKeyGenerator.make(scene: "12", take: 1)
        let keyA3 = SortKeyGenerator.make(scene: "12", take: 3)
        let keyB1 = SortKeyGenerator.make(scene: "12A", take: 1)

        XCTAssertTrue(SortKeyGenerator.compare(keyA1, keyA3))
        XCTAssertTrue(SortKeyGenerator.compare(keyA3, keyB1) || keyA3 != keyB1)
    }

    func testTakeIncrementerNextTake() {
        XCTAssertEqual(TakeIncrementer.nextTake(after: 2, existingTakesForScene: [1, 2, 3]), 4)
        XCTAssertEqual(TakeIncrementer.suggestedTake(for: "10", existing: [("10", 1), ("10", 2)]), 3)
    }

    func testSmartFillCarriesLensAndISO() {
        let last = LogEntryDraft(scene: "5", take: 2, lens: "50mm", iso: 1280, fps: 23.976)
        var draft = LogEntryDraft(scene: "5", take: 3)
        let filled = SmartFillEngine.apply(to: draft, lastEntry: last, cameraDefaults: nil)
        XCTAssertEqual(filled.lens, "50mm")
        XCTAssertEqual(filled.iso, 1280)
        XCTAssertEqual(filled.fps, 23.976)
    }

    func testValidatorRejectsDuplicateSceneTake() {
        let draft = LogEntryDraft(scene: "12", take: 3)
        XCTAssertThrowsError(try LogEntryValidator.validate(draft, existingSceneTakes: [("12", 3)])) { error in
            XCTAssertEqual(error as? LogEntryValidationError, .duplicateSceneTake(scene: "12", take: 3))
        }
    }

    func testVESFieldMapperCSVRow() {
        let draft = LogEntryDraft(scene: "7", take: 4, lens: "32mm", iso: 800, notes: "Good")
        let row = VESFieldMapper.csvRow(from: draft)
        XCTAssertEqual(row.first, "7")
        XCTAssertEqual(row[1], "4")
        XCTAssertEqual(row[2], "32mm")
        XCTAssertTrue(row.last?.contains("Good") == true)
    }

    func testConflictMergerDetectsLensConflict() {
        let local = LogEntryDraft(scene: "1", take: 1, lens: "50mm")
        let remote = LogEntryDraft(scene: "1", take: 1, lens: "75mm")
        let conflicts = ConflictMerger.detectConflicts(local: local, remote: remote)
        XCTAssertTrue(conflicts.contains { $0.key == "lens" })
    }

    func testNLPQueryParserSceneAndCircled() {
        let parsed = NLPQueryParser.parse("circled anamorphic scene 12")
        XCTAssertEqual(parsed.scene, "12")
        XCTAssertTrue(parsed.circledOnly)
        XCTAssertEqual(parsed.lensContains, "anamorphic")
    }

    func testFilmTerminologyVoiceParse() {
        let result = FilmTerminologyLexicon.processTranscript("log take 3 for scene 12 circled mos")
        XCTAssertEqual(result.scene, "12")
        XCTAssertEqual(result.take, 3)
        XCTAssertTrue(result.flags.contains("CIRCLED"))
        XCTAssertTrue(result.flags.contains("MOS"))
    }

    func testDashboardStatsCalculator() {
        let entries = [
            LogEntryDraft(scene: "1", take: 1, lens: "50mm", isCircled: true),
            LogEntryDraft(scene: "1", take: 2, lens: "50mm"),
            LogEntryDraft(scene: "2", take: 1, lens: "75mm")
        ]
        let stats = DashboardStatsCalculator.compute(entries: entries, shootDurationHours: 2)
        XCTAssertEqual(stats.takeCount, 3)
        XCTAssertEqual(stats.circledCount, 1)
        XCTAssertEqual(stats.dominantLens, "50mm")
        XCTAssertEqual(stats.takesPerHour, 1.5)
    }

    func testSmartSuggestEngineSuggestsLensForScene() {
        let history = [
            LogEntryDraft(scene: "8", take: 1, lens: "40mm"),
            LogEntryDraft(scene: "8", take: 2, lens: "40mm"),
            LogEntryDraft(scene: "8", take: 3, lens: "75mm")
        ]
        let draft = LogEntryDraft(scene: "8", take: 4)
        let suggestions = SmartSuggestEngine.suggest(from: history, for: draft)
        XCTAssertTrue(suggestions.contains { $0.field == "lens" && $0.value == "40mm" })
    }
}