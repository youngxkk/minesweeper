//
//  PuzzleCatalog.swift
//  StarYi Go — Unified O(1) Puzzle Catalog
//

import Foundation

/// Single source of truth for looking up any built-in, dojo, pack, codex, or bootcamp puzzle in O(1) time.
/// Isolates legacy `StarYiIslands` lookups behind a unified boundary.
enum PuzzleCatalog {
    private static let builtInById: [String: GoPuzzle] = {
        var map: [String: GoPuzzle] = [:]
        // Order defines priority when IDs overlap across sources.
        let orderedSources: [[GoPuzzle]] = [
            StarYiIslands.orderedPuzzles,
            StarterBootcamp.puzzles,
            BuiltInPuzzleLibrary.allPuzzles,
            PuzzlePackLoader.fullCatalog,
            DojoPuzzleBank.allDojoPuzzles,
            GoTermCodex.codexPracticePuzzles
        ]
        for source in orderedSources {
            for puzzle in source {
                map[puzzle.id] = puzzle
            }
        }
        return map
    }()

    static func findPuzzle(withId id: String, customPuzzles: [GoPuzzle] = []) -> GoPuzzle? {
        if let custom = customPuzzles.first(where: { $0.id == id }) {
            return custom
        }
        return builtInById[id]
    }
}
