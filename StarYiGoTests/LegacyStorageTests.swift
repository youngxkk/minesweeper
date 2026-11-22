import Foundation
import Testing
@testable import StarYiGo

struct LegacyStorageTests {
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
}
