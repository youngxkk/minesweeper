//
//  PuzzleModels.swift
//  StarYi Go
//

import Foundation

enum PuzzleCategory: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case capture
    case tactics
    case lifeAndDeath
    case capturingRace
    case opening
    case endgame

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .capture: return "puzzle.category.capture"
        case .tactics: return "puzzle.category.tactics"
        case .lifeAndDeath: return "puzzle.category.lifeAndDeath"
        case .capturingRace: return "puzzle.category.capturingRace"
        case .opening: return "puzzle.category.opening"
        case .endgame: return "puzzle.category.endgame"
        }
    }

    func displayTitle(isChinese: Bool) -> String {
        switch self {
        case .capture: return isChinese ? "吃子启蒙" : "Capture"
        case .tactics: return isChinese ? "经典手筋" : "Tesuji"
        case .lifeAndDeath: return isChinese ? "死活天地" : "Life & Death"
        case .capturingRace: return isChinese ? "对杀紧气" : "Capturing Race"
        case .opening: return isChinese ? "布局大场" : "Opening"
        case .endgame: return isChinese ? "实战收官" : "Endgame"
        }
    }

    var symbolName: String {
        switch self {
        case .capture: return "circle.grid.cross.fill"
        case .tactics: return "bolt.fill"
        case .lifeAndDeath: return "sparkles"
        case .capturingRace: return "flame.fill"
        case .opening: return "map.fill"
        case .endgame: return "flag.checkered"
        }
    }
}

/// Dihedral board symmetry (4 rotations x 2 reflections) + optional Black/White color swap
/// so kids genuinely read the position instead of memorizing corner coordinates!
struct PuzzleTransform: Hashable, Codable, Sendable {
    /// Quarter-turns clockwise: 0, 1, 2, 3
    let rotation: Int
    /// Horizontal mirror before rotation
    let mirrored: Bool
    /// Swaps Black <-> White stones and playerColor
    let swapColors: Bool

    static let identity = PuzzleTransform(rotation: 0, mirrored: false, swapColors: false)

    static func random(allowColorSwap: Bool = true) -> PuzzleTransform {
        PuzzleTransform(
            rotation: Int.random(in: 0..<4),
            mirrored: Bool.random(),
            swapColors: allowColorSwap ? Bool.random() : false
        )
    }

    var isIdentity: Bool {
        rotation % 4 == 0 && !mirrored && !swapColors
    }

    func apply(to pt: BoardPoint, boardSize n: Int) -> BoardPoint {
        var r = pt.row
        var c = mirrored ? (n - 1 - pt.col) : pt.col
        let rot = ((rotation % 4) + 4) % 4
        for _ in 0..<rot {
            let nr = c
            let nc = n - 1 - r
            r = nr
            c = nc
        }
        return BoardPoint(row: r, col: c)
    }

    func apply(to region: BoardCropRegion, boardSize n: Int) -> BoardCropRegion {
        let corners = [
            BoardPoint(row: region.minRow, col: region.minCol),
            BoardPoint(row: region.minRow, col: region.maxCol),
            BoardPoint(row: region.maxRow, col: region.minCol),
            BoardPoint(row: region.maxRow, col: region.maxCol)
        ].map { apply(to: $0, boardSize: n) }

        let minR = corners.map(\.row).min() ?? 0
        let maxR = corners.map(\.row).max() ?? (n - 1)
        let minC = corners.map(\.col).min() ?? 0
        let maxC = corners.map(\.col).max() ?? (n - 1)
        return BoardCropRegion(minRow: minR, maxRow: maxR, minCol: minC, maxCol: maxC)
    }

    func apply(to color: StoneColor) -> StoneColor {
        swapColors ? color.opposite : color
    }

    /// Recursively transforms an entire parsed SGF game tree into the rotated/mirrored/color-swapped frame.
    func apply(to node: SGFNode, boardSize n: Int) -> SGFNode {
        var newProps: [String: [String]] = [:]
        for (key, vals) in node.properties {
            switch key {
            case "AB", "AW":
                let targetKey = swapColors ? (key == "AB" ? "AW" : "AB") : key
                let transformed = vals.map { raw -> String in
                    if let pt = BoardPoint(sgf: raw) {
                        return apply(to: pt, boardSize: n).sgfCoordinate
                    }
                    return raw
                }
                newProps[targetKey, default: []].append(contentsOf: transformed)
            case "B", "W":
                let targetKey = swapColors ? (key == "B" ? "W" : "B") : key
                let transformed = vals.map { raw -> String in
                    if raw.isEmpty || raw == "tt" { return raw }
                    if let pt = BoardPoint(sgf: raw) {
                        return apply(to: pt, boardSize: n).sgfCoordinate
                    }
                    return raw
                }
                newProps[targetKey, default: []].append(contentsOf: transformed)
            case "PL":
                let transformed = vals.map { raw -> String in
                    guard swapColors else { return raw }
                    if raw.uppercased() == "B" { return "W" }
                    if raw.uppercased() == "W" { return "B" }
                    return raw
                }
                newProps[key] = transformed
            default:
                newProps[key] = vals
            }
        }
        let newChildren = node.children.map { apply(to: $0, boardSize: n) }
        return SGFNode(properties: newProps, children: newChildren)
    }
}

/// Spaced-repetition (SRS) mistake item for long-term Go tsumego retention (1d -> 3d -> 7d -> Mastered).
struct SRSMistakeItem: Codable, Hashable, Identifiable, Sendable {
    var id: String { puzzleId }
    let puzzleId: String
    var nextReviewDate: Date
    var intervalDays: Int
    var correctStreak: Int

    var isDueNow: Bool {
        nextReviewDate <= Date()
    }

    static func initial(puzzleId: String, now: Date = Date()) -> SRSMistakeItem {
        SRSMistakeItem(puzzleId: puzzleId, nextReviewDate: now, intervalDays: 1, correctStreak: 0)
    }

    /// Advances review schedule: 1 day -> 3 days -> returns nil when Mastered (3 consecutive passes).
    func advancingOnCorrect(now: Date = Date()) -> SRSMistakeItem? {
        let nextStreak = correctStreak + 1
        if nextStreak >= 3 {
            return nil // Graduated from SRS mistake book!
        }
        let nextDays = nextStreak == 1 ? 1 : 3
        let nextDate = Calendar.current.date(byAdding: .day, value: nextDays, to: now) ?? now.addingTimeInterval(Double(nextDays) * 86400)
        return SRSMistakeItem(
            puzzleId: puzzleId,
            nextReviewDate: nextDate,
            intervalDays: nextDays,
            correctStreak: nextStreak
        )
    }
}

struct GoPuzzle: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let category: PuzzleCategory
    let rankBadge: String
    let titleZh: String
    let titleEn: String
    let promptZh: String
    let promptEn: String
    let hintZh: String
    let hintEn: String
    let boardSize: Int
    let playerColor: StoneColor
    let sgf: String
    let cropRegion: BoardCropRegion

    func title(_ l10n: L10n) -> String {
        l10n.bilingual(zh: titleZh, en: titleEn)
    }

    func prompt(_ l10n: L10n, activeColor: StoneColor? = nil) -> String {
        let raw = l10n.bilingual(zh: promptZh, en: promptEn)
        guard let activeColor, activeColor != playerColor else { return raw }
        // Bidirectional color wording swap for both Black-to-play and White-to-play puzzles.
        if l10n.language.isChinese {
            return raw
                .replacingOccurrences(of: "黑先", with: "__TMP_B1__")
                .replacingOccurrences(of: "白先", with: "黑先")
                .replacingOccurrences(of: "__TMP_B1__", with: "白先")
                .replacingOccurrences(of: "黑棋", with: "__TMP_B__")
                .replacingOccurrences(of: "黑子", with: "__TMP_BS__")
                .replacingOccurrences(of: "白棋", with: "黑棋")
                .replacingOccurrences(of: "白子", with: "黑子")
                .replacingOccurrences(of: "__TMP_B__", with: "白棋")
                .replacingOccurrences(of: "__TMP_BS__", with: "白子")
        } else {
            return raw
                .replacingOccurrences(of: "Black", with: "__TMP_B__")
                .replacingOccurrences(of: "black", with: "__TMP_b__")
                .replacingOccurrences(of: "White", with: "Black")
                .replacingOccurrences(of: "white", with: "black")
                .replacingOccurrences(of: "__TMP_B__", with: "White")
                .replacingOccurrences(of: "__TMP_b__", with: "white")
        }
    }

    func hint(_ l10n: L10n) -> String {
        l10n.bilingual(zh: hintZh, en: hintEn)
    }

    /// Parses the SGF root and constructs the initial `GoBoardState`, optionally applying a `PuzzleTransform`.
    func initialBoardState(transform: PuzzleTransform = .identity) -> GoBoardState {
        let activeColor = transform.apply(to: playerColor)
        var state = GoBoardState(size: boardSize, komi: 0, handicap: 0, startingTurn: activeColor)
        if let rawRoot = SGFParser.parse(sgf) {
            let root = transform.isIdentity ? rawRoot : transform.apply(to: rawRoot, boardSize: boardSize)
            for pt in root.addedBlackPoints {
                state.setSetupStone(.black, at: pt)
            }
            for pt in root.addedWhitePoints {
                state.setSetupStone(.white, at: pt)
            }
            state.resetPositionHistoryToCurrent()
        }
        return state
    }

    /// Parses SGF root with an optional symmetry / color-swap transform.
    func parsedRoot(transform: PuzzleTransform = .identity) -> SGFNode? {
        guard let rawRoot = SGFParser.parse(sgf) else { return nil }
        return transform.isIdentity ? rawRoot : transform.apply(to: rawRoot, boardSize: boardSize)
    }

    /// Numeric rank ordering helper (30K -> 30, 1K -> 1, 1D -> 0, 3D -> -2) for Dojo sorting & filtering.
    var rankOrderValue: Int {
        let upper = rankBadge.uppercased()
        if upper.hasSuffix("K"), let n = Int(upper.dropLast()) {
            return n
        }
        if upper.hasSuffix("D"), let n = Int(upper.dropLast()) {
            return 1 - n
        }
        return 15
    }

    /// Finds the first correct move from a given SGF node (for Hint display).
    static func firstCorrectMove(from node: SGFNode) -> BoardPoint? {
        for child in node.children {
            if isCorrectBranch(child), let move = child.move, case .place(let pt) = move.action {
                return pt
            }
        }
        return nil
    }

    /// Extracts the main correct Principal Variation move sequence from a node (for "Show Solution" playback!).
    static func solutionLine(from node: SGFNode) -> [(color: StoneColor, point: BoardPoint)] {
        var line: [(StoneColor, BoardPoint)] = []
        var cur = node
        while let correctChild = cur.children.first(where: { isCorrectBranch($0) }) {
            if let mv = correctChild.move, case .place(let pt) = mv.action {
                line.append((mv.color, pt))
            }
            if let c = correctChild.comment?.uppercased(), c.contains("CORRECT") {
                break
            }
            cur = correctChild
        }
        return line
    }

    /// Returns true if `node` or any descendant is marked `CORRECT`.
    static func isCorrectBranch(_ node: SGFNode) -> Bool {
        if let c = node.comment?.uppercased(), c.contains("CORRECT") {
            return true
        }
        return node.children.contains { isCorrectBranch($0) }
    }
}
