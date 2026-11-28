//
//  GoBoardState.swift
//  StarYi Go
//

import Foundation

/// Deterministic Zobrist hashing table for fast positional Ko / Superko checks.
final class ZobristTable: @unchecked Sendable {
    static let shared = ZobristTable()

    // Max board size 19x19 = 361 intersections, 2 colors (black=0, white=1)
    private let table: [UInt64]

    private init() {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        func nextRandom() -> UInt64 {
            // SplitMix64 deterministic PRNG
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        var values: [UInt64] = []
        values.reserveCapacity(19 * 19 * 2)
        for _ in 0..<(19 * 19 * 2) {
            values.append(nextRandom())
        }
        self.table = values
    }

    @inline(__always)
    func hash(index: Int, color: StoneColor) -> UInt64 {
        let colorOffset = (color == .black) ? 0 : 1
        let slot = index * 2 + colorOffset
        guard slot >= 0 && slot < table.count else { return 0 }
        return table[slot]
    }
}

struct MoveOutcome: Sendable {
    let nextState: GoBoardState
    let capturedPoints: [BoardPoint]
}

/// Pure-Swift value-type Go board state implementing full Go rules:
/// captures, suicide prevention, simple Ko & positional Superko, handicap setup, and pass tracking.
struct GoBoardState: Hashable, Sendable {
    let size: Int
    var grid: [StoneColor?]
    var currentTurn: StoneColor
    var blackCaptures: Int
    var whiteCaptures: Int
    var koIndex: Int?
    var lastMove: MoveAction?
    /// Most recent 5 moves (newest last) for neural-net history planes (t-1 .. t-5).
    var recentMoves: [MoveAction] = []
    var moveCount: Int
    var consecutivePasses: Int
    var boardHash: UInt64
    var positionHistory: Set<UInt64>
    var komi: Double
    var handicap: Int

    init(
        size: Int = 13,
        komi: Double? = nil,
        handicap: Int = 0,
        startingTurn: StoneColor? = nil
    ) {
        self.size = size
        self.grid = Array(repeating: nil, count: size * size)
        self.blackCaptures = 0
        self.whiteCaptures = 0
        self.koIndex = nil
        self.lastMove = nil
        self.recentMoves = []
        self.moveCount = 0
        self.consecutivePasses = 0
        self.boardHash = 0
        self.handicap = max(0, handicap)
        let defaultKomi = BoardSize(rawValue: size)?.defaultKomi ?? 6.5
        self.komi = komi ?? (self.handicap >= 2 ? 0.5 : defaultKomi)
        self.currentTurn = startingTurn ?? (self.handicap >= 2 ? .white : .black)
        self.positionHistory = []

        if self.handicap >= 2 {
            for point in Self.handicapPoints(size: size, count: self.handicap) {
                setSetupStone(.black, at: point)
            }
        }
        self.positionHistory.insert(self.boardHash)
    }

    @inline(__always)
    func index(row: Int, col: Int) -> Int {
        row * size + col
    }

    @inline(__always)
    func point(for index: Int) -> BoardPoint {
        BoardPoint(row: index / size, col: index % size)
    }

    @inline(__always)
    func isValid(row: Int, col: Int) -> Bool {
        row >= 0 && row < size && col >= 0 && col < size
    }

    @inline(__always)
    func stone(at point: BoardPoint) -> StoneColor? {
        guard isValid(row: point.row, col: point.col) else { return nil }
        return grid[index(row: point.row, col: point.col)]
    }

    mutating func setSetupStone(_ color: StoneColor?, at point: BoardPoint) {
        guard isValid(row: point.row, col: point.col) else { return }
        let idx = index(row: point.row, col: point.col)
        if let existing = grid[idx] {
            boardHash ^= ZobristTable.shared.hash(index: idx, color: existing)
        }
        grid[idx] = color
        if let newColor = color {
            boardHash ^= ZobristTable.shared.hash(index: idx, color: newColor)
        }
    }

    mutating func resetPositionHistoryToCurrent() {
        positionHistory = [boardHash]
    }

    @inline(__always)
    func neighbors(of idx: Int) -> [Int] {
        let r = idx / size
        let c = idx % size
        var result: [Int] = []
        result.reserveCapacity(4)
        if r > 0 { result.append(idx - size) }
        if r < size - 1 { result.append(idx + size) }
        if c > 0 { result.append(idx - 1) }
        if c < size - 1 { result.append(idx + 1) }
        return result
    }

    /// Returns the connected stone group and its empty-point liberties starting from `idx`.
    func groupAndLiberties(at idx: Int) -> GoGroup? {
        guard let color = grid[idx] else { return nil }
        var stones: Set<Int> = [idx]
        var liberties: Set<Int> = []
        var stack: [Int] = [idx]
        stack.reserveCapacity(16)

        while let current = stack.popLast() {
            let r = current / size
            let c = current % size

            if r > 0 {
                let n = current - size
                if grid[n] == color {
                    if stones.insert(n).inserted { stack.append(n) }
                } else if grid[n] == nil {
                    liberties.insert(n)
                }
            }
            if r < size - 1 {
                let n = current + size
                if grid[n] == color {
                    if stones.insert(n).inserted { stack.append(n) }
                } else if grid[n] == nil {
                    liberties.insert(n)
                }
            }
            if c > 0 {
                let n = current - 1
                if grid[n] == color {
                    if stones.insert(n).inserted { stack.append(n) }
                } else if grid[n] == nil {
                    liberties.insert(n)
                }
            }
            if c < size - 1 {
                let n = current + 1
                if grid[n] == color {
                    if stones.insert(n).inserted { stack.append(n) }
                } else if grid[n] == nil {
                    liberties.insert(n)
                }
            }
        }
        return GoGroup(color: color, stones: stones, liberties: liberties)
    }

    func allGroups() -> [GoGroup] {
        var visited = Array(repeating: false, count: size * size)
        var groups: [GoGroup] = []
        for idx in 0..<(size * size) {
            guard !visited[idx], grid[idx] != nil else { continue }
            if let group = groupAndLiberties(at: idx) {
                for s in group.stones { visited[s] = true }
                groups.append(group)
            }
        }
        return groups
    }

    /// Returns all intersections occupied by stones that currently have exactly 1 liberty (Atari).
    func atariPoints() -> Set<BoardPoint> {
        var result: Set<BoardPoint> = []
        for group in allGroups() where group.liberties.count == 1 {
            for idx in group.stones {
                result.insert(point(for: idx))
            }
        }
        return result
    }

    /// Returns the forbidden Ko intersection as a `BoardPoint`, if active.
    var koPoint: BoardPoint? {
        guard let koIndex else { return nil }
        return point(for: koIndex)
    }

    /// Detects whether an empty intersection is a solid single-point true eye for `color`.
    /// Checks all orthogonal neighbors are `color` AND diagonal control rules (preventing false eyes).
    func isTrueEye(index idx: Int, for color: StoneColor) -> Bool {
        guard grid[idx] == nil else { return false }
        let r = idx / size
        let c = idx % size

        for n in neighbors(of: idx) {
            if grid[n] != color {
                return false
            }
        }

        let opponent = color.opposite
        var opponentDiags = 0
        var totalDiags = 0
        for (dr, dc) in [(-1, -1), (-1, 1), (1, -1), (1, 1)] {
            let nr = r + dr
            let nc = c + dc
            if isValid(row: nr, col: nc) {
                totalDiags += 1
                if grid[index(row: nr, col: nc)] == opponent {
                    opponentDiags += 1
                }
            }
        }
        // On corner/edge (totalDiags < 4), ANY opponent diagonal makes it a false eye.
        // In the center (totalDiags == 4), 2+ opponent diagonals make it a false eye.
        if totalDiags < 4 {
            return opponentDiags == 0
        }
        return opponentDiags <= 1
    }

    /// Detects whether an empty intersection surrounded orthogonally by `color` is actually a False Eye (假眼).
    func isFalseEye(index idx: Int, for color: StoneColor) -> Bool {
        guard grid[idx] == nil else { return false }
        for n in neighbors(of: idx) {
            if grid[n] != color { return false }
        }
        return !isTrueEye(index: idx, for: color)
    }

    /// Returns true ONLY when playing `idx` would pointlessly fill our own true eye without capturing
    /// or saving a group in atari. Allows tactical throw-ins, snapbacks, and capturing moves!
    func isPointlessSelfEyeFill(index idx: Int, for color: StoneColor) -> Bool {
        guard isTrueEye(index: idx, for: color) else { return false }
        // Check if any adjacent friendly group is in atari (only 1 liberty = this eye -> filling would be suicide anyway,
        // unless it connects multiple groups, wait: all orthogonal neighbors are `color`, so filling can't capture opponent!)
        var distinctGroups: Set<Int> = []
        var minLibs = Int.max
        for n in neighbors(of: idx) {
            if let g = groupAndLiberties(at: n) {
                let rep = g.stones.min() ?? n
                distinctGroups.insert(rep)
                minLibs = min(minLibs, g.liberties.count)
            }
        }
        // If all adjacent stones already belong to the same healthy group (libs >= 2), filling our own eye is pointless.
        if distinctGroups.count == 1 && minLibs >= 2 {
            return true
        }
        // Even if multiple groups touch this true eye, if none are in atari and no opponent threatens a cut, don't fill.
        return minLibs >= 3
    }

    /// Checks whether an enclosed single eye space of 4+ points is unconditionally alive
    /// (excludes dead 1-vital-point shapes: Square Four, Pyramid Four, Bulky Five, Crossed Five, and Rabbity Six).
    private func isUnconditionallyAliveSingleEye(_ regionIndices: [Int]) -> Bool {
        let count = regionIndices.count
        guard count >= 4 else { return false }
        if count >= 7 { return true }

        let regionSet = Set(regionIndices)
        var maxDeg = 0
        var deg3Count = 0
        var has2x2 = false

        for idx in regionIndices {
            let r = idx / size
            let c = idx % size
            var deg = 0
            for n in neighbors(of: idx) where regionSet.contains(n) {
                deg += 1
            }
            if deg > maxDeg { maxDeg = deg }
            if deg == 3 { deg3Count += 1 }
            if !has2x2 && r + 1 < size && c + 1 < size {
                if regionSet.contains(index(row: r, col: c + 1)) &&
                   regionSet.contains(index(row: r + 1, col: c)) &&
                   regionSet.contains(index(row: r + 1, col: c + 1)) {
                    has2x2 = true
                }
            }
        }

        switch count {
        case 4:
            // Alive: Straight-4 / Bent-4 (no 2x2 Square-4, no degree-3 Pyramid-4)
            return !has2x2 && maxDeg <= 2
        case 5:
            // Alive: excludes Bulky-5 (has 2x2) and Crossed-5 (maxDeg == 4)
            return !has2x2 && maxDeg <= 3
        case 6:
            // Alive: excludes Rabbity-6 (has 2x2 with a single degree-3 vital point; 2x3 rectangle has 2 deg-3 points)
            if has2x2 && deg3Count <= 1 {
                return false
            }
            return true
        default:
            return true
        }
    }

    /// Returns eye points and stone indices belonging to unconditionally alive groups:
    /// - 2+ distinct enclosed true eye regions (single-point or multi-point eye spaces), OR
    /// - a single enclosed eye space of >= 4 points that is not a dead Square Four (e.g., Straight/Bent Four, 5+ space).
    /// Used both for visual celebration ("两眼活棋") and accurate endgame/AI evaluation!
    func twoEyeAliveAnalysis() -> (eyePoints: Set<BoardPoint>, aliveStoneIndices: Set<Int>) {
        let total = size * size
        let groups = allGroups()
        var groupIndexAt = Array(repeating: -1, count: total)
        for (gIdx, g) in groups.enumerated() {
            for s in g.stones { groupIndexAt[s] = gIdx }
        }

        // Flood-fill all empty regions enclosed exclusively by one color
        var visitedEmpty = Array(repeating: false, count: total)
        var eyeRegionsByGroup: [Int: [[Int]]] = [:]

        for idx in 0..<total where grid[idx] == nil && !visitedEmpty[idx] {
            var region: [Int] = [idx]
            var stack: [Int] = [idx]
            visitedEmpty[idx] = true
            var touchesBlack = false
            var touchesWhite = false
            var touchingGroups: Set<Int> = []

            while let cur = stack.popLast() {
                for n in neighbors(of: cur) {
                    if let s = grid[n] {
                        if s == .black { touchesBlack = true } else { touchesWhite = true }
                        let gIdx = groupIndexAt[n]
                        if gIdx >= 0 { touchingGroups.insert(gIdx) }
                    } else if !visitedEmpty[n] {
                        visitedEmpty[n] = true
                        region.append(n)
                        stack.append(n)
                    }
                }
            }

            // Must be strictly enclosed by ONE color and not huge open empty board
            guard touchesBlack != touchesWhite else { continue }
            let owner: StoneColor = touchesBlack ? .black : .white
            guard region.count <= max(8, total / 4) else { continue }

            // Single-point enclosed region must pass true-eye diagonal check
            if region.count == 1 {
                guard isTrueEye(index: region[0], for: owner) else { continue }
            }

            // Attribute this eye region to its enclosing group(s)
            // If all boundary stones of the eye belong to a single connected group, it's a guaranteed eye for that group!
            if touchingGroups.count == 1, let gIdx = touchingGroups.first {
                eyeRegionsByGroup[gIdx, default: []].append(region)
            } else if region.count == 1 {
                // Single-point true eye shared by friendly groups whose diagonals are solidly controlled
                for gIdx in touchingGroups {
                    eyeRegionsByGroup[gIdx, default: []].append(region)
                }
            }
        }

        var eyePoints: Set<BoardPoint> = []
        var aliveStones: Set<Int> = []

        for (gIdx, regions) in eyeRegionsByGroup {
            let group = groups[gIdx]
            let hasTwoDistinctEyes = regions.count >= 2
            let hasBigLivingEye = regions.contains { reg in
                isUnconditionallyAliveSingleEye(reg)
            }

            if hasTwoDistinctEyes || hasBigLivingEye {
                aliveStones.formUnion(group.stones)
                for reg in regions {
                    if reg.count <= 2 {
                        for e in reg { eyePoints.insert(point(for: e)) }
                    } else if let rep = reg.first {
                        eyePoints.insert(point(for: rep))
                        if let last = reg.last, last != rep {
                            eyePoints.insert(point(for: last))
                        }
                    }
                }
            }
        }

        return (eyePoints, aliveStones)
    }

    var isDoublePassEnded: Bool {
        consecutivePasses >= 2
    }

    /// Applies a move (or pass) and enforces all standard Go rules.
    func applying(action: MoveAction, color: StoneColor? = nil) -> Result<MoveOutcome, MoveError> {
        let mover = color ?? currentTurn
        switch action {
        case .resign:
            return .success(MoveOutcome(nextState: self, capturedPoints: []))

        case .pass:
            var next = self
            next.currentTurn = mover.opposite
            next.koIndex = nil
            next.lastMove = .pass
            next.appendRecentMove(.pass)
            next.moveCount += 1
            next.consecutivePasses += 1
            return .success(MoveOutcome(nextState: next, capturedPoints: []))

        case .place(let pt):
            guard isValid(row: pt.row, col: pt.col) else {
                return .failure(.outOfBounds)
            }
            let idx = index(row: pt.row, col: pt.col)
            guard grid[idx] == nil else {
                return .failure(.occupied)
            }
            if koIndex == idx {
                return .failure(.koViolation)
            }

            var next = self
            next.grid[idx] = mover
            next.boardHash ^= ZobristTable.shared.hash(index: idx, color: mover)

            let opponent = mover.opposite
            var capturedIndices: [Int] = []
            var checkedOpponent: Set<Int> = []

            for n in next.neighbors(of: idx) {
                if next.grid[n] == opponent, !checkedOpponent.contains(n) {
                    if let oppGroup = next.groupAndLiberties(at: n) {
                        checkedOpponent.formUnion(oppGroup.stones)
                        if oppGroup.liberties.isEmpty {
                            for stoneIdx in oppGroup.stones {
                                next.grid[stoneIdx] = nil
                                next.boardHash ^= ZobristTable.shared.hash(index: stoneIdx, color: opponent)
                                capturedIndices.append(stoneIdx)
                            }
                        }
                    }
                }
            }

            // Check suicide: allowed only if we captured at least 1 opponent stone OR our group has liberties.
            guard let ownGroup = next.groupAndLiberties(at: idx), !ownGroup.liberties.isEmpty else {
                return .failure(.suicide)
            }

            // Positional Superko check
            if next.positionHistory.contains(next.boardHash) {
                return .failure(.koViolation)
            }

            // Simple Ko detection: single stone captured by a single-stone group with 1 liberty
            if capturedIndices.count == 1 && ownGroup.stones.count == 1 && ownGroup.liberties.count == 1 {
                next.koIndex = capturedIndices[0]
            } else {
                next.koIndex = nil
            }

            if mover == .black {
                next.blackCaptures += capturedIndices.count
            } else {
                next.whiteCaptures += capturedIndices.count
            }

            next.currentTurn = opponent
            next.lastMove = .place(pt)
            next.appendRecentMove(.place(pt))
            next.moveCount += 1
            next.consecutivePasses = 0
            next.positionHistory.insert(next.boardHash)

            let capturedPoints = capturedIndices.map { next.point(for: $0) }
            return .success(MoveOutcome(nextState: next, capturedPoints: capturedPoints))
        }
    }

    private mutating func appendRecentMove(_ action: MoveAction) {
        recentMoves.append(action)
        if recentMoves.count > 5 {
            recentMoves.removeFirst(recentMoves.count - 5)
        }
    }

    /// Fast, allocation-free legality check for the common non-capturing case;
    /// falls back to full `applying` only when an adjacent opponent group is in atari.
    func isLegal(point pt: BoardPoint, for color: StoneColor? = nil) -> Bool {
        guard isValid(row: pt.row, col: pt.col) else { return false }
        let idx = index(row: pt.row, col: pt.col)
        guard grid[idx] == nil else { return false }
        if let ko = koIndex, ko == idx { return false }

        let mover = color ?? currentTurn
        let opponent = mover.opposite
        let adj = neighbors(of: idx)

        var hasEmptyNeighbor = false
        var hasSafeFriendlyNeighbor = false
        var mightCaptureOpponent = false

        for n in adj {
            guard let stone = grid[n] else {
                hasEmptyNeighbor = true
                continue
            }
            if stone == opponent {
                // If an adjacent opponent group has only 1 liberty (this point), placing captures it.
                if groupHasExactlyOneLiberty(at: n, expectedLiberty: idx) {
                    mightCaptureOpponent = true
                    break
                }
            } else if !hasSafeFriendlyNeighbor {
                if !groupHasExactlyOneLiberty(at: n, expectedLiberty: idx) {
                    hasSafeFriendlyNeighbor = true
                }
            }
        }

        if mightCaptureOpponent {
            if case .success = applying(action: .place(pt), color: mover) {
                return true
            }
            return false
        }

        // Non-capturing move: must have an empty neighbor or join a friendly group with >= 2 liberties.
        guard hasEmptyNeighbor || hasSafeFriendlyNeighbor else { return false }
        let candidateHash = boardHash ^ ZobristTable.shared.hash(index: idx, color: mover)
        return !positionHistory.contains(candidateHash)
    }

    /// Returns true if the chain containing `startIdx` has no liberty other than `expectedLiberty`.
    private func groupHasExactlyOneLiberty(at startIdx: Int, expectedLiberty: Int) -> Bool {
        guard let color = grid[startIdx] else { return false }
        var visited = Set<Int>()
        visited.insert(startIdx)
        var stack: [Int] = [startIdx]

        while let cur = stack.popLast() {
            for n in neighbors(of: cur) {
                if grid[n] == nil {
                    if n != expectedLiberty {
                        return false // Found a second liberty!
                    }
                } else if grid[n] == color && visited.insert(n).inserted {
                    stack.append(n)
                }
            }
        }
        return true
    }

    func legalMovePoints(for color: StoneColor? = nil) -> [BoardPoint] {
        let mover = color ?? currentTurn
        var result: [BoardPoint] = []
        result.reserveCapacity(size * size / 2)
        for idx in 0..<(size * size) where grid[idx] == nil && idx != koIndex {
            let pt = point(for: idx)
            if isLegal(point: pt, for: mover) {
                result.append(pt)
            }
        }
        return result
    }

    /// Standard Go handicap stone placements for 7x7, 9x9, 13x13, and 19x19 boards.
    static func handicapPoints(size: Int, count: Int) -> [BoardPoint] {
        guard count >= 2, size >= 7 else { return [] }
        let lo = (size <= 9) ? 2 : 3
        let hi = size - 1 - lo
        let mid = size / 2

        let tr = BoardPoint(row: lo, col: hi)
        let bl = BoardPoint(row: hi, col: lo)
        let br = BoardPoint(row: hi, col: hi)
        let tl = BoardPoint(row: lo, col: lo)
        let center = BoardPoint(row: mid, col: mid)
        let left = BoardPoint(row: mid, col: lo)
        let right = BoardPoint(row: mid, col: hi)
        let top = BoardPoint(row: lo, col: mid)
        let bottom = BoardPoint(row: hi, col: mid)

        let maxCount = BoardSize(rawValue: size)?.maxHandicap ?? (size == 9 ? 4 : (size == 13 ? 5 : 9))
        switch min(count, maxCount) {
        case 2: return [tr, bl]
        case 3: return [tr, bl, br]
        case 4: return [tr, bl, br, tl]
        case 5: return [tr, bl, br, tl, center]
        case 6: return [tr, bl, br, tl, left, right]
        case 7: return [tr, bl, br, tl, left, right, center]
        case 8: return [tr, bl, br, tl, left, right, top, bottom]
        case 9: return [tr, bl, br, tl, left, right, top, bottom, center]
        default: return []
        }
    }
}
