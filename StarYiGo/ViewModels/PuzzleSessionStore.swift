//
//  PuzzleSessionStore.swift
//  StarYi Go — Reusable SGF Puzzle Session Engine
//

import Combine
import Foundation
import SwiftUI

/// Reusable, unit-testable SGF puzzle stepping engine that encapsulates board state,
/// dihedral/color transforms, SGF branch navigation, off-main-thread refutation replies,
/// and board FX triggers. Designed to be shared across single puzzles, gauntlets, rush,
/// skip gates, and exam tests.
@MainActor
final class PuzzleSessionStore: ObservableObject {
    enum StepOutcome: Equatable, Sendable {
        case correctAdvance
        case solved
        case wrong(at: BoardPoint)
        case illegal(at: BoardPoint)
    }

    @Published private(set) var puzzle: GoPuzzle
    @Published private(set) var transform: PuzzleTransform
    @Published private(set) var boardState: GoBoardState
    @Published private(set) var isResponding: Bool = false
    @Published private(set) var isSolved: Bool = false
    @Published private(set) var mistakesCount: Int = 0
    @Published private(set) var hintPoint: BoardPoint? = nil
    @Published private(set) var lastCapturedPoints: [BoardPoint] = []
    @Published private(set) var captureEventID: UUID = UUID()
    @Published private(set) var illegalFlashPoint: BoardPoint? = nil
    @Published private(set) var illegalEventID: UUID = UUID()

    private var rootNode: SGFNode?
    private var currentNode: SGFNode?
    private var responseTask: Task<Void, Never>?

    var effectivePlayerColor: StoneColor {
        transform.apply(to: puzzle.playerColor)
    }

    var effectiveCropRegion: BoardCropRegion {
        transform.apply(to: puzzle.cropRegion, boardSize: puzzle.boardSize)
    }

    init(puzzle: GoPuzzle, transform: PuzzleTransform = .identity) {
        self.puzzle = puzzle
        self.transform = transform
        self.boardState = puzzle.initialBoardState(transform: transform)
        let parsed = puzzle.parsedRoot(transform: transform)
        self.rootNode = parsed
        self.currentNode = parsed
    }

    deinit {
        responseTask?.cancel()
    }

    func load(puzzle: GoPuzzle, transform: PuzzleTransform = .identity) {
        cancelTasks()
        self.puzzle = puzzle
        self.transform = transform
        self.boardState = puzzle.initialBoardState(transform: transform)
        let parsed = puzzle.parsedRoot(transform: transform)
        self.rootNode = parsed
        self.currentNode = parsed
        self.isResponding = false
        self.isSolved = false
        self.mistakesCount = 0
        self.hintPoint = nil
        self.lastCapturedPoints = []
        self.illegalFlashPoint = nil
    }

    func reset() {
        load(puzzle: puzzle, transform: transform)
    }

    func cancelTasks() {
        responseTask?.cancel()
        responseTask = nil
    }

    /// Computes the next winning move coordinate from the current SGF node, if one exists.
    func computeHintPoint() -> BoardPoint? {
        guard let node = currentNode else { return nil }
        for child in node.children where child.containsCorrectLeaf {
            if let mv = child.move, mv.color == effectivePlayerColor, case .place(let pt) = mv.action {
                hintPoint = pt
                return pt
            }
        }
        return nil
    }

    /// Applies a player tap on the puzzle board and schedules any scripted or AI opponent reply.
    func handlePlayerMove(
        at point: BoardPoint,
        onCompleted: ((StepOutcome) -> Void)? = nil
    ) {
        guard !isResponding, !isSolved else { return }

        let playerColor = effectivePlayerColor
        switch boardState.applying(action: .place(point), color: playerColor) {
        case .failure:
            illegalFlashPoint = point
            illegalEventID = UUID()
            onCompleted?(.illegal(at: point))
            return
        case .success(let outcome):
            hintPoint = nil
            boardState = outcome.nextState
            if !outcome.capturedPoints.isEmpty {
                lastCapturedPoints = outcome.capturedPoints
                captureEventID = UUID()
            }

            // Look for matching child in SGF variation tree
            let matchingChild = currentNode?.children.first { child in
                guard let mv = child.move, mv.color == playerColor else { return false }
                return mv.action == .place(point)
            }

            guard let child = matchingChild else {
                // Unscripted move -> run off-main-thread local refutation reply, then report wrong
                mistakesCount += 1
                scheduleUnscriptedRefutation(after: point, onCompleted: onCompleted)
                return
            }

            currentNode = child
            if child.isMarkedCorrect {
                isSolved = true
                onCompleted?(.solved)
                return
            }
            if child.isMarkedWrong || child.children.isEmpty {
                mistakesCount += 1
                onCompleted?(.wrong(at: point))
                return
            }

            // Pick opponent's scripted response (preferring a branch that still leads to CORRECT if player is on right path)
            let replyNode = child.children.first(where: { $0.containsCorrectLeaf }) ?? child.children.first
            guard let reply = replyNode, let mv = reply.move else {
                mistakesCount += 1
                onCompleted?(.wrong(at: point))
                return
            }

            isResponding = true
            responseTask?.cancel()
            responseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 280_000_000)
                guard !Task.isCancelled, let self else { return }
                self.isResponding = false
                if case .success(let oppOut) = self.boardState.applying(action: mv.action, color: mv.color) {
                    self.boardState = oppOut.nextState
                    if !oppOut.capturedPoints.isEmpty {
                        self.lastCapturedPoints = oppOut.capturedPoints
                        self.captureEventID = UUID()
                    }
                }
                self.currentNode = reply
                if reply.isMarkedCorrect {
                    self.isSolved = true
                    onCompleted?(.solved)
                } else if reply.isMarkedWrong || reply.children.isEmpty {
                    self.mistakesCount += 1
                    onCompleted?(.wrong(at: point))
                } else {
                    onCompleted?(.correctAdvance)
                }
            }
        }
    }

    private func scheduleUnscriptedRefutation(
        after point: BoardPoint,
        onCompleted: ((StepOutcome) -> Void)?
    ) {
        let oppColor = effectivePlayerColor.opposite
        let snapshot = boardState
        let region = effectiveCropRegion

        isResponding = true
        responseTask?.cancel()
        responseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled else { return }
            let reply = await Task.detached(priority: .userInitiated) {
                LocalMCTSGoEngine.bestLocalReply(for: snapshot, color: oppColor, near: point, within: region)
            }.value
            guard !Task.isCancelled, let self else { return }
            self.isResponding = false
            if let reply,
               case .success(let oppOut) = self.boardState.applying(action: reply, color: oppColor) {
                self.boardState = oppOut.nextState
                if !oppOut.capturedPoints.isEmpty {
                    self.lastCapturedPoints = oppOut.capturedPoints
                    self.captureEventID = UUID()
                }
            }
            onCompleted?(.wrong(at: point))
        }
    }
}
