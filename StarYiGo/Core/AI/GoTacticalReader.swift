//
//  GoTacticalReader.swift
//  StarYi Go — Exact Ladder Solver, Local 3x3 Shape Patterns & Opening Book
//

import Foundation

enum LadderResult: Equatable, Sendable {
    case captured(steps: [BoardPoint])
    case escaped(steps: [BoardPoint])
    case unknown
}

/// Pure-Swift tactical reader for exact Go reading:
/// - Full-board recursive Ladder (征子) verification with exact move sequence
/// - 3x3 shape recognition (empty triangle penalty, hane, tiger's mouth, bamboo joint)
/// - 9x9 / 13x13 / 19x19 opening & corner Joseki instincts
/// - Game Review blunder -> playable custom GoPuzzle converter
enum GoTacticalReader {

    // MARK: - Exact Ladder (征子) Solver

    /// Reads whether `targetStone` (currently with 1 liberty, defender to move) can escape a ladder,
    /// OR is captured when the attacker chases optimally.
    /// Returns the exact sequence of chase moves so it can power BOTH AI reading AND the Ladder Mini-Drill!
    static func readLadderDefenderToMove(
        state: GoBoardState,
        targetStone: BoardPoint,
        maxDepth: Int = 36
    ) -> LadderResult {
        let idx = state.index(row: targetStone.row, col: targetStone.col)
        guard let targetGroup = state.groupAndLiberties(at: idx),
              targetGroup.liberties.count == 1 else {
            return .unknown
        }
        let defender = targetGroup.color
        let attacker = defender.opposite

        var steps: [BoardPoint] = []
        var nodesRemaining = 256
        let escaped = searchDefenderEscape(
            state: state,
            targetIdx: idx,
            defender: defender,
            attacker: attacker,
            depth: 0,
            maxDepth: maxDepth,
            nodesRemaining: &nodesRemaining,
            outSteps: &steps
        )
        return escaped ? .escaped(steps: steps) : .captured(steps: steps)
    }

    /// Reads whether `attacker` playing `firstAtari` initiates a working ladder against `targetStone` (which currently has 2 liberties).
    static func readLadderAttackerToMove(
        state: GoBoardState,
        targetStone: BoardPoint,
        firstAtari: BoardPoint,
        maxDepth: Int = 36
    ) -> LadderResult {
        let targetIdx = state.index(row: targetStone.row, col: targetStone.col)
        guard let defender = state.stone(at: targetStone) else { return .unknown }
        let attacker = defender.opposite

        guard case .success(let out) = state.applying(action: .place(firstAtari), color: attacker) else {
            return .unknown
        }
        guard let afterGroup = out.nextState.groupAndLiberties(at: targetIdx) else {
            return .captured(steps: [firstAtari])
        }
        if afterGroup.liberties.count != 1 {
            return .escaped(steps: [firstAtari])
        }

        let sub = readLadderDefenderToMove(state: out.nextState, targetStone: targetStone, maxDepth: maxDepth)
        switch sub {
        case .captured(let rest):
            return .captured(steps: [firstAtari] + rest)
        case .escaped(let rest):
            return .escaped(steps: [firstAtari] + rest)
        case .unknown:
            return .unknown
        }
    }

    /// Returns true if defender escapes (reaches >= 3 liberties or captures an adjacent attacker stone).
    private static func searchDefenderEscape(
        state: GoBoardState,
        targetIdx: Int,
        defender: StoneColor,
        attacker: StoneColor,
        depth: Int,
        maxDepth: Int,
        nodesRemaining: inout Int,
        outSteps: inout [BoardPoint]
    ) -> Bool {
        guard depth < maxDepth, nodesRemaining > 0 else { return true }
        nodesRemaining -= 1
        guard let group = state.groupAndLiberties(at: targetIdx) else { return false }
        if group.liberties.count >= 3 { return true }
        if group.liberties.count == 0 { return false }

        // First check if defender can counter-capture any adjacent attacker group in atari!
        var checkedOpp: Set<Int> = []
        for s in group.stones {
            for n in state.neighbors(of: s) where state.grid[n] == attacker && !checkedOpp.contains(n) {
                if let oppG = state.groupAndLiberties(at: n) {
                    checkedOpp.formUnion(oppG.stones)
                    if oppG.liberties.count == 1, let capLib = oppG.liberties.first {
                        let capPt = state.point(for: capLib)
                        if case .success(let out) = state.applying(action: .place(capPt), color: defender) {
                            let newLibs = out.nextState.groupAndLiberties(at: targetIdx)?.liberties.count ?? 0
                            if newLibs >= 3 {
                                outSteps.append(capPt)
                                return true
                            }
                        }
                    }
                }
            }
        }

        // Standard ladder extension: play on the single remaining liberty
        guard group.liberties.count == 1, let escapeIdx = group.liberties.first else {
            return false
        }
        let escapePt = state.point(for: escapeIdx)
        guard case .success(let defOut) = state.applying(action: .place(escapePt), color: defender) else {
            return false
        }
        guard let defGroup = defOut.nextState.groupAndLiberties(at: targetIdx) else {
            return false
        }

        // If extending gave >= 3 liberties, defender broke out (e.g., hit a friendly ladder breaker)!
        if defGroup.liberties.count >= 3 {
            outSteps.append(escapePt)
            return true
        }
        // Self-atari (only 1 liberty left) -> attacker captures immediately!
        if defGroup.liberties.count == 1, let capIdx = defGroup.liberties.first {
            outSteps.append(escapePt)
            outSteps.append(defOut.nextState.point(for: capIdx))
            return false
        }

        // Defender now has 2 liberties; attacker tries both atari points to see if either keeps defender trapped.
        let atariCandidates = Array(defGroup.liberties).sorted { a, b in
            // Prefer the move closer to the center (standard ladder blocking move)
            let aPt = defOut.nextState.point(for: a)
            let bPt = defOut.nextState.point(for: b)
            let mid = defOut.nextState.size / 2
            let dA = abs(aPt.row - mid) + abs(aPt.col - mid)
            let dB = abs(bPt.row - mid) + abs(bPt.col - mid)
            return dA < dB
        }

        var bestFailSteps: [BoardPoint] = [escapePt]

        for attIdx in atariCandidates {
            let attPt = defOut.nextState.point(for: attIdx)
            guard case .success(let attOut) = defOut.nextState.applying(action: .place(attPt), color: attacker) else {
                continue
            }
            // Don't let attacker self-atari unless it immediately captures
            if attOut.capturedPoints.isEmpty {
                let attLibs = attOut.nextState.groupAndLiberties(at: attIdx)?.liberties.count ?? 0
                if attLibs <= 1 { continue }
            }

            var branchSteps: [BoardPoint] = [escapePt, attPt]
            let defEscapes = searchDefenderEscape(
                state: attOut.nextState,
                targetIdx: targetIdx,
                defender: defender,
                attacker: attacker,
                depth: depth + 2,
                maxDepth: maxDepth,
                nodesRemaining: &nodesRemaining,
                outSteps: &branchSteps
            )
            if !defEscapes {
                outSteps.append(contentsOf: branchSteps)
                return false // Attacker found a working ladder!
            } else if branchSteps.count > bestFailSteps.count {
                bestFailSteps = branchSteps
            }
        }

        outSteps.append(contentsOf: bestFailSteps)
        return true
    }

    // MARK: - 3x3 Shape Recognition & Opening / Joseki Heuristics

    /// Evaluates classic Go local shape quality (positive = good shape, negative = ugly/heavy shape).
    static func localShapeBonus(state: GoBoardState, point pt: BoardPoint, color: StoneColor) -> Double {
        let r = pt.row
        let c = pt.col
        let opp = color.opposite
        var bonus = 0.0

        func cell(_ dr: Int, _ dc: Int) -> StoneColor? {
            let nr = r + dr, nc = c + dc
            guard state.isValid(row: nr, col: nc) else { return nil }
            return state.grid[state.index(row: nr, col: nc)]
        }

        // 1. Empty Triangle Penalty (愚形三角): 3 friendly stones in a 2x2 L-shape with NO enemy stone at the diagonal corner
        let quads: [((Int, Int), (Int, Int), (Int, Int))] = [
            ((-1, 0), (0, -1), (-1, -1)),
            ((-1, 0), (0, 1), (-1, 1)),
            ((1, 0), (0, -1), (1, -1)),
            ((1, 0), (0, 1), (1, 1))
        ]
        for (o1, o2, d) in quads {
            if cell(o1.0, o1.1) == color && cell(o2.0, o2.1) == color && cell(d.0, d.1) == nil {
                bonus -= 9.0
            }
            // Hane around enemy stone (扳): friendly orthogonal + enemy orthogonal + enemy diagonal
            if cell(o1.0, o1.1) == color && cell(o2.0, o2.1) == opp && cell(d.0, d.1) == opp {
                bonus += 6.5
            }
            if cell(o2.0, o2.1) == color && cell(o1.0, o1.1) == opp && cell(d.0, d.1) == opp {
                bonus += 6.5
            }
        }

        // 2. Tiger's Mouth (虎口) formation: 2 diagonal friendly stones protecting a cut
        let diagPairs: [((Int, Int), (Int, Int), (Int, Int))] = [
            ((-1, -1), (-1, 1), (-1, 0)),
            ((1, -1), (1, 1), (1, 0)),
            ((-1, -1), (1, -1), (0, -1)),
            ((-1, 1), (1, 1), (0, 1))
        ]
        for (d1, d2, mid) in diagPairs {
            if cell(d1.0, d1.1) == color && cell(d2.0, d2.1) == color && cell(mid.0, mid.1) == nil {
                bonus += 7.0
            }
        }

        // 3. Bamboo Joint (双/竹节连接) completion
        if (cell(-1, 0) == color && cell(0, -1) == nil && cell(-1, -1) == nil && cell(0, -2) == color && cell(-1, -2) == color) ||
           (cell(1, 0) == color && cell(0, 1) == nil && cell(1, 1) == nil && cell(0, 2) == color && cell(1, 2) == color) {
            bonus += 5.0
        }

        // 4. Second-line endgame Hane (二路扳官子)
        let distRow = min(r, state.size - 1 - r)
        let distCol = min(c, state.size - 1 - c)
        if (distRow == 1 || distCol == 1) && state.moveCount > state.size * 2 {
            let hasFriendAdj = [(-1,0),(1,0),(0,-1),(0,1)].contains { cell($0.0, $0.1) == color }
            let hasOppAdj = [(-1,0),(1,0),(0,-1),(0,1)].contains { cell($0.0, $0.1) == opp }
            if hasFriendAdj && hasOppAdj {
                bonus += 7.5
            }
        }

        return bonus
    }

    /// Authentic Opening & Corner Joseki bonus points for 9x9, 13x13, and 19x19.
    static func openingBookBonus(state: GoBoardState, point pt: BoardPoint, color: StoneColor) -> Double {
        let s = state.size
        guard s >= 9, state.moveCount < (s == 9 ? 10 : (s == 13 ? 18 : 30)) else { return 0 }
        let opp = color.opposite
        var bonus = 0.0

        // Standard corners (3-4, 4-4, 3-3)
        let corners: [(Int, Int)] = [
            (0, 0), (0, s - 1), (s - 1, 0), (s - 1, s - 1)
        ]

        for (cr, cc) in corners {
            let dr = cr == 0 ? 1 : -1
            let dc = cc == 0 ? 1 : -1
            let hoshi = BoardPoint(row: cr + dr * (s >= 13 ? 3 : 2), col: cc + dc * (s >= 13 ? 3 : 2))
            let komoku1 = BoardPoint(row: cr + dr * (s >= 13 ? 2 : 2), col: cc + dc * (s >= 13 ? 3 : 2))
            let komoku2 = BoardPoint(row: cr + dr * (s >= 13 ? 3 : 2), col: cc + dc * (s >= 13 ? 2 : 2))
            let sanSan = BoardPoint(row: cr + dr * 2, col: cc + dc * 2)

            // Empty corner -> strongly prefer 4-4 or 3-4!
            let cornerOccupied = isCornerOccupied(state: state, cr: cr, cc: cc, dr: dr, dc: dc, span: s >= 13 ? 5 : 3)
            if !cornerOccupied {
                if pt == hoshi { bonus += 24.0 }
                else if s >= 13 && (pt == komoku1 || pt == komoku2) { bonus += 20.0 }
            } else if s >= 13 {
                // Classic 4-4 corner responses: Knight's approach (小飞挂) or 3-3 invasion (点三三)
                if state.stone(at: hoshi) == opp {
                    let approach1 = BoardPoint(row: cr + dr * 2, col: cc + dc * 5)
                    let approach2 = BoardPoint(row: cr + dr * 5, col: cc + dc * 2)
                    if pt == approach1 || pt == approach2 { bonus += 16.0 }
                    if pt == sanSan && state.moveCount >= 6 { bonus += 14.0 }
                } else if state.stone(at: hoshi) == color {
                    // Enclose corner (小飞守角) if opponent approached or corner is quiet
                    let enclose1 = BoardPoint(row: cr + dr * 2, col: cc + dc * 5)
                    let enclose2 = BoardPoint(row: cr + dr * 5, col: cc + dc * 2)
                    if pt == enclose1 || pt == enclose2 { bonus += 12.0 }
                }
            }
        }

        // On 9x9, Tengen (center) is a very strong opening move!
        if s == 9 && state.moveCount <= 2 && pt == BoardPoint(row: 4, col: 4) {
            bonus += 18.0
        }

        return bonus
    }

    private static func isCornerOccupied(state: GoBoardState, cr: Int, cc: Int, dr: Int, dc: Int, span: Int) -> Bool {
        for rStep in 0..<span {
            for cStep in 0..<span {
                let r = cr + dr * rStep
                let c = cc + dc * cStep
                if state.isValid(row: r, col: c), state.grid[state.index(row: r, col: c)] != nil {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Blunder-to-Personal-Puzzle Converter

    /// Converts a real game blunder into a playable `GoPuzzle` stored in the player's personal mistake book!
    static func makePersonalPuzzle(
        fromState stateBeforeMove: GoBoardState,
        reviewedMove: ReviewedMove,
        gameTitle: String
    ) -> GoPuzzle? {
        guard let bestVar = reviewedMove.topVariations.first else { return nil }
        let mover = reviewedMove.color
        let opp = mover.opposite
        let size = stateBeforeMove.size

        // Build SGF setup stones
        var abParts: [String] = []
        var awParts: [String] = []
        for r in 0..<size {
            for c in 0..<size {
                let pt = BoardPoint(row: r, col: c)
                if let s = stateBeforeMove.stone(at: pt) {
                    if s == .black { abParts.append("[\(pt.sgfCoordinate)]") }
                    else { awParts.append("[\(pt.sgfCoordinate)]") }
                }
            }
        }

        var sgf = "(;GM[1]FF[4]SZ[\(size)]PL[\(mover.sgfTag)]"
        if !abParts.isEmpty { sgf += "AB" + abParts.joined() }
        if !awParts.isEmpty { sgf += "AW" + awParts.joined() }

        // Correct branch: AI best move (up to 3 plies if PV exists)
        let pv = bestVar.pvMoves.isEmpty ? [bestVar.firstMove] : bestVar.pvMoves
        if pv.count >= 3 {
            sgf += "(;\(mover.sgfTag)[\(pv[0].sgfCoordinate)];\(opp.sgfTag)[\(pv[1].sgfCoordinate)];\(mover.sgfTag)[\(pv[2].sgfCoordinate)]C[CORRECT])"
        } else {
            sgf += "(;\(mover.sgfTag)[\(pv[0].sgfCoordinate)]C[CORRECT])"
        }

        // Wrong branch: the actual blunder played in the game
        if case .place(let blunderPt) = reviewedMove.playedAction, blunderPt != pv[0] {
            sgf += "(;\(mover.sgfTag)[\(blunderPt.sgfCoordinate)]C[WRONG])"
        }
        sgf += ")"

        // Compute tight crop region around the blunder & best move
        var focusPoints = [pv[0]]
        if case .place(let bp) = reviewedMove.playedAction { focusPoints.append(bp) }
        let minR = max(0, (focusPoints.map(\.row).min() ?? 0) - 3)
        let maxR = min(size - 1, (focusPoints.map(\.row).max() ?? size - 1) + 3)
        let minC = max(0, (focusPoints.map(\.col).min() ?? 0) - 3)
        let maxC = min(size - 1, (focusPoints.map(\.col).max() ?? size - 1) + 3)
        let crop = size <= 9 ? BoardCropRegion.full(size: size) : BoardCropRegion(minRow: minR, maxRow: maxR, minCol: minC, maxCol: maxC)

        let id = "my-blunder-\(UUID().uuidString.prefix(8))"
        let moveNum = reviewedMove.moveNumber
        let bestCoord = pv[0].humanLabel(boardSize: size)

        return GoPuzzle(
            id: id,
            category: .tactics,
            rankBadge: "实战复盘",
            titleZh: "实战恶手第 \(moveNum) 手 · \(gameTitle)",
            titleEn: "Game Blunder Move #\(moveNum)",
            promptZh: "复盘实战第 \(moveNum) 手：\(reviewedMove.diagnosisZh) 请找出更佳的一手！",
            promptEn: "Review Move #\(moveNum): \(reviewedMove.diagnosisEn) Find the stronger move!",
            hintZh: "AI 建议重点关注 \(bestCoord) 附近的攻防要点。",
            hintEn: "AI recommends focusing around \(bestCoord).",
            boardSize: size,
            playerColor: mover,
            sgf: sgf,
            cropRegion: crop
        )
    }
}
