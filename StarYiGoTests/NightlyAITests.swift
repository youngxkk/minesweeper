import Foundation
import XCTest
@testable import StarYiGo

final class NightlyAITests: XCTestCase {
    func testSeededSelfPlayFinishesWithLegalMoves() throws {
        executionTimeAllowance = 180
        for seed: UInt64 in [7, 42] {
            let state = try play(size: 5, seed: seed, maxPlies: 150)
            XCTAssertEqual(state.consecutivePasses, 2, "Self-play did not finish with seed \(seed)")
        }
    }

    func testNineteenLineResponseTimes() throws {
        executionTimeAllowance = 180
        _ = try play(size: 19, seed: 2026, maxPlies: 12)
    }

    func testNineteenLineMiddleAndLateGameResponseTimes() throws {
        executionTimeAllowance = 180
        for (phase, plies) in [("middle", 72), ("late", 224)] {
            let fixture = try fixedPosition(after: plies)
            _ = try play(size: 19, seed: 2026, maxPlies: 8, phase: phase, startingFrom: fixture)
        }
    }

    private func fixedPosition(after plies: Int) throws -> GoBoardState {
        var state = GoBoardState(size: 19)
        var random = SeededGenerator(state: 84)
        let indices = Array(0..<(19 * 19)).shuffled(using: &random)
        for index in indices {
            let point = state.point(for: index)
            if case .success(let outcome) = state.applying(action: .place(point)) {
                state = outcome.nextState
                if state.moveCount == plies { return state }
            }
        }
        throw FixtureError.insufficientLegalMoves
    }

    private enum FixtureError: Error {
        case insufficientLegalMoves
    }

    private func play(size: Int, seed: UInt64, maxPlies: Int, phase: String = "opening", startingFrom: GoBoardState? = nil) throws -> GoBoardState {
        let engine = LocalMCTSGoEngine()
        var state = startingFrom ?? GoBoardState(size: size)
        var random = SeededGenerator(state: seed)
        var moves: [MoveAction] = []
        var milliseconds: [Double] = []
        defer {
            let sorted = milliseconds.sorted()
            let p95 = sorted.isEmpty ? 0 : sorted[Int(ceil(Double(sorted.count) * 0.95)) - 1]
            let summary = "size=\(size) phase=\(phase) seed=\(seed) level=rabbit plies=\(moves.count) p95_ms=\(p95) max_ms=\(sorted.last ?? 0)"
            let lines = zip(moves, milliseconds).enumerated().map {
                "\($0.offset + 1),\($0.element.0),\($0.element.1)"
            }
            print("AI self-play: \(summary)")
            let report = XCTAttachment(string: ([summary, "ply,action,elapsed_ms"] + lines).joined(separator: "\n"))
            report.name = "AI self-play \(size)x\(size) \(phase), seed \(seed)"
            report.lifetime = .keepAlways
            add(report)
        }

        let clock = ContinuousClock()
        for ply in 1...maxPlies {
            let start = clock.now
            let action = engine.computeMoveSync(
                for: state, color: state.currentTurn, level: .rabbit,
                ruleSet: .standard, coachingStyle: .standard, random: &random
            )
            let elapsed = (clock.now - start).components
            let duration = Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
            moves.append(action)
            milliseconds.append(duration)
            XCTAssertLessThan(duration, 15_000, "Slow move on \(size)x\(size), seed \(seed), ply \(ply)")
            switch state.applying(action: action) {
            case .success(let outcome):
                state = outcome.nextState
            case .failure(let error):
                XCTFail("Illegal move \(action) on \(size)x\(size), seed \(seed), ply \(ply): \(error)")
                throw error
            }
            if state.consecutivePasses == 2 { break }
        }
        return state
    }

    // SplitMix64 gives the search a repeatable random stream for each match.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }
    }
}
