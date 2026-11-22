//
//  GoScoring.swift
//  StarYi Go
//

import Foundation

struct TerritoryEstimate: Sendable {
    /// Value per intersection in [-1.0, +1.0]:
    /// Positive = Black ownership/influence, Negative = White ownership/influence.
    let ownership: [Double]
    let blackArea: Double
    let whiteArea: Double
    let komi: Double

    var blackTotal: Double { blackArea }
    var whiteTotal: Double { whiteArea + komi }
    var blackLead: Double { blackTotal - whiteTotal }

    /// Probability-like visual ratio in [0.05, 0.95] for the territory bar.
    var blackRatio: Double {
        let total = max(1.0, blackTotal + whiteTotal)
        return min(0.95, max(0.05, blackTotal / total))
    }
}

/// Diagnoses whether a board is properly sealed for endgame scoring or still has leaks / unfilled dame.
struct EndgameReadiness: Sendable, Equatable {
    /// Empty intersections on contested boundaries where territory is still leaking or unsealed.
    let unsealedBoundaryPoints: [BoardPoint]
    /// Neutral dame intersections (single empty points touching both colors) still open.
    let unfilledDamePoints: [BoardPoint]
    /// Groups currently in Seki (mutual life).
    let sekiGroupCount: Int

    var isReadyToScore: Bool {
        unsealedBoundaryPoints.isEmpty
    }

    var warningCount: Int {
        unsealedBoundaryPoints.count
    }
}

/// Detected Seki (mutual life) analysis.
struct SekiAnalysis: Sendable {
    let sekiStoneIndices: Set<Int>
    let sekiSharedLiberties: Set<Int>
    let sekiEyeIndices: Set<Int>
    let sekiPairCount: Int
}

/// Individual enclosed territory pocket for visual step-by-step counting animation.
struct TerritoryPocket: Identifiable, Hashable, Sendable {
    let id: Int
    let owner: StoneColor
    let points: [BoardPoint]
}

enum GoScoring {
    // MARK: - Seki (双活) Detection

    /// Detects pairs of opposing groups locked in Seki (mutual life):
    /// Neither group has 2 true eyes, both share 1-2 common liberties, and playing any shared liberty
    /// immediately puts the mover into self-atari (allowing the opponent to capture).
    static func detectSeki(
        state: GoBoardState,
        deadStoneIndices: Set<Int> = []
    ) -> SekiAnalysis {
        var clean = state
        for idx in deadStoneIndices where idx >= 0 && idx < clean.grid.count {
            clean.grid[idx] = nil
        }

        let groups = clean.allGroups()
        let aliveAnalysis = clean.twoEyeAliveAnalysis()
        var sekiStones: Set<Int> = []
        var sekiShared: Set<Int> = []
        var sekiEyes: Set<Int> = []
        var pairs = 0

        let blackGroups = groups.filter { $0.color == .black && $0.stones.isDisjoint(with: aliveAnalysis.aliveStoneIndices) }
        let whiteGroups = groups.filter { $0.color == .white && $0.stones.isDisjoint(with: aliveAnalysis.aliveStoneIndices) }

        for bg in blackGroups {
            for wg in whiteGroups {
                let shared = bg.liberties.intersection(wg.liberties)
                guard !shared.isEmpty, shared.count <= 2 else { continue }

                // Remaining non-shared liberties must each be at most 1 (single internal eye each or 0)
                let bgPrivate = bg.liberties.subtracting(shared)
                let wgPrivate = wg.liberties.subtracting(shared)
                guard bgPrivate.count <= 1 && wgPrivate.count <= 1 else { continue }

                // Case A: 0 private liberties each, 2 shared liberties -> playing either shared liberty is self-atari!
                // Case B: 1 true eye each (private liberty is a true eye), 1 shared liberty -> playing shared liberty is self-atari!
                let isCaseA = (shared.count == 2 && bgPrivate.isEmpty && wgPrivate.isEmpty)
                let isCaseB: Bool = {
                    guard shared.count == 1, let bEye = bgPrivate.first, let wEye = wgPrivate.first else { return false }
                    return clean.isTrueEye(index: bEye, for: .black) && clean.isTrueEye(index: wEye, for: .white)
                }()

                guard isCaseA || isCaseB else { continue }

                // Verify that playing any shared liberty does NOT capture the opponent and leaves mover in atari (1 liberty)
                var mutualStandoff = true
                for lib in shared {
                    let pt = clean.point(for: lib)
                    if case .success(let bOut) = clean.applying(action: .place(pt), color: .black) {
                        let bLibs = bOut.nextState.groupAndLiberties(at: lib)?.liberties.count ?? 0
                        if !bOut.capturedPoints.isEmpty || bLibs > 1 {
                            mutualStandoff = false
                            break
                        }
                    }
                    if case .success(let wOut) = clean.applying(action: .place(pt), color: .white) {
                        let wLibs = wOut.nextState.groupAndLiberties(at: lib)?.liberties.count ?? 0
                        if !wOut.capturedPoints.isEmpty || wLibs > 1 {
                            mutualStandoff = false
                            break
                        }
                    }
                }

                if mutualStandoff {
                    pairs += 1
                    sekiStones.formUnion(bg.stones)
                    sekiStones.formUnion(wg.stones)
                    sekiShared.formUnion(shared)
                    if isCaseB {
                        sekiEyes.formUnion(bgPrivate)
                        sekiEyes.formUnion(wgPrivate)
                    }
                }
            }
        }

        return SekiAnalysis(
            sekiStoneIndices: sekiStones,
            sekiSharedLiberties: sekiShared,
            sekiEyeIndices: sekiEyes,
            sekiPairCount: pairs
        )
    }

    // MARK: - Endgame Unsealed Boundary & Dame Readiness Check

    /// Checks whether territories are properly sealed before entering endgame scoring.
    /// Highlights leaking territory regions (large neutral empty pockets touching both colors)
    /// and open dame points so young players learn when to finish boundaries before passing!
    static func analyzeEndgameReadiness(
        state: GoBoardState,
        deadStoneIndices: Set<Int> = []
    ) -> EndgameReadiness {
        var clean = state
        for idx in deadStoneIndices where idx >= 0 && idx < clean.grid.count {
            clean.grid[idx] = nil
        }

        let seki = detectSeki(state: state, deadStoneIndices: deadStoneIndices)
        let total = clean.size * clean.size
        var visited = Array(repeating: false, count: total)
        var unsealed: [BoardPoint] = []
        var dame: [BoardPoint] = []

        for idx in 0..<total where clean.grid[idx] == nil && !visited[idx] {
            var region: [Int] = [idx]
            var stack: [Int] = [idx]
            visited[idx] = true
            var touchesBlack = false
            var touchesWhite = false

            while let cur = stack.popLast() {
                for n in clean.neighbors(of: cur) {
                    if let s = clean.grid[n] {
                        if s == .black { touchesBlack = true } else { touchesWhite = true }
                    } else if !visited[n] {
                        visited[n] = true
                        region.append(n)
                        stack.append(n)
                    }
                }
            }

            guard touchesBlack && touchesWhite else { continue }

            // Exclude genuine Seki shared liberties from warnings (players must NOT fill Seki dame!)
            let nonSekiRegion = region.filter { !seki.sekiSharedLiberties.contains($0) }
            guard !nonSekiRegion.isEmpty else { continue }

            if nonSekiRegion.count == 1 {
                dame.append(clean.point(for: nonSekiRegion[0]))
            } else if nonSekiRegion.count >= 2 {
                // Find the bottleneck contact points touching BOTH colors (or adjacent to opposing stones)
                var contactPts: [BoardPoint] = []
                for rIdx in nonSekiRegion {
                    var adjB = false
                    var adjW = false
                    for n in clean.neighbors(of: rIdx) {
                        if clean.grid[n] == .black { adjB = true }
                        else if clean.grid[n] == .white { adjW = true }
                    }
                    if adjB && adjW {
                        contactPts.append(clean.point(for: rIdx))
                    }
                }
                if contactPts.isEmpty {
                    // Large open neutral area — mark up to 2 representative points
                    if let first = nonSekiRegion.first {
                        unsealed.append(clean.point(for: first))
                    }
                } else {
                    unsealed.append(contentsOf: contactPts.prefix(3))
                }
            }
        }

        return EndgameReadiness(
            unsealedBoundaryPoints: unsealed,
            unfilledDamePoints: dame,
            sekiGroupCount: seki.sekiPairCount
        )
    }

    // MARK: - Automatic Dead-Stone Estimation

    /// Automatically detects dead stones before endgame scoring confirmation:
    /// - Groups with 2+ true eyes (or large living eyes) or in Seki are strictly alive.
    /// - Groups in Atari, small trapped groups, or larger eyeless groups completely surrounded by enemy territory
    ///   without enough eye space are proposed as dead (users can tap any group to override or Play Out Dispute).
    static func autoEstimateDeadStones(state: GoBoardState) -> Set<Int> {
        let groups = state.allGroups()
        guard !groups.isEmpty else { return [] }

        let analysis = state.twoEyeAliveAnalysis()
        let seki = detectSeki(state: state)
        let est = estimateTerritory(state: state)
        var dead: Set<Int> = []

        for group in groups {
            // Unconditionally alive with 2+ eyes OR in Seki
            if !group.stones.isDisjoint(with: analysis.aliveStoneIndices) {
                continue
            }
            if !group.stones.isDisjoint(with: seki.sekiStoneIndices) {
                continue
            }

            let sign: Double = (group.color == .black) ? 1.0 : -1.0
            var oppNeighborCount = 0
            var totalBoundary = 0
            var libertyAvgOwner = 0.0

            for lib in group.liberties {
                libertyAvgOwner += est.ownership[lib] * sign
            }
            if !group.liberties.isEmpty {
                libertyAvgOwner /= Double(group.liberties.count)
            }

            // Count single-point true eyes for this group
            var trueEyeCount = 0
            for lib in group.liberties where state.isTrueEye(index: lib, for: group.color) {
                trueEyeCount += 1
            }

            // Inspect 2-step neighborhood for surrounding opponent stones
            var checked: Set<Int> = group.stones
            for s in group.stones {
                for n in state.neighbors(of: s) where !checked.contains(n) {
                    checked.insert(n)
                    totalBoundary += 1
                    if state.grid[n] == group.color.opposite {
                        oppNeighborCount += 1
                    } else if state.grid[n] == nil {
                        for n2 in state.neighbors(of: n) where !group.stones.contains(n2) {
                            if state.grid[n2] == group.color.opposite {
                                oppNeighborCount += 1
                                totalBoundary += 1
                            } else if state.grid[n2] == group.color {
                                totalBoundary += 1
                            }
                        }
                    }
                }
            }

            let oppRatio = totalBoundary > 0 ? Double(oppNeighborCount) / Double(totalBoundary) : 0.0

            // 1. In atari (1 liberty) and heavily surrounded by opponent
            if group.liberties.count == 1 && oppRatio >= 0.55 {
                dead.formUnion(group.stones)
                continue
            }
            // 2. Small trapped group (<= 4 stones, <= 2 liberties) enclosed in enemy influence
            if group.stones.count <= 4 && group.liberties.count <= 2 && oppRatio >= 0.70 && libertyAvgOwner < -0.10 {
                dead.formUnion(group.stones)
                continue
            }
            // 3. Larger eyeless dead dragon (up to 12 stones, <= 3 liberties, 0-1 eye, surrounded >= 78% by opponent)
            if group.stones.count <= 12 && group.liberties.count <= 3 && trueEyeCount <= 1 && oppRatio >= 0.78 && libertyAvgOwner < -0.22 {
                dead.formUnion(group.stones)
                continue
            }
        }

        return dead
    }

    // MARK: - Territory Pockets (for Step-by-Step Animated Visual Counting)

    static func territoryPockets(
        state: GoBoardState,
        deadStoneIndices: Set<Int> = []
    ) -> [TerritoryPocket] {
        var scoringState = state
        for idx in deadStoneIndices where idx >= 0 && idx < scoringState.grid.count {
            scoringState.grid[idx] = nil
        }

        let total = scoringState.size * scoringState.size
        var visited = Array(repeating: false, count: total)
        var pockets: [TerritoryPocket] = []
        var nextId = 0

        for idx in 0..<total where scoringState.grid[idx] == nil && !visited[idx] {
            var region: [Int] = [idx]
            var stack: [Int] = [idx]
            visited[idx] = true
            var touchesBlack = false
            var touchesWhite = false

            while let cur = stack.popLast() {
                for n in scoringState.neighbors(of: cur) {
                    if let stone = scoringState.grid[n] {
                        if stone == .black { touchesBlack = true } else { touchesWhite = true }
                    } else if !visited[n] {
                        visited[n] = true
                        region.append(n)
                        stack.append(n)
                    }
                }
            }

            if touchesBlack && !touchesWhite {
                pockets.append(TerritoryPocket(id: nextId, owner: .black, points: region.map { scoringState.point(for: $0) }))
                nextId += 1
            } else if touchesWhite && !touchesBlack {
                pockets.append(TerritoryPocket(id: nextId, owner: .white, points: region.map { scoringState.point(for: $0) }))
                nextId += 1
            }
        }

        return pockets.sorted { $0.points.count > $1.points.count }
    }

    // MARK: - Dual Official Scoring (Chinese Area & Japanese Territory)

    /// Unified exact scoring supporting both Chinese Area Scoring (数子法) and Japanese/Korean Territory Scoring (数目法).
    /// Properly treats neutral Dame (单官) and Seki (双活) — never assigns dame via influence heuristic!
    static func score(
        state: GoBoardState,
        rule: ScoringRule = .chinese,
        deadStoneIndices: Set<Int> = []
    ) -> GameResult {
        var scoringState = state
        var deadBlackCount = 0
        var deadWhiteCount = 0

        for idx in deadStoneIndices where idx >= 0 && idx < scoringState.grid.count {
            if let s = scoringState.grid[idx] {
                if s == .black { deadBlackCount += 1 } else { deadWhiteCount += 1 }
            }
            scoringState.grid[idx] = nil
        }

        let seki = detectSeki(state: state, deadStoneIndices: deadStoneIndices)
        let size = scoringState.size
        let total = size * size

        var blackStones = 0
        var whiteStones = 0
        var blackTerritory = 0
        var whiteTerritory = 0
        var dameCount = 0

        var visitedEmpty = Array(repeating: false, count: total)

        for idx in 0..<total {
            if let stone = scoringState.grid[idx] {
                if stone == .black { blackStones += 1 } else { whiteStones += 1 }
            } else if !visitedEmpty[idx] {
                var region: [Int] = [idx]
                var stack: [Int] = [idx]
                visitedEmpty[idx] = true
                var touchesBlack = false
                var touchesWhite = false

                while let cur = stack.popLast() {
                    for n in scoringState.neighbors(of: cur) {
                        if let stone = scoringState.grid[n] {
                            if stone == .black { touchesBlack = true }
                            else { touchesWhite = true }
                        } else if !visitedEmpty[n] {
                            visitedEmpty[n] = true
                            region.append(n)
                            stack.append(n)
                        }
                    }
                }

                if touchesBlack && !touchesWhite {
                    // Under Japanese rules, eyes inside Seki do NOT count as territory points!
                    if rule == .japanese {
                        let nonSekiEyes = region.filter { !seki.sekiEyeIndices.contains($0) }.count
                        blackTerritory += nonSekiEyes
                    } else {
                        blackTerritory += region.count
                    }
                } else if touchesWhite && !touchesBlack {
                    if rule == .japanese {
                        let nonSekiEyes = region.filter { !seki.sekiEyeIndices.contains($0) }.count
                        whiteTerritory += nonSekiEyes
                    } else {
                        whiteTerritory += region.count
                    }
                } else if touchesBlack && touchesWhite {
                    // Neutral dame / Seki shared liberties: NEVER given to one side by influence!
                    dameCount += region.count
                }
            }
        }

        let totalBlackCaptures = state.blackCaptures + deadWhiteCount
        let totalWhiteCaptures = state.whiteCaptures + deadBlackCount

        let blackTotal: Double
        let whiteTotal: Double

        switch rule {
        case .chinese:
            // Chinese Area Scoring: living stones + enclosed territory + equal half-share of any open dame
            let halfDame = Double(dameCount) * 0.5
            blackTotal = Double(blackStones + blackTerritory) + halfDame
            whiteTotal = Double(whiteStones + whiteTerritory) + halfDame + scoringState.komi
        case .japanese:
            // Japanese Territory Scoring: enclosed territory (excl. Seki eyes) + prisoners + dead enemy stones + komi
            blackTotal = Double(blackTerritory + totalBlackCaptures)
            whiteTotal = Double(whiteTerritory + totalWhiteCaptures) + scoringState.komi
        }

        let winner: StoneColor = blackTotal > whiteTotal ? .black : .white
        return GameResult(
            winner: winner,
            blackScore: blackTotal,
            whiteScore: whiteTotal,
            komi: scoringState.komi,
            byResignation: false,
            byCaptureRace: false,
            captureTarget: nil,
            byTimeout: false,
            scoringRule: rule,
            blackStones: blackStones,
            whiteStones: whiteStones,
            blackTerritory: blackTerritory,
            whiteTerritory: whiteTerritory,
            blackCaptures: totalBlackCaptures,
            whiteCaptures: totalWhiteCaptures,
            dameCount: dameCount,
            sekiGroupCount: seki.sekiPairCount,
            boardSize: size
        )
    }

    /// Backwards-compatible wrapper for Chinese Area Scoring.
    static func chineseAreaScore(
        state: GoBoardState,
        deadStoneIndices: Set<Int> = []
    ) -> GameResult {
        score(state: state, rule: .chinese, deadStoneIndices: deadStoneIndices)
    }

    /// Real-time Bouzy-inspired influence & territory estimator for live "形势判断 / Territory" overlay.
    static func estimateTerritory(
        state: GoBoardState,
        deadStoneIndices: Set<Int> = []
    ) -> TerritoryEstimate {
        var evalState = state
        if !deadStoneIndices.isEmpty {
            for idx in deadStoneIndices where idx >= 0 && idx < evalState.grid.count {
                evalState.grid[idx] = nil
            }
        }

        let size = evalState.size
        let total = size * size

        // 1. Seed initial influence from live stones (stones in atari exert weaker influence)
        var field = Array(repeating: 0.0, count: total)
        let groups = evalState.allGroups()
        for group in groups {
            let sign = (group.color == .black) ? 1.0 : -1.0
            let weight: Double = group.liberties.count == 1 ? 0.35 : 1.0
            for idx in group.stones {
                field[idx] = sign * weight
            }
        }

        // 2. Iterative diffusion (dilation)
        let diffusionSteps = size <= 9 ? 4 : 5
        for _ in 0..<diffusionSteps {
            var next = field
            for idx in 0..<total {
                if let stone = evalState.grid[idx] {
                    next[idx] = stone == .black ? 1.0 : -1.0
                    continue
                }
                var sum = field[idx] * 0.45
                var count = 0.45
                for n in evalState.neighbors(of: idx) {
                    sum += field[n]
                    count += 1.0
                }
                next[idx] = sum / count
            }
            field = next
        }

        // 3. Strictly enclosed regions get full ownership confidence
        var visitedEmpty = Array(repeating: false, count: total)
        for idx in 0..<total where evalState.grid[idx] == nil && !visitedEmpty[idx] {
            var region: [Int] = [idx]
            var stack: [Int] = [idx]
            visitedEmpty[idx] = true
            var touchesBlack = false
            var touchesWhite = false

            while let cur = stack.popLast() {
                for n in evalState.neighbors(of: cur) {
                    if let stone = evalState.grid[n] {
                        if stone == .black { touchesBlack = true }
                        else { touchesWhite = true }
                    } else if !visitedEmpty[n] {
                        visitedEmpty[n] = true
                        region.append(n)
                        stack.append(n)
                    }
                }
            }
            if touchesBlack && !touchesWhite {
                for rIdx in region { field[rIdx] = 1.0 }
            } else if touchesWhite && !touchesBlack {
                for rIdx in region { field[rIdx] = -1.0 }
            }
        }

        var blackArea = 0.0
        var whiteArea = 0.0
        for idx in 0..<total {
            if let stone = evalState.grid[idx] {
                if stone == .black { blackArea += 1 } else { whiteArea += 1 }
            } else {
                if field[idx] > 0.28 {
                    blackArea += 1
                } else if field[idx] < -0.28 {
                    whiteArea += 1
                }
            }
        }

        return TerritoryEstimate(
            ownership: field,
            blackArea: blackArea,
            whiteArea: whiteArea,
            komi: evalState.komi
        )
    }
}
