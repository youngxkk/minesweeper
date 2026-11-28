import Foundation
import Testing
@testable import StarYiGo

struct LegacyStorageTests {
    #if DEBUG
    @Test @MainActor func parentalGateBypassRequiresDebugModeAndPersists() throws {
        let suite = "StarYiGoTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = StorageService(defaults: defaults)
        let app = AppState(storage: storage)
        #expect(!app.shouldBypassParentalVerification)
        app.setDebugSkipParentalVerification(true)
        #expect(!app.shouldBypassParentalVerification)
        app.setDebugModeEnabled(true)
        #expect(app.shouldBypassParentalVerification)
        let reopened = AppState(storage: storage)
        #expect(reopened.shouldBypassParentalVerification)
        reopened.setDebugModeEnabled(false)
        #expect(!reopened.shouldBypassParentalVerification)
        reopened.setDebugModeEnabled(true)
        reopened.setDebugSkipParentalVerification(false)
        #expect(!reopened.shouldBypassParentalVerification)
        #expect(!storage.loadDebugSkipParentalVerification())
    }
    #endif

    @Test @MainActor func firstPlacementBelongsToTheSamePlayerAfterRelaunch() throws {
        let suite = "StarYiGoTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let app = AppState(storage: StorageService(defaults: defaults))
        let owner = app.profile.id
        #expect(app.familyProfiles.map(\.id) == [owner])
        let beginner = try #require(StarYiCampaign.placementOptions.first { $0.recommendedRankTier == 0 })
        app.applyPlacementChoice(beginner)
        let reopened = AppState(storage: StorageService(defaults: defaults))
        #expect(reopened.profile.id == owner)
        #expect(reopened.familyProfiles.map(\.id) == [owner])
        #expect(reopened.puzzleProgress.didCompletePlacement)
        #expect(reopened.puzzleProgress.unlockedSeaIds.contains(beginner.targetSeaId))
    }

    @Test func recoversPlacementSavedBeforeTheFirstProfile() throws {
        let suite = "StarYiGoTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = StorageService(defaults: defaults)
        let owner = UUID()
        var progress = PuzzleProgressStore()
        progress.didCompletePlacement = true
        storage.savePuzzleProgress(progress, for: owner)
        #expect(storage.loadFamilyProfiles().map(\.id) == [owner])
        #expect(storage.loadProfile().id == owner)
        #expect(storage.loadPuzzleProgress(for: owner) == progress)
    }

    @Test func readsVersionOneArchiveAndOlderSettings() throws {
        let suite = "StarYiGoTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        // Literal v1 JSON keeps this independent of the current encoder.
        defaults.set(Data("""
        [{
            "id": "88549125-3E08-47EC-BB13-3C4D18E99815",
            "date": 0,
            "boardSize": 9,
            "komi": 6.5,
            "handicap": 0,
            "blackName": "Black",
            "whiteName": "White",
            "resultString": "W+R",
            "moveCount": 2,
            "sgf": "(;GM[1]FF[4]SZ[9]KM[6.5]RE[W+R];B[ee];W[cc])"
        }]
        """.utf8), forKey: "starpoint.savedGames.v1")
        defaults.set(Data(#"{"confirmBeforePlace":false}"#.utf8), forKey: "starpoint.appSettings.v1")

        let storage = StorageService(defaults: defaults)
        let record = try #require(storage.loadSavedGames().first)
        #expect(record.id.uuidString == "88549125-3E08-47EC-BB13-3C4D18E99815")
        #expect(record.date == Date(timeIntervalSinceReferenceDate: 0))
        #expect(record.moveCount == 2)
        #expect(record.resultString == "W+R")
        let root = try #require(SGFParser.parse(record.sgf))
        #expect(root.boardSize == 9)
        #expect(root.children.first?.move?.action == .place(BoardPoint(row: 4, col: 4)))
        #expect(root.children.first?.children.first?.move?.action == .place(BoardPoint(row: 2, col: 2)))

        let settings = storage.loadSettings()
        #expect(!settings.confirmBeforePlace)
        #expect(settings.preferredBoardSize == AppSettings().preferredBoardSize)
        storage.saveSavedGames([record])
        #expect(StorageService(defaults: defaults).loadSavedGames() == [record])
    }

    @Test @MainActor func migratesLegacyProgressToTheOriginalFamilyMember() throws {
        let suite = "StarYiGoTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = #"{"id":"58BEE259-4DCF-4D87-AEFA-9ABF5968EC75","nickname":"First","xp":60}"#
        let second = #"{"id":"08AB7BC4-EA0A-47AE-A9FE-92099E572F3E","nickname":"Second","xp":20}"#
        defaults.set(Data(first.utf8), forKey: "starpoint.userProfile.v1")
        defaults.set(Data("[\(first),\(second)]".utf8), forKey: "starpoint.familyProfiles.v1")
        defaults.set(Data(#"{"starsByPuzzleId":{"legacy-puzzle":3},"mistakeBookIds":["review-me"]}"#.utf8),
                     forKey: "starpoint.puzzleProgress.v1")

        let storage = StorageService(defaults: defaults)
        let app = AppState(storage: storage)
        let original = app.profile
        #expect(original.nickname == "First")
        #expect(original.xp == 60)
        #expect(app.familyProfiles.count == 2)
        #expect(app.puzzleProgress.starsByPuzzleId["legacy-puzzle"] == 3)
        #expect(app.puzzleProgress.mistakeBookIds == ["review-me"])

        let other = try #require(app.familyProfiles.first { $0.id != original.id })
        app.switchProfile(to: other)
        #expect(app.puzzleProgress == PuzzleProgressStore())
        var otherProgress = PuzzleProgressStore()
        otherProgress.starsByPuzzleId["other-puzzle"] = 2
        storage.savePuzzleProgress(otherProgress, for: other.id)

        let reopened = AppState(storage: StorageService(defaults: defaults))
        #expect(reopened.profile.id == other.id)
        #expect(reopened.puzzleProgress == otherProgress)
        reopened.switchProfile(to: original)
        #expect(reopened.puzzleProgress.starsByPuzzleId == ["legacy-puzzle": 3])
    }
}
