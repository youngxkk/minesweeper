import Foundation
import XCTest
@testable import StarYiGo

// These tests run in separate installations on a throwaway simulator.
final class UpgradeInstallationTests: XCTestCase {
    private let firstID = UUID(uuidString: "1603ED03-A8A0-48F9-85F5-627410C2D02E")!
    private let secondID = UUID(uuidString: "EAE30E70-95DC-41CF-A4D8-FC49D15097BA")!

    private func fixtureStorage() throws -> StorageService {
        StorageService(defaults: try XCTUnwrap(UserDefaults(suiteName: "StarYiGo.UpgradeFixture")))
    }

    func testSeedPreviousInstallation() throws {
        let storage = try fixtureStorage()
        XCTAssertTrue(storage.loadSavedGames().isEmpty, "Use a clean simulator for the upgrade fixture")
        let first = UserProfile(id: firstID, nickname: "Upgrade First", xp: 120)
        let second = UserProfile(id: secondID, nickname: "Upgrade Second", xp: 40)
        storage.saveProfile(first)
        storage.saveFamilyProfiles([first, second])

        var progress = PuzzleProgressStore()
        progress.starsByPuzzleId = ["first-puzzle": 3]
        storage.savePuzzleProgress(progress, for: first.id)
        progress.starsByPuzzleId = ["second-puzzle": 2]
        storage.savePuzzleProgress(progress, for: second.id)

        var settings = AppSettings()
        settings.showCoordinates = false
        storage.saveSettings(settings)
        storage.saveSavedGames([
            SavedGameRecord(boardSize: 9, komi: 6.5, handicap: 0, blackName: first.nickname,
                            whiteName: "AI", resultString: "W+R", moveCount: 2,
                            sgf: "(;GM[1]FF[4]SZ[9]RE[W+R];B[ee];W[cc])")
        ])
    }

    @MainActor
    func testUpgradePreservesArchiveSettingsAndFamilyProgress() throws {
        let app = AppState(storage: try fixtureStorage())
        XCTAssertEqual(app.profile.id, firstID)
        XCTAssertEqual(app.profile.xp, 120)
        XCTAssertEqual(Set(app.familyProfiles.map(\.id)), Set([firstID, secondID]))
        XCTAssertEqual(app.puzzleProgress.starsByPuzzleId, ["first-puzzle": 3])
        XCTAssertFalse(app.settings.showCoordinates)
        let record = try XCTUnwrap(app.savedGames.first)
        XCTAssertEqual(record.resultString, "W+R")
        let root = try XCTUnwrap(SGFParser.parse(record.sgf))
        XCTAssertEqual(root.children.first?.children.first?.move?.action, .place(BoardPoint(row: 2, col: 2)))
        let other = try XCTUnwrap(app.familyProfiles.first { $0.id == secondID })
        app.switchProfile(to: other)
        XCTAssertEqual(app.puzzleProgress.starsByPuzzleId, ["second-puzzle": 2])
        XCTAssertEqual(app.savedGames.first?.id, record.id)
    }
}
