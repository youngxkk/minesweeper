//
//  PuzzlePackLoader.swift
//  StarYi Go — External JSON Puzzle Pack Loader & 1,100+ Catalog Engine (Phase 3)
//

import Foundation

struct PuzzlePackPayload: Codable, Sendable {
    let version: Int
    let description: String
    let templates: [GoPuzzle]
}

private final class PuzzlePackBundleToken {}

enum PuzzlePackLoader {

    /// Raw verified handcrafted templates loaded from `puzzle_packs.json` (30K -> 5D).
    static let jsonTemplates: [GoPuzzle] = {
        guard let url = locatePackURL(),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(PuzzlePackPayload.self, from: data) else {
            return []
        }
        return payload.templates
    }()

    /// Deterministic 6-orientation expansion of the external JSON templates (~816 verified puzzles).
    static let expandedPackPuzzles: [GoPuzzle] = {
        let variantTransforms: [(suffix: String, zhTag: String, enTag: String, transform: PuzzleTransform)] = [
            ("", "", "", .identity),
            ("-r90", " · 旋转视角", " (Rotated 90°)", PuzzleTransform(rotation: 1, mirrored: false, swapColors: false)),
            ("-w", " · 执白先手", " (White to Play)", PuzzleTransform(rotation: 2, mirrored: false, swapColors: true)),
            ("-m", " · 镜像翻转", " (Mirrored)", PuzzleTransform(rotation: 0, mirrored: true, swapColors: false)),
            ("-wm", " · 白先变向", " (White Mirrored)", PuzzleTransform(rotation: 3, mirrored: true, swapColors: true)),
            ("-r180", " · 倒置视角", " (Rotated 180°)", PuzzleTransform(rotation: 2, mirrored: false, swapColors: false))
        ]

        var result: [GoPuzzle] = []
        result.reserveCapacity(jsonTemplates.count * variantTransforms.count)
        for template in jsonTemplates {
            for v in variantTransforms {
                if v.transform.isIdentity {
                    result.append(template)
                } else {
                    result.append(
                        DojoPuzzleBank.transformedPuzzle(
                            template,
                            suffix: v.suffix,
                            zhTag: v.zhTag,
                            enTag: v.enTag,
                            transform: v.transform
                        )
                    )
                }
            }
        }
        return result
    }()

    /// Complete deduplicated catalog combining 320 Core Dojo puzzles + 800+ JSON Pack puzzles (1,100+ total).
    static let fullCatalog: [GoPuzzle] = {
        var seen = Set<String>()
        var combined: [GoPuzzle] = []
        combined.reserveCapacity(DojoPuzzleBank.allDojoPuzzles.count + expandedPackPuzzles.count)
        for p in DojoPuzzleBank.allDojoPuzzles {
            if seen.insert(p.id).inserted { combined.append(p) }
        }
        for p in expandedPackPuzzles {
            if seen.insert(p.id).inserted { combined.append(p) }
        }
        return combined
    }()

    private static let catalogById: [String: GoPuzzle] = {
        Dictionary(uniqueKeysWithValues: fullCatalog.map { ($0.id, $0) })
    }()

    static func findPuzzle(withId id: String) -> GoPuzzle? {
        catalogById[id]
    }

    /// All unique base templates across Built-In + Dojo Core + External JSON (200 templates, 30K -> 5D).
    static let allUniqueTemplates: [GoPuzzle] = {
        var seen = Set<String>()
        var out: [GoPuzzle] = []
        for p in BuiltInPuzzleLibrary.allPuzzles + DojoPuzzleBank.coreDojoTemplates + jsonTemplates {
            if seen.insert(p.id).inserted { out.append(p) }
        }
        return out
    }()

    /// Generates an escalating puzzle pool from 30K -> 5D for Endless Puzzle Rush.
    /// Groups templates by rank band and shuffles within each band so every run feels fresh.
    static func generatePuzzleRushSequence() -> [GoPuzzle] {
        // Higher rankOrderValue = easier (30K -> 30, 1K -> 1, 1D -> 0, 5D -> -4).
        let grouped = Dictionary(grouping: allUniqueTemplates) { $0.rankOrderValue }
        let sortedRanks = grouped.keys.sorted(by: >) // 30 -> -4 (easiest to hardest)
        var sequence: [GoPuzzle] = []
        for rank in sortedRanks {
            let pool = (grouped[rank] ?? []).shuffled()
            sequence.append(contentsOf: pool)
        }
        return sequence
    }

    /// Selects a deterministic rank-appropriate daily puzzle tailored to the player's certified rank tier.
    static func rankAdaptiveDailyPuzzle(for date: Date = Date(), certifiedRankTier: Int) -> GoPuzzle {
        let targetRange: ClosedRange<Int>
        switch certifiedRankTier {
        case ...1: targetRange = 18...30   // 30K - 18K
        case 2:    targetRange = 14...22   // 22K - 14K
        case 3:    targetRange = 10...17   // 17K - 10K (15K zone!)
        case 4:    targetRange = 6...13    // 13K - 6K  (10K zone)
        case 5:    targetRange = 1...8     // 8K - 1K   (5K zone)
        default:   targetRange = -4...2    // 2K - 5D   (Dan zone)
        }
        let matching = allUniqueTemplates.filter { targetRange.contains($0.rankOrderValue) }
        let pool = matching.isEmpty ? BuiltInPuzzleLibrary.allPuzzles : matching
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return pool[(dayOfYear - 1) % pool.count]
    }

    private static func locatePackURL() -> URL? {
        let bundles: [Bundle] = [
            Bundle.main,
            Bundle(for: PuzzlePackBundleToken.self)
        ] + Bundle.allBundles

        for bundle in bundles {
            if let url = bundle.url(forResource: "puzzle_packs", withExtension: "json", subdirectory: "Resources/Puzzles") {
                return url
            }
            if let url = bundle.url(forResource: "puzzle_packs", withExtension: "json", subdirectory: "Puzzles") {
                return url
            }
            if let url = bundle.url(forResource: "puzzle_packs", withExtension: "json") {
                return url
            }
        }
        return nil
    }
}
