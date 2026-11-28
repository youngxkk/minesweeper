//
//  LocalMCTSGoEngine.swift
//  StarYi Go — Multi-Ply UCT+RAVE MCTS, Tactical Ladder Reader & Coaching AI
//

import Foundation

/// Pure-Swift offline Go AI combining:
/// 1. Exact tactical reading (recursive Ladder solver, snapback/atari, 3x3 local shapes)
/// 2. Opening & Corner Joseki book for 9x9 / 13x13 / 19x19
/// 3. Multi-ply UCT + RAVE (AMAF) Monte Carlo Tree Search with progressive widening & PV extraction
/// 4. Purposeful Kid Coaching Styles (instead of blind random blunders)
/// 5. Full post-game Winrate/ScoreLead Curve & Plain-Language Mistake Diagnostics
final class LocalMCTSGoEngine: GoAIEngine, @unchecked Sendable {
    let engineName = "StarYi Multi-Ply MCTS + Tactical Reader"

    func selectMove(
        for state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty
    ) async -> MoveAction {
        await selectMove(for: state, color: color, level: level, ruleSet: .standard, coachingStyle: .standard)
    }

    private func runCancellableBackground<T: Sendable>(
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @Sendable () -> T
    ) async -> T {
        let child = Task.detached(priority: priority) {
            operation()
        }
        return await withTaskCancellationHandler {
            await child.value
        } onCancel: {
            child.cancel()
        }
    }

    func selectMove(
        for state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty,
        ruleSet: GameRuleSet,
        coachingStyle: AICoachingStyle = .standard
    ) async -> MoveAction {
        await runCancellableBackground { [self] in
            var random = SystemRandomNumberGenerator()
            return self.computeMoveSync(for: state, color: color, level: level, ruleSet: ruleSet, coachingStyle: coachingStyle, random: &random)
        }
    }

    func suggestMoves(
        for state: GoBoardState,
        color: StoneColor,
        count: Int = 2
    ) async -> [MoveSuggestion] {
        await runCancellableBackground { [self] in
            let analysis = self.analyzePositionSync(for: state, color: color, maxVariations: max(2, count), iterations: state.size <= 9 ? 140 : 80)
            return analysis.topVariations.prefix(count).map { v in
                MoveSuggestion(point: v.firstMove, score: v.winrateForMover, reason: v.reason, pvMoves: v.pvMoves)
            }
        }
    }

    func analyzePosition(
        for state: GoBoardState,
        color: StoneColor,
        maxVariations: Int = 3
    ) async -> PositionAnalysis {
        await runCancellableBackground { [self] in
            self.analyzePositionSync(for: state, color: color, maxVariations: maxVariations, iterations: state.size <= 9 ? 160 : 90)
        }
    }

    func analyzeGame(
        initialState: GoBoardState,
        moves: [GoMove]
    ) async -> GameReviewReport {
        await runCancellableBackground { [self] in
            self.analyzeGameSync(initialState: initialState, moves: moves)
        }
    }

    /// Fast local tactical refutation used in Puzzle mode when a child plays an unscripted wrong move,
    /// so the opponent visually demonstrates WHY the move fails (e.g., escaping or counter-capturing).
    static func bestLocalReply(
        for state: GoBoardState,
        color: StoneColor,
        near focusPoint: BoardPoint,
        within region: BoardCropRegion? = nil
    ) -> MoveAction? {
        let engine = LocalMCTSGoEngine()
        let candidates = engine.evaluateCandidates(
            state: state,
            color: color,
            level: .panda,
            ruleSet: .captureRace(target: 1),
            coachingStyle: .standard,
            enableLadderReading: true
        )
        let filtered = candidates.filter { c in
            if let region, !region.contains(c.point) { return false }
            let dist = abs(c.point.row - focusPoint.row) + abs(c.point.col - focusPoint.col)
            return dist <= 3 || c.reason == .capture || c.reason == .escape
        }
        if let best = filtered.first ?? candidates.first {
            return .place(best.point)
        }
        return nil
    }

    // MARK: - Multi-Ply UCT+RAVE Tree Node

    private final class MCTSNode {
        let movePoint: BoardPoint?
        let reason: HintReason
        let prior: Double
        let state: GoBoardState
        let moverJustPlayed: StoneColor?
        weak var parent: MCTSNode?
        var children: [MCTSNode] = []
        var visits: Int = 0
        var totalReward: Double = 0.0 // always from `moverJustPlayed`'s perspective
        var raveVisits: Int = 0
        var raveReward: Double = 0.0
        var isExpanded: Bool = false

        init(
            movePoint: BoardPoint?,
            reason: HintReason = .territory,
            prior: Double = 0.5,
            state: GoBoardState,
            moverJustPlayed: StoneColor?,
            parent: MCTSNode? = nil
        ) {
            self.movePoint = movePoint
            self.reason = reason
            self.prior = prior
            self.state = state
            self.moverJustPlayed = moverJustPlayed
            self.parent = parent
        }

        var meanValue: Double {
            visits > 0 ? totalReward / Double(visits) : prior
        }

        func ucbRaveScore(parentLogN: Double, cPuct: Double = 1.15) -> Double {
            let v = Double(visits)
            let q = visits > 0 ? (totalReward / v) : prior
            let rQ = raveVisits > 0 ? (raveReward / Double(raveVisits)) : q
            let beta = Double(raveVisits) / (v + Double(raveVisits) + 0.0001 * v * Double(raveVisits) + 25.0)
            let combinedQ = (1.0 - beta) * q + beta * rQ
            let explore = cPuct * (0.45 + prior) * sqrt(parentLogN / (v + 1.0))
            return combinedQ + explore
        }
    }

    private struct Candidate {
        let index: Int
        let point: BoardPoint
        let heuristicScore: Double
        let reason: HintReason
    }

    // MARK: - Core Synchronous Move Selection

    func computeMoveSync(
        for state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty,
        ruleSet: GameRuleSet,
        coachingStyle: AICoachingStyle,
        random: inout some RandomNumberGenerator
    ) -> MoveAction {
        let enableLadder = (level != .sprout)
        let candidates = evaluateCandidates(
            state: state,
            color: color,
            level: level,
            ruleSet: ruleSet,
            coachingStyle: coachingStyle,
            enableLadderReading: enableLadder
        )
        guard !candidates.isEmpty else { return .pass }

        // Smart endgame pass check (standard mode only)
        if !ruleSet.isCaptureRace {
            let readiness = GoScoring.analyzeEndgameReadiness(state: state)
            if state.consecutivePasses >= 1 {
                let bestScore = candidates[0].heuristicScore
                let est = GoScoring.estimateTerritory(state: state)
                let myLead = (color == .black) ? est.blackLead : -est.blackLead
                if bestScore < 4.5 && (readiness.isReadyToScore || myLead > 2.0 || state.moveCount > state.size * state.size / 2) {
                    return .pass
                }
            }
            if candidates[0].heuristicScore < 1.8 && state.moveCount > (state.size * state.size * 2) / 3 && readiness.isReadyToScore {
                return .pass
            }
            // If every remaining legal move has negative value (e.g. only hopeless opponent pockets,
            // own secure territory fills, or self-atari left), pass instead of throwing dead stones.
            if candidates[0].heuristicScore < 0.0 && state.moveCount >= state.size {
                return .pass
            }
        }

        // Immediate winning capture in Capture Race
        if case .captureRace(let target) = ruleSet {
            let currentCaps = (color == .black) ? state.blackCaptures : state.whiteCaptures
            for c in candidates.prefix(10) where c.reason == .capture {
                if case .success(let out) = state.applying(action: .place(c.point), color: color),
                   currentCaps + out.capturedPoints.count >= target {
                    return .place(c.point)
                }
            }
        }

        // Sprout / Coaching Sparring Beginner Level:
        // Structured human-like teaching selection (avoids senseless self-atari & junk 1st-line spam)
        let iterations = level.mctsIterations(for: state.size)
        if iterations == 0 {
            return pickHumanLikeTeachingMove(from: candidates, level: level, coachingStyle: coachingStyle, random: &random)
        }

        let root = runMultiPlyMCTS(
            rootState: state,
            color: color,
            level: level,
            iterations: iterations,
            ruleSet: ruleSet,
            coachingStyle: coachingStyle,
            random: &random
        )

        guard !root.children.isEmpty else {
            return .place(candidates[0].point)
        }

        let sortedChildren = root.children.sorted { a, b in
            if a.visits != b.visits { return a.visits > b.visits }
            return a.meanValue > b.meanValue
        }

        // For lower ranked levels (Rabbit/Fox), choose softly from top 2-3 plausible moves (human-like, never random trash!)
        if level == .rabbit || level == .fox {
            let pool = Array(sortedChildren.prefix(level == .rabbit ? 3 : 2))
            let bestVal = pool[0].meanValue
            let viable = pool.filter { bestVal - $0.meanValue <= (level == .rabbit ? 0.14 : 0.06) }
            if let picked = viable.randomElement(using: &random), let pt = picked.movePoint {
                return .place(pt)
            }
        }

        if let bestPt = sortedChildren.first?.movePoint {
            return .place(bestPt)
        }
        return .place(candidates[0].point)
    }

    /// Picks a plausible human-like move for beginners / themed sparring instead of blind noise.
    private func pickHumanLikeTeachingMove(
        from candidates: [Candidate],
        level: AIDifficulty,
        coachingStyle: AICoachingStyle,
        random: inout some RandomNumberGenerator
    ) -> MoveAction {
        let safePool = candidates.filter { $0.heuristicScore > -2.0 }
        let pool = safePool.isEmpty ? candidates : safePool
        let topK = min(pool.count, coachingStyle == .standard ? 5 : 4)
        // Softmax-like weighted selection over top reasonable moves
        var weights: [Double] = []
        let temp = max(4.0, level.explorationNoise)
        let maxS = pool[0].heuristicScore
        for i in 0..<topK {
            weights.append(exp((pool[i].heuristicScore - maxS) / temp))
        }
        let sumW = weights.reduce(0, +)
        var r = Double.random(in: 0..<max(0.0001, sumW), using: &random)
        for i in 0..<topK {
            r -= weights[i]
            if r <= 0 {
                return .place(pool[i].point)
            }
        }
        return .place(pool[0].point)
    }

    // MARK: - Multi-Ply UCT + RAVE Tree Search

    private func runMultiPlyMCTS(
        rootState: GoBoardState,
        color: StoneColor,
        level: AIDifficulty,
        iterations: Int,
        ruleSet: GameRuleSet,
        coachingStyle: AICoachingStyle,
        random: inout some RandomNumberGenerator
    ) -> MCTSNode {
        var adjustedState = rootState
        adjustedState.currentTurn = color

        let root = MCTSNode(movePoint: nil, state: adjustedState, moverJustPlayed: nil)
        let rootWidth = rootState.size <= 9 ? 14 : (rootState.size <= 13 ? 12 : 10)
        expandNode(root, maxChildren: rootWidth, level: level, ruleSet: ruleSet, coachingStyle: coachingStyle, enableLadder: true)

        guard !root.children.isEmpty else { return root }

        let playoutDepth = rootState.size <= 7 ? 22 : (rootState.size <= 9 ? 30 : (rootState.size <= 13 ? 24 : 18))
        let totalIters = max(root.children.count * 2, iterations)

        for _ in 0..<totalIters {
            // Undo / quit / suspend cancels the enclosing task; stop burning a core on
            // results nobody will use.
            if Task.isCancelled { break }
            // 1. Selection down the tree using UCT + RAVE
            var node = root
            var path: [MCTSNode] = [root]

            while node.isExpanded && !node.children.isEmpty {
                let logN = log(Double(max(2, node.visits + 1)))
                var bestChild = node.children[0]
                var bestScore = -Double.infinity
                for child in node.children {
                    let s = child.ucbRaveScore(parentLogN: logN)
                    if s > bestScore {
                        bestScore = s
                        bestChild = child
                    }
                }
                node = bestChild
                path.append(node)
            }

            // 2. Expansion when a leaf has been visited enough (multi-ply tree growth!)
            if !node.isExpanded && node.visits >= 4 && path.count < 6 && !node.state.isDoublePassEnded {
                let childWidth = path.count == 2 ? 6 : 4
                expandNode(node, maxChildren: childWidth, level: level, ruleSet: ruleSet, coachingStyle: coachingStyle, enableLadder: false)
                if let firstChild = node.children.first {
                    node = firstChild
                    path.append(node)
                }
            }

            // 3. Tactical Playout + AMAF tracking for RAVE
            var playedByBlack: Set<BoardPoint> = []
            var playedByWhite: Set<BoardPoint> = []
            let blackWinProb = simulatePlayout(
                from: node.state,
                maxSteps: playoutDepth,
                ruleSet: ruleSet,
                playedByBlack: &playedByBlack,
                playedByWhite: &playedByWhite,
                random: &random
            )

            // 4. Backpropagation (including RAVE sibling updates)
            for pNode in path {
                pNode.visits += 1
                if let mover = pNode.moverJustPlayed {
                    let reward = (mover == .black) ? blackWinProb : (1.0 - blackWinProb)
                    pNode.totalReward += reward
                }

                // RAVE update on siblings of expanded nodes
                if pNode.isExpanded {
                    let childColor = pNode.state.currentTurn
                    let moveSet = (childColor == .black) ? playedByBlack : playedByWhite
                    let childReward = (childColor == .black) ? blackWinProb : (1.0 - blackWinProb)
                    for child in pNode.children {
                        if let pt = child.movePoint, moveSet.contains(pt) {
                            child.raveVisits += 1
                            child.raveReward += childReward
                        }
                    }
                }
            }
        }

        return root
    }

    private func expandNode(
        _ node: MCTSNode,
        maxChildren: Int,
        level: AIDifficulty,
        ruleSet: GameRuleSet,
        coachingStyle: AICoachingStyle,
        enableLadder: Bool
    ) {
        let mover = node.state.currentTurn
        let cands = evaluateCandidates(
            state: node.state,
            color: mover,
            level: level,
            ruleSet: ruleSet,
            coachingStyle: coachingStyle,
            enableLadderReading: enableLadder
        )
        let viableCands = cands.filter { $0.heuristicScore >= -5.0 }
        let shortlist = Array((viableCands.isEmpty ? cands : viableCands).prefix(maxChildren))
        guard !shortlist.isEmpty else {
            node.isExpanded = true
            return
        }

        let maxS = shortlist.map(\.heuristicScore).max() ?? 1.0
        let minS = shortlist.map(\.heuristicScore).min() ?? 0.0
        let span = max(1.0, maxS - minS)

        // Fuse offline spatial Policy-Value neural prior at the root for strong ranks (5K -> 5D)
        let neuralEval: NeuralEvaluation? = (node.parent == nil && !ruleSet.isCaptureRace && (level == .crane || level == .tiger || level.isHighDan))
            ? StarYiNeuralPolicyValueNet.evaluate(state: node.state, mover: mover)
            : nil
        let n = node.state.size

        var built: [MCTSNode] = []
        built.reserveCapacity(shortlist.count)
        for c in shortlist {
            if case .success(let out) = node.state.applying(action: .place(c.point), color: mover) {
                var normPrior = 0.20 + 0.72 * ((c.heuristicScore - minS) / span)
                if let nn = neuralEval {
                    let nnProb = nn.policy[c.point.row * n + c.point.col]
                    normPrior = normPrior * 0.58 + min(1.0, nnProb * 7.5) * 0.42
                }
                built.append(MCTSNode(
                    movePoint: c.point,
                    reason: c.reason,
                    prior: normPrior,
                    state: out.nextState,
                    moverJustPlayed: mover,
                    parent: node
                ))
            }
        }
        node.children = built
        node.isExpanded = true
    }

    private func extractPV(from node: MCTSNode, maxLength: Int = 5) -> [BoardPoint] {
        var pv: [BoardPoint] = []
        var cur: MCTSNode? = node
        while let n = cur, pv.count < maxLength {
            if let pt = n.movePoint {
                pv.append(pt)
            }
            cur = n.children.max { a, b in
                if a.visits != b.visits { return a.visits < b.visits }
                return a.meanValue < b.meanValue
            }
        }
        return pv
    }

    // MARK: - Position & Full Game Analysis (Winrate Curve + Diagnostics)

    func analyzePositionSync(
        for state: GoBoardState,
        color: StoneColor,
        maxVariations: Int = 3,
        iterations: Int = 120
    ) -> PositionAnalysis {
        var random = SystemRandomNumberGenerator()
        let root = runMultiPlyMCTS(
            rootState: state,
            color: color,
            level: .dragon,
            iterations: iterations,
            ruleSet: .standard,
            coachingStyle: .standard,
            random: &random
        )

        let est = GoScoring.estimateTerritory(state: state)
        let sorted = root.children.sorted { a, b in
            if a.visits != b.visits { return a.visits > b.visits }
            return a.meanValue > b.meanValue
        }

        let variations: [MoveVariation] = sorted.prefix(maxVariations).compactMap { child in
            guard let pt = child.movePoint else { return nil }
            let pv = extractPV(from: child, maxLength: 5)
            let childEst = GoScoring.estimateTerritory(state: child.state)
            return MoveVariation(
                firstMove: pt,
                winrateForMover: min(0.98, max(0.02, child.meanValue)),
                scoreLeadForBlack: childEst.blackLead,
                pvMoves: pv,
                reason: child.reason
            )
        }

        let bestMoverWR = variations.first?.winrateForMover ?? (1.0 / (1.0 + exp(-est.blackLead / Double(max(5, state.size)))))
        let blackWR = min(0.98, max(0.02, (color == .black) ? bestMoverWR : (1.0 - bestMoverWR)))
        let counts = countStones(on: state)
        let calibratedLead = calibratedScoreLead(
            state: state,
            blackCount: counts.black,
            whiteCount: counts.white,
            blackWinrate: blackWR,
            rawTerritoryLead: est.blackLead
        )

        return PositionAnalysis(
            blackWinrate: blackWR,
            blackScoreLead: calibratedLead,
            topVariations: variations
        )
    }

    private func countStones(on state: GoBoardState) -> (black: Int, white: Int) {
        var b = 0, w = 0
        for stone in state.grid {
            if stone == .black { b += 1 }
            else if stone == .white { w += 1 }
        }
        return (b, w)
    }

    /// Prevents flood-fill territory estimation from assigning the entire empty board (+353.5 pts!)
    /// during early opening moves when only one color or very few stones exist, and ensures
    /// scoreLead stays directionally consistent with blackWinrate.
    private func calibratedScoreLead(
        state: GoBoardState,
        blackCount: Int,
        whiteCount: Int,
        blackWinrate: Double,
        rawTerritoryLead: Double
    ) -> Double {
        let clampedWR = min(0.96, max(0.04, blackWinrate))
        let wrLead = log(clampedWR / (1.0 - clampedWR)) * Double(state.size) * 0.25
        let totalStones = blackCount + whiteCount
        let boardArea = Double(state.size * state.size)

        // Before both players have stones or in early opening, flood-fill territory is meaningless.
        if blackCount == 0 || whiteCount == 0 || totalStones < max(6, state.size / 2) {
            return (wrLead * 2.0).rounded() / 2.0
        }

        // Guard against wildly inflated flood-fill leads when the board is still mostly open.
        let fillRatio = Double(totalStones) / max(1.0, boardArea)
        let maxPlausibleLead = fillRatio < 0.25 ? Double(state.size) * 1.5 : boardArea * 0.45
        if abs(rawTerritoryLead) > maxPlausibleLead {
            return (wrLead * 2.0).rounded() / 2.0
        }

        // If winrate and raw territory lead disagree strongly in sign, trust winrate-calibrated lead.
        let wrSign = blackWinrate - 0.5
        if abs(wrSign) > 0.05 && (wrSign * rawTerritoryLead < 0) {
            return (wrLead * 2.0).rounded() / 2.0
        }

        let blend = min(1.0, max(0.0, (fillRatio - 0.08) / 0.25))
        let result = wrLead * (1.0 - blend) + rawTerritoryLead * blend
        return (result * 2.0).rounded() / 2.0
    }

    /// Checks whether `played` maps to any point in `candidates` under a dihedral (D4) symmetry
    /// that leaves `state` invariant (e.g., all 4 star points on an empty board are equivalent).
    private func isSymmetricallyEquivalent(
        played: BoardPoint,
        to candidates: [BoardPoint],
        on state: GoBoardState
    ) -> Bool {
        if candidates.contains(played) { return true }
        let n = state.size
        func transform(_ pt: BoardPoint, _ sym: Int) -> BoardPoint {
            let r = pt.row, c = pt.col
            switch sym {
            case 0: return BoardPoint(row: r, col: c)
            case 1: return BoardPoint(row: r, col: n - 1 - c)
            case 2: return BoardPoint(row: n - 1 - r, col: c)
            case 3: return BoardPoint(row: n - 1 - r, col: n - 1 - c)
            case 4: return BoardPoint(row: c, col: r)
            case 5: return BoardPoint(row: c, col: n - 1 - r)
            case 6: return BoardPoint(row: n - 1 - c, col: r)
            default: return BoardPoint(row: n - 1 - c, col: n - 1 - r)
            }
        }
        let isEmpty = state.grid.allSatisfy { $0 == nil }
        for sym in 1..<8 {
            let mapped = transform(played, sym)
            guard candidates.contains(mapped) else { continue }
            if isEmpty { return true }
            var invariant = true
            for r in 0..<n where invariant {
                for c in 0..<n {
                    let p = BoardPoint(row: r, col: c)
                    let tp = transform(p, sym)
                    if state.stone(at: p) != state.stone(at: tp) {
                        invariant = false
                        break
                    }
                }
            }
            if invariant { return true }
        }
        return false
    }

    private func analyzeGameSync(
        initialState: GoBoardState,
        moves: [GoMove]
    ) -> GameReviewReport {
        var states: [GoBoardState] = [initialState]
        var cur = initialState
        for mv in moves {
            if case .success(let out) = cur.applying(action: mv.action, color: mv.color) {
                cur = out.nextState
            }
            states.append(cur)
        }

        // Fast per-move evaluation calibrated by game length so full-game review completes in ~1-2s!
        let perMoveIters = moves.count > 80 ? 28 : (moves.count > 40 ? 44 : 64)
        var winrateHistory: [Double] = [0.5]
        var scoreLeadHistory: [Double] = [0.0]
        var reviewed: [ReviewedMove] = []

        var prevBlackWR = 0.5
        var prevBlackLead = 0.0

        for (i, mv) in moves.enumerated() {
            let stateBefore = states[i]
            let stateAfter = states[i + 1]

            let preAnalysis = analyzePositionSync(for: stateBefore, color: mv.color, maxVariations: 3, iterations: perMoveIters)
            let afterEst = GoScoring.estimateTerritory(state: stateAfter)
            let bestBeforeMoverWR = preAnalysis.topVariations.first?.winrateForMover ?? (mv.color == .black ? prevBlackWR : (1.0 - prevBlackWR))
            let bestMovePt = preAnalysis.topVariations.first?.firstMove
            let topCandidatePts = Array(preAnalysis.topVariations.prefix(2).map(\.firstMove))

            let isBeforeEmpty = stateBefore.grid.allSatisfy { $0 == nil }
            let playedIsOpeningStandard: Bool = {
                guard isBeforeEmpty, case .place(let p) = mv.action else { return false }
                let s = stateBefore.size
                let minEdge = min(p.row, p.col, s - 1 - p.row, s - 1 - p.col)
                return s >= 9 ? (minEdge >= 2) : (minEdge >= 1)
            }()

            let playedIsTop: Bool = {
                if case .place(let p) = mv.action {
                    if playedIsOpeningStandard { return true }
                    return isSymmetricallyEquivalent(played: p, to: topCandidatePts, on: stateBefore)
                }
                return false
            }()

            let stoneCounts = countStones(on: stateAfter)
            let totalStonesAfter = stoneCounts.black + stoneCounts.white
            let hasBothColors = stoneCounts.black > 0 && stoneCounts.white > 0
            let rawAfterWR: Double = hasBothColors
                ? (1.0 / (1.0 + exp(-afterEst.blackLead / Double(max(6, stateAfter.size)))))
                : 0.5

            let afterBlackWR: Double
            if isBeforeEmpty && playedIsTop {
                afterBlackWR = 0.5
            } else if playedIsTop {
                afterBlackWR = (mv.color == .black) ? bestBeforeMoverWR : (1.0 - bestBeforeMoverWR)
            } else {
                afterBlackWR = 0.55 * rawAfterWR + 0.45 * prevBlackWR
            }

            let afterBlackLead = calibratedScoreLead(
                state: stateAfter,
                blackCount: stoneCounts.black,
                whiteCount: stoneCounts.white,
                blackWinrate: afterBlackWR,
                rawTerritoryLead: afterEst.blackLead
            )

            let moverWRBefore = (mv.color == .black) ? prevBlackWR : (1.0 - prevBlackWR)
            let moverWRAfter = (mv.color == .black) ? afterBlackWR : (1.0 - afterBlackWR)
            let wrDrop = (isBeforeEmpty && playedIsTop) ? 0.0 : max(0.0, moverWRBefore - moverWRAfter)

            let moverLeadBefore = (mv.color == .black) ? prevBlackLead : -prevBlackLead
            let moverLeadAfter = (mv.color == .black) ? afterBlackLead : -afterBlackLead
            let scoreDrop = (isBeforeEmpty && playedIsTop) ? 0.0 : max(0.0, moverLeadBefore - moverLeadAfter)

            // Ensure Move 1 symmetric standard opening isn't compared against an equivalent corner
            let effectiveBestPoint = (isBeforeEmpty && playedIsTop) ? nil : bestMovePt
            let _ = totalStonesAfter

            // Detect concrete Go tactical mistakes for plain-language kid-friendly feedback!
            let (quality, diagZh, diagEn) = diagnoseMove(
                move: mv,
                stateBefore: stateBefore,
                stateAfter: stateAfter,
                bestPoint: effectiveBestPoint,
                bestReason: preAnalysis.topVariations.first?.reason,
                wrDrop: wrDrop,
                scoreDrop: scoreDrop,
                playedIsTop: playedIsTop
            )

            winrateHistory.append(afterBlackWR)
            scoreLeadHistory.append(afterBlackLead)
            reviewed.append(ReviewedMove(
                id: mv.moveNumber,
                moveNumber: mv.moveNumber,
                color: mv.color,
                playedAction: mv.action,
                blackWinrateAfter: afterBlackWR,
                blackScoreLeadAfter: afterBlackLead,
                moverWinrateDrop: wrDrop,
                moverScoreDrop: scoreDrop,
                quality: quality,
                diagnosisZh: diagZh,
                diagnosisEn: diagEn,
                topVariations: preAnalysis.topVariations
            ))

            prevBlackWR = afterBlackWR
            prevBlackLead = afterBlackLead
        }

        return GameReviewReport(
            initialBlackWinrate: 0.5,
            winrateHistory: winrateHistory,
            scoreLeadHistory: scoreLeadHistory,
            reviewedMoves: reviewed
        )
    }

    private func diagnoseMove(
        move: GoMove,
        stateBefore: GoBoardState,
        stateAfter: GoBoardState,
        bestPoint: BoardPoint?,
        bestReason: HintReason?,
        wrDrop: Double,
        scoreDrop: Double,
        playedIsTop: Bool
    ) -> (MoveQuality, String, String) {
        let bestLabel = bestPoint?.humanLabel(boardSize: stateBefore.size) ?? ""

        // 1. Check if player walked into self-atari without capturing
        if case .place(let pt) = move.action, move.capturedPoints.isEmpty {
            let idx = stateAfter.index(row: pt.row, col: pt.col)
            if let g = stateAfter.groupAndLiberties(at: idx), g.liberties.count == 1 {
                return (
                    .blunder,
                    "自撞紧气！这手棋下完自己只剩 1 口气，容易被对手直接提掉。建议改下 \(bestLabel)。",
                    "Self-atari! This move leaves your own group with only 1 liberty. Try \(bestLabel) instead."
                )
            }
        }

        // 2. Check if player missed saving own group in atari
        let beforeAtariOwn = stateBefore.allGroups().filter { $0.color == move.color && $0.liberties.count == 1 }
        if !beforeAtariOwn.isEmpty {
            let stillInAtari = stateAfter.allGroups().filter { $0.color == move.color && $0.liberties.count == 1 }
            if !stillInAtari.isEmpty && !playedIsTop && bestReason == .escape {
                return (
                    .blunder,
                    "漏看叫吃！棋盘上有己方棋块只剩 1 口气危在旦夕，应先考虑 \(bestLabel) 长气救回。",
                    "Missed Atari! One of your groups was down to 1 liberty — rescuing around \(bestLabel) was urgent."
                )
            }
        }

        // 3. Check if player missed an immediate capture
        if !playedIsTop && bestReason == .capture && move.capturedPoints.isEmpty && scoreDrop >= 2.5 {
            return (
                .mistake,
                "错失提子良机！对手有棋子只剩最后 1 口气，下在 \(bestLabel) 可以直接提子。",
                "Missed Capture! An enemy group had 1 liberty — playing \(bestLabel) captures it immediately."
            )
        }

        // 4. General score / winrate drop classification
        if wrDrop >= 0.14 || scoreDrop >= 6.5 {
            return (
                .blunder,
                "大恶手（约亏 \(String(format: "%.1f", max(scoreDrop, 4.0))) 目）：错过关键攻防要点，AI 推荐 \(bestLabel)。",
                "Blunder (~\(String(format: "%.1f", max(scoreDrop, 4.0))) pts lost): Missed a vital point — AI recommends \(bestLabel)."
            )
        } else if wrDrop >= 0.08 || scoreDrop >= 3.5 {
            return (
                .mistake,
                "缓手/问题手（约亏 \(String(format: "%.1f", max(scoreDrop, 2.5))) 目）：局部或大场价值不够大，\(bestLabel) 更积极。",
                "Mistake (~\(String(format: "%.1f", max(scoreDrop, 2.5))) pts lost): Slightly slow — \(bestLabel) is more active."
            )
        } else if wrDrop >= 0.045 || scoreDrop >= 2.0 {
            return (
                .inaccuracy,
                "略有损目：可以考虑更紧凑的 \(bestLabel)。",
                "Small inaccuracy: \(bestLabel) keeps better shape and value."
            )
        } else if playedIsTop && (!move.capturedPoints.isEmpty || bestReason == .escape || bestReason == .connect) {
            return (
                .brilliant,
                "好手！精准抓住了本局的攻防要点。",
                "Strong move! You found the exact tactical vital point."
            )
        } else {
            return (
                .good,
                "稳健正手，行棋方向合理。",
                "Solid move with good balance and direction."
            )
        }
    }

    // MARK: - Heuristic Tactical Evaluator (with Ladder Reading, 3x3 Shapes, Opening Book & Coaching Styles)

    private func evaluateCandidates(
        state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty,
        ruleSet: GameRuleSet,
        coachingStyle: AICoachingStyle = .standard,
        enableLadderReading: Bool = true
    ) -> [Candidate] {
        let size = state.size
        let total = size * size
        let opponent = color.opposite
        let isCaptureRace = ruleSet.isCaptureRace

        // Character playstyle + Coaching theme weights
        var atariWeight: Double = (level == .rabbit || level == .fox || level == .tiger) ? 1.30 : (level == .panda || level == .deer ? 0.94 : 1.08)
        var connectWeight: Double = (level == .panda || level == .crane || level == .deer) ? 1.35 : 1.08
        var cutWeight: Double = (level == .fox || level == .tiger || level.isHighDan) ? 1.35 : 1.05
        let captureMultiplier: Double = isCaptureRace ? 1.65 : 1.0

        switch coachingStyle {
        case .standard:
            break
        case .capturePractice:
            atariWeight *= 0.80 // Slightly softer defense so kids spot double-atari & captures
        case .shapeAndConnect:
            connectWeight *= 1.25
            cutWeight *= 1.30 // Actively creates cut/connect teaching moments
        case .ladderAndNet:
            cutWeight *= 1.35
        }

        let groups = state.allGroups()
        var groupIndexAt = Array(repeating: -1, count: total)
        for (gIdx, g) in groups.enumerated() {
            for s in g.stones { groupIndexAt[s] = gIdx }
        }
        let hopelessOpponentPocketMask: [Bool] = isCaptureRace
            ? Array(repeating: false, count: total)
            : Self.computeHopelessOpponentPocketMask(
                state: state,
                for: color,
                groups: groups,
                groupIndexAt: groupIndexAt
            )

        let lastPt: BoardPoint? = {
            if case .place(let p) = state.lastMove { return p }
            return nil
        }()

        let starSet = Set(BoardSize(rawValue: size)?.starPoints ?? [])
        let isOpening = state.moveCount < (size <= 5 ? 3 : (size <= 7 ? 5 : (size <= 9 ? 8 : (size <= 13 ? 16 : 28))))

        var candidates: [Candidate] = []
        candidates.reserveCapacity(total / 2)

        for idx in 0..<total {
            if Task.isCancelled { break }
            guard state.grid[idx] == nil, idx != state.koIndex else { continue }
            let pt = state.point(for: idx)

            // Only skip truly pointless self-eye fills (still allows snapbacks, ko fills, captures!)
            if state.isPointlessSelfEyeFill(index: idx, for: color) {
                continue
            }

            guard case .success(let outcome) = state.applying(action: .place(pt), color: color) else {
                continue
            }

            var score = 5.0
            var primaryReason: HintReason = .territory

            // 1. Capturing opponent stones
            let capturedCount = outcome.capturedPoints.count
            if capturedCount > 0 {
                score += (52.0 + Double(capturedCount) * 28.0) * captureMultiplier
                primaryReason = .capture
            }

            let newOwnGroup = outcome.nextState.groupAndLiberties(at: idx)
            let newLibs = newOwnGroup?.liberties.count ?? 0
            let newSize = newOwnGroup?.stones.count ?? 1

            // 2. Saving own group(s) from Atari (WITH Ladder check so AI doesn't run into a working ladder!)
            var savedStones = 0
            var savedGroupSample: BoardPoint?
            var adjacentFriendlyGroups: Set<Int> = []
            var adjacentOpponentGroups: Set<Int> = []

            for n in state.neighbors(of: idx) {
                let gIdx = groupIndexAt[n]
                guard gIdx >= 0 else { continue }
                let g = groups[gIdx]
                if g.color == color {
                    adjacentFriendlyGroups.insert(gIdx)
                    if g.liberties.count == 1 {
                        savedStones += g.stones.count
                        savedGroupSample = state.point(for: n)
                    }
                } else if g.color == opponent {
                    adjacentOpponentGroups.insert(gIdx)
                }
            }

            if savedStones > 0 && newLibs >= 2 {
                var escapeValue = (44.0 + Double(savedStones) * 24.0) * captureMultiplier
                // Exact Ladder verification: if extending into 2 liberties gets caught in a working ladder, don't run!
                if enableLadderReading && newLibs == 2 && capturedCount == 0, let sample = savedGroupSample {
                    if case .captured = GoTacticalReader.readLadderDefenderToMove(state: state, targetStone: sample, maxDepth: 24) {
                        escapeValue = -18.0 // Caught in ladder -> sacrifice instead of throwing more stones!
                    }
                }
                score += escapeValue
                if escapeValue > 0 && primaryReason != .capture { primaryReason = .escape }
            }

            // 3. Self-atari penalty (unless snapback!)
            var isSnapback = false
            if newLibs == 1 && capturedCount == 0 {
                // Check if this is a clever Snapback (倒扑) sacrifice!
                if newSize == 1, let singleLib = newOwnGroup?.liberties.first {
                    let libPt = outcome.nextState.point(for: singleLib)
                    if case .success(let oppCap) = outcome.nextState.applying(action: .place(libPt), color: opponent) {
                        let oppAfterLibs = oppCap.nextState.groupAndLiberties(at: singleLib)?.liberties.count ?? 0
                        let oppAfterSize = oppCap.nextState.groupAndLiberties(at: singleLib)?.stones.count ?? 1
                        if oppAfterLibs == 1 && oppAfterSize >= 2 {
                            isSnapback = true
                        }
                    }
                }
                if isSnapback {
                    score += 46.0 * captureMultiplier
                    primaryReason = .capture
                } else {
                    score -= (36.0 + Double(newSize) * 7.5) * captureMultiplier
                }
            } else if newLibs == 2 {
                score += 3.0
            } else if newLibs >= 3 {
                score += 6.0
            }

            // 4. Putting opponent groups into Atari (WITH Double-Atari & Working-Ladder bonus!)
            var putInAtariGroups = 0
            var putInAtariStones = 0
            var checkedOppAfter: Set<Int> = []
            for n in outcome.nextState.neighbors(of: idx) where outcome.nextState.grid[n] == opponent {
                if !checkedOppAfter.contains(n), let oppG = outcome.nextState.groupAndLiberties(at: n) {
                    checkedOppAfter.formUnion(oppG.stones)
                    if oppG.liberties.count == 1 {
                        putInAtariGroups += 1
                        putInAtariStones += oppG.stones.count
                        // Exact ladder check when putting an opponent group into atari!
                        if enableLadderReading && oppG.stones.count <= 3 {
                            let samplePt = outcome.nextState.point(for: n)
                            if case .captured = GoTacticalReader.readLadderDefenderToMove(state: outcome.nextState, targetStone: samplePt, maxDepth: 20) {
                                score += 28.0 * captureMultiplier
                            }
                        }
                    } else if oppG.liberties.count == 2 {
                        score += (6.5 + Double(oppG.stones.count) * 1.6) * atariWeight
                    }
                }
            }
            if putInAtariStones > 0 && newLibs >= 2 {
                let doubleAtariBonus = putInAtariGroups >= 2 ? 32.0 : 0.0
                score += (24.0 + Double(putInAtariStones) * 12.0 + doubleAtariBonus) * atariWeight * captureMultiplier
                if primaryReason == .territory { primaryReason = .atari }
            }

            // 5. Connecting 2+ separate friendly groups
            if adjacentFriendlyGroups.count >= 2 && newLibs >= 2 {
                score += 19.0 * connectWeight
                if primaryReason == .territory { primaryReason = .connect }
            }

            // 6. Cutting opponent groups
            if adjacentOpponentGroups.count >= 2 && newLibs >= 2 {
                score += 17.5 * cutWeight
            }

            // 7. 3x3 Local Go Shape Recognition (empty triangle penalty, hane, tiger's mouth, bamboo joint)
            if newLibs >= 2 {
                score += GoTacticalReader.localShapeBonus(state: state, point: pt, color: color)
            }

            let isHopelessOpponentInvasion = !isCaptureRace
                && hopelessOpponentPocketMask[idx]
                && capturedCount == 0
                && putInAtariStones == 0
                && !isSnapback

            // 8. Authentic Opening & Corner Joseki Book
            if !isHopelessOpponentInvasion {
                if isOpening {
                    let bookBonus = GoTacticalReader.openingBookBonus(state: state, point: pt, color: color)
                    if bookBonus > 0 {
                        score += bookBonus
                        if primaryReason == .territory { primaryReason = .corner }
                    } else if starSet.contains(pt) && isLocalAreaEmpty(state: state, center: pt, radius: size <= 7 ? 1 : 2) {
                        score += 20.0
                        if primaryReason == .territory { primaryReason = .corner }
                    }

                    let distRow = min(pt.row, size - 1 - pt.row)
                    let distCol = min(pt.col, size - 1 - pt.col)
                    let minEdge = min(distRow, distCol)
                    let idealLine = size <= 5 ? 1 : (size <= 9 ? 2 : 3)
                    if minEdge == idealLine || minEdge == max(1, idealLine - 1) {
                        score += 7.5
                    } else if minEdge == 0 {
                        score -= 16.0
                    } else if minEdge == 1 && size >= 9 {
                        score -= 6.0
                    }
                } else {
                    let distRow = min(pt.row, size - 1 - pt.row)
                    let distCol = min(pt.col, size - 1 - pt.col)
                    let minEdge = min(distRow, distCol)
                    if minEdge == 0 && adjacentFriendlyGroups.isEmpty && adjacentOpponentGroups.isEmpty {
                        score -= 12.0
                    } else if minEdge >= 1 && minEdge <= 4 {
                        score += 3.0
                    }
                }

                // 9. Local fighting responsiveness
                if let lastPt {
                    let manhattan = abs(pt.row - lastPt.row) + abs(pt.col - lastPt.col)
                    if manhattan == 1 {
                        score += isCaptureRace ? 12.0 : 8.5
                    } else if manhattan == 2 {
                        score += isCaptureRace ? 8.0 : 6.0
                    } else if manhattan == 3 {
                        score += 3.0
                    }
                }
            }

            // 10. Avoid playing deep inside own secure territory
            if !isCaptureRace
                && isLikelyOwnTerritory(state: state, row: pt.row, col: pt.col, color: color)
                && adjacentOpponentGroups.isEmpty {
                score -= 14.0
            }

            // 11. Avoid pointless throws into sealed, unlivable opponent pockets (e.g. 1-2 line dead strips)
            if isHopelessOpponentInvasion {
                score -= (newLibs <= 2 ? 42.0 : 34.0)
            }

            candidates.append(Candidate(index: idx, point: pt, heuristicScore: score, reason: primaryReason))
        }

        candidates.sort { $0.heuristicScore > $1.heuristicScore }
        return candidates
    }

    // MARK: - Tactical Playout (returning Black win probability in [0, 1])

    private func simulatePlayout(
        from initialState: GoBoardState,
        maxSteps: Int,
        ruleSet: GameRuleSet,
        playedByBlack: inout Set<BoardPoint>,
        playedByWhite: inout Set<BoardPoint>,
        random: inout some RandomNumberGenerator
    ) -> Double {
        var state = initialState
        let total = state.size * state.size

        for _ in 0..<maxSteps {
            if Task.isCancelled { break }
            if case .captureRace(let target) = ruleSet {
                if state.blackCaptures >= target { return 1.0 }
                if state.whiteCaptures >= target { return 0.0 }
            }
            if state.isDoublePassEnded { break }
            let mover = state.currentTurn
            var moved = false

            // Fast local response around last move (save atari / capture / local shape)
            if case .place(let lastPt) = state.lastMove {
                let localOffsets = [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,1),(-1,1),(1,-1)]
                let start = Int.random(in: 0..<localOffsets.count, using: &random)
                for k in 0..<localOffsets.count {
                    let (dr, dc) = localOffsets[(start + k) % localOffsets.count]
                    let r = lastPt.row + dr
                    let c = lastPt.col + dc
                    if state.isValid(row: r, col: c) {
                        let idx = state.index(row: r, col: c)
                        if state.grid[idx] == nil && idx != state.koIndex && !state.isPointlessSelfEyeFill(index: idx, for: mover) {
                            let pt = BoardPoint(row: r, col: c)
                            if case .success(let out) = state.applying(action: .place(pt), color: mover) {
                                let libs = out.nextState.groupAndLiberties(at: idx)?.liberties.count ?? 0
                                if libs >= 2 || !out.capturedPoints.isEmpty {
                                    state = out.nextState
                                    if mover == .black { playedByBlack.insert(pt) } else { playedByWhite.insert(pt) }
                                    moved = true
                                    break
                                }
                            }
                        }
                    }
                }
            }

            if !moved {
                let startIdx = Int.random(in: 0..<total, using: &random)
                let attempts = min(total, 24)
                for step in 0..<attempts {
                    let idx = (startIdx + step * 7) % total
                    if state.grid[idx] == nil && idx != state.koIndex && !state.isPointlessSelfEyeFill(index: idx, for: mover) {
                        let pt = state.point(for: idx)
                        if case .success(let out) = state.applying(action: .place(pt), color: mover) {
                            let libs = out.nextState.groupAndLiberties(at: idx)?.liberties.count ?? 0
                            if libs >= 2 || !out.capturedPoints.isEmpty || step > 16 {
                                state = out.nextState
                                if mover == .black { playedByBlack.insert(pt) } else { playedByWhite.insert(pt) }
                                moved = true
                                break
                            }
                        }
                    }
                }
            }

            if !moved {
                if case .success(let out) = state.applying(action: .pass, color: mover) {
                    state = out.nextState
                } else {
                    break
                }
            }
        }

        if case .captureRace = ruleSet {
            let diff = Double(state.blackCaptures - state.whiteCaptures)
            return 1.0 / (1.0 + exp(-diff * 1.2))
        }

        let est = GoScoring.estimateTerritory(state: state)
        return 1.0 / (1.0 + exp(-est.blackLead / Double(max(5, state.size))))
    }

    // MARK: - Go Geometry Helpers

    private func isLocalAreaEmpty(state: GoBoardState, center: BoardPoint, radius: Int) -> Bool {
        for r in max(0, center.row - radius)...min(state.size - 1, center.row + radius) {
            for c in max(0, center.col - radius)...min(state.size - 1, center.col + radius) {
                if state.grid[state.index(row: r, col: c)] != nil {
                    return false
                }
            }
        }
        return true
    }

    /// Identifies empty intersections inside connected pockets that are completely enclosed by
    /// healthy opponent groups (all bordering opponent groups have >= 3 liberties) and are too
    /// narrow (width <= 2 lines, e.g. 2x6) or too small (<= 8 points) to realistically make two eyes —
    /// even if a few trapped, non-living friendly stones still sit inside the pocket.
    static func computeHopelessOpponentPocketMask(
        state: GoBoardState,
        for color: StoneColor,
        groups: [GoGroup],
        groupIndexAt: [Int]
    ) -> [Bool] {
        let size = state.size
        let total = size * size
        var mask = Array(repeating: false, count: total)
        var visited = Array(repeating: false, count: total)
        let opponent = color.opposite
        let aliveStones = state.twoEyeAliveAnalysis().aliveStoneIndices

        var queue: [Int] = []
        queue.reserveCapacity(32)
        var emptyCells: [Int] = []
        emptyCells.reserveCapacity(32)

        for start in 0..<total where state.grid[start] == nil && !visited[start] {
            queue.removeAll(keepingCapacity: true)
            emptyCells.removeAll(keepingCapacity: true)
            visited[start] = true
            queue.append(start)

            var touchesAliveOwn = false
            var touchesOpponent = false
            var allOppGroupsHealthy = true
            var totalPocketCells = 0
            var minR = size, maxR = -1, minC = size, maxC = -1

            var head = 0
            while head < queue.count {
                let curr = queue[head]
                head += 1
                totalPocketCells += 1
                if state.grid[curr] == nil {
                    emptyCells.append(curr)
                }

                let r = curr / size
                let c = curr % size
                if r < minR { minR = r }
                if r > maxR { maxR = r }
                if c < minC { minC = c }
                if c > maxC { maxC = c }

                for n in state.neighbors(of: curr) {
                    if let stone = state.grid[n] {
                        if stone == color {
                            if aliveStones.contains(n) {
                                touchesAliveOwn = true
                            } else if !visited[n] {
                                visited[n] = true
                                queue.append(n)
                            }
                        } else if stone == opponent {
                            touchesOpponent = true
                            let gIdx = groupIndexAt[n]
                            if gIdx >= 0 && groups[gIdx].liberties.count < 3 {
                                allOppGroupsHealthy = false
                            }
                        }
                    } else if !visited[n] {
                        visited[n] = true
                        queue.append(n)
                    }
                }
            }

            guard !touchesAliveOwn, touchesOpponent, allOppGroupsHealthy else { continue }

            let spanR = maxR - minR + 1
            let spanC = maxC - minC + 1
            let minSpan = min(spanR, spanC)
            if minSpan <= 2 || totalPocketCells <= 8 {
                for cell in emptyCells {
                    mask[cell] = true
                }
            }
        }

        return mask
    }

    private func isLikelyOwnTerritory(state: GoBoardState, row: Int, col: Int, color: StoneColor) -> Bool {
        var friendlyCount = 0
        var totalChecked = 0
        for dr in -2...2 {
            for dc in -2...2 where abs(dr) + abs(dc) <= 2 && !(dr == 0 && dc == 0) {
                let nr = row + dr, nc = col + dc
                if state.isValid(row: nr, col: nc) {
                    totalChecked += 1
                    if let s = state.grid[state.index(row: nr, col: nc)] {
                        if s == color { friendlyCount += 1 } else { return false }
                    }
                }
            }
        }
        return totalChecked > 0 && friendlyCount >= 4
    }
}
