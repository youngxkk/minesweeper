//
//  PhotoJudgeHistoryTests.swift
//  StarYiGoTests
//

import Foundation
import Testing
import UIKit
@testable import StarYiGo

struct PhotoJudgeHistoryTests {

    private func makeIsolatedStorage() throws -> (storage: StorageService, suite: String, imageDir: URL) {
        let suite = "StarYiGoTests.PhotoJudgeHistory.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let imageDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoJudgeHistoryTests-\(UUID().uuidString)", isDirectory: true)
        let storage = StorageService(defaults: defaults, photoHistoryDirectory: imageDir)
        return (storage, suite, imageDir)
    }

    private func cleanup(suite: String, imageDir: URL) {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: imageDir)
    }

    private func makeDummyImage(color: UIColor = .brown, size: CGSize = CGSize(width: 64, height: 64)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func makeSampleBoardState(size: Int = 9, komi: Double = 5.5) -> GoBoardState {
        var state = GoBoardState(size: size, komi: komi)
        state.setSetupStone(.black, at: BoardPoint(row: 2, col: 2))
        state.setSetupStone(.black, at: BoardPoint(row: 2, col: 3))
        state.setSetupStone(.white, at: BoardPoint(row: 6, col: 6))
        return state
    }

    @Test @MainActor func savesRestoresAndReconstructsBoardAcrossRelaunch() throws {
        let (storage, suite, imageDir) = try makeIsolatedStorage()
        defer { cleanup(suite: suite, imageDir: imageDir) }

        let app = AppState(storage: storage)
        let state = makeSampleBoardState(size: 9, komi: 5.5)
        let dead: Set<Int> = [state.index(row: 6, col: 6)]
        let score = GoScoring.score(state: state, rule: .chinese, deadStoneIndices: dead)
        let recordDate = Date(timeIntervalSinceNow: -86_400 * 3) // 3 days ago

        let record = PhotoJudgeRecord.from(
            date: recordDate,
            boardState: state,
            scoringRule: .chinese,
            deadStoneIndices: dead,
            result: score,
            blackWinrate: 0.87
        )
        let saved = app.upsertPhotoJudgeRecord(record, warpedImage: makeDummyImage())
        #expect(app.photoJudgeHistory.count == 1)
        #expect(saved.imageFilename != nil)

        // Relaunch AppState with same storage
        let reopened = AppState(storage: storage)
        let loaded = try #require(reopened.photoJudgeHistory.first)
        #expect(loaded.id == record.id)
        #expect(loaded.date == recordDate)
        #expect(loaded.boardSize == 9)
        #expect(loaded.scoringRule == .chinese)
        #expect(loaded.deadStoneIndices == [state.index(row: 6, col: 6)])
        #expect(loaded.blackWinrate == 0.87)
        #expect(loaded.makeBoardState().grid == state.grid)
        #expect(reopened.loadPhotoJudgeImage(for: loaded) != nil)
    }

    @Test @MainActor func enforces100RecordCapAndDeletesEvictedImageFiles() throws {
        let (storage, suite, imageDir) = try makeIsolatedStorage()
        defer { cleanup(suite: suite, imageDir: imageDir) }

        let app = AppState(storage: storage)
        let state = makeSampleBoardState(size: 9)
        let score = GoScoring.score(state: state, rule: .chinese, deadStoneIndices: [])

        var savedIds: [UUID] = []
        var savedFilenames: [String] = []

        for idx in 0..<105 {
            let record = PhotoJudgeRecord.from(
                date: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + idx * 60)),
                boardState: state,
                scoringRule: .chinese,
                deadStoneIndices: [],
                result: score
            )
            // Attach an image for the first 6 records so we can verify evicted images are cleaned up
            let img: UIImage? = idx < 6 ? makeDummyImage() : nil
            let saved = app.upsertPhotoJudgeRecord(record, warpedImage: img)
            savedIds.append(saved.id)
            if let fn = saved.imageFilename {
                savedFilenames.append(fn)
            }
        }

        #expect(app.photoJudgeHistory.count == PhotoJudgeRecord.maxStoredCount)
        #expect(app.photoJudgeHistory.count == 100)
        // Newest record (index 104) is at the front
        #expect(app.photoJudgeHistory.first?.id == savedIds[104])
        // Oldest surviving record is index 5 (0...4 were evicted)
        #expect(app.photoJudgeHistory.last?.id == savedIds[5])

        // Evicted image files (0...4) should be removed from disk, while surviving #5 still exists
        for idx in 0..<5 {
            let url = imageDir.appendingPathComponent(savedFilenames[idx])
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
        let survivingURL = imageDir.appendingPathComponent(savedFilenames[5])
        #expect(FileManager.default.fileExists(atPath: survivingURL.path))
    }

    @Test @MainActor func updatesExistingRecordInPlaceWithoutDuplicatingOrLosingImage() throws {
        let (storage, suite, imageDir) = try makeIsolatedStorage()
        defer { cleanup(suite: suite, imageDir: imageDir) }

        let app = AppState(storage: storage)
        var state = makeSampleBoardState(size: 9)
        let initialScore = GoScoring.score(state: state, rule: .chinese, deadStoneIndices: [])
        let recordId = UUID()
        let originalDate = Date(timeIntervalSinceNow: -3600)

        let initial = PhotoJudgeRecord.from(
            id: recordId,
            date: originalDate,
            boardState: state,
            scoringRule: .chinese,
            deadStoneIndices: [],
            result: initialScore,
            blackWinrate: nil
        )
        let firstSaved = app.upsertPhotoJudgeRecord(initial, warpedImage: makeDummyImage())
        let filename = try #require(firstSaved.imageFilename)

        // User edits a stone and KataGo finishes evaluation
        state.setSetupStone(.white, at: BoardPoint(row: 4, col: 4))
        let updatedScore = GoScoring.score(state: state, rule: .japanese, deadStoneIndices: [])
        let updated = PhotoJudgeRecord.from(
            id: recordId,
            date: originalDate,
            boardState: state,
            scoringRule: .japanese,
            deadStoneIndices: [],
            result: updatedScore,
            blackWinrate: 0.62
        )
        let secondSaved = app.upsertPhotoJudgeRecord(updated, warpedImage: nil)

        #expect(app.photoJudgeHistory.count == 1)
        #expect(secondSaved.imageFilename == filename)
        #expect(app.photoJudgeHistory.first?.scoringRule == .japanese)
        #expect(app.photoJudgeHistory.first?.blackWinrate == 0.62)
        #expect(app.loadPhotoJudgeImage(for: secondSaved) != nil)
    }

    @Test @MainActor func manualDeleteAndClearAllRemoveRecordsAndImages() throws {
        let (storage, suite, imageDir) = try makeIsolatedStorage()
        defer { cleanup(suite: suite, imageDir: imageDir) }

        let app = AppState(storage: storage)
        let state = makeSampleBoardState(size: 9)
        let score = GoScoring.score(state: state, rule: .chinese, deadStoneIndices: [])

        let first = app.upsertPhotoJudgeRecord(
            PhotoJudgeRecord.from(boardState: state, scoringRule: .chinese, deadStoneIndices: [], result: score),
            warpedImage: makeDummyImage()
        )
        let second = app.upsertPhotoJudgeRecord(
            PhotoJudgeRecord.from(boardState: state, scoringRule: .chinese, deadStoneIndices: [], result: score),
            warpedImage: makeDummyImage()
        )
        let third = app.upsertPhotoJudgeRecord(
            PhotoJudgeRecord.from(boardState: state, scoringRule: .chinese, deadStoneIndices: [], result: score),
            warpedImage: makeDummyImage()
        )

        #expect(app.photoJudgeHistory.count == 3)

        // Manually delete a single record
        app.deletePhotoJudgeRecord(id: second.id)
        #expect(app.photoJudgeHistory.map(\.id) == [third.id, first.id])
        if let deletedFile = second.imageFilename {
            #expect(!FileManager.default.fileExists(atPath: imageDir.appendingPathComponent(deletedFile).path))
        }

        // Verify persistence after relaunch
        let reopened = AppState(storage: storage)
        #expect(reopened.photoJudgeHistory.map(\.id) == [third.id, first.id])

        // Clear all
        reopened.clearPhotoJudgeHistory()
        #expect(reopened.photoJudgeHistory.isEmpty)
        for file in [first.imageFilename, third.imageFilename].compactMap({ $0 }) {
            #expect(!FileManager.default.fileExists(atPath: imageDir.appendingPathComponent(file).path))
        }
    }
}
