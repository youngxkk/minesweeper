//
//  SGFParser.swift
//  StarYi Go
//

import Foundation

/// A node in an SGF game tree (supports main line + arbitrary variation branches).
final class SGFNode: Sendable {
    let properties: [String: [String]]
    let children: [SGFNode]

    init(properties: [String: [String]], children: [SGFNode] = []) {
        self.properties = properties
        self.children = children
    }

    func value(for key: String) -> String? {
        properties[key]?.first
    }

    func values(for key: String) -> [String] {
        properties[key] ?? []
    }

    var comment: String? {
        value(for: "C")
    }

    var move: (color: StoneColor, action: MoveAction)? {
        if let raw = value(for: "B") {
            if raw.isEmpty || raw == "tt" {
                return (.black, .pass)
            }
            if let pt = BoardPoint(sgf: raw) {
                return (.black, .place(pt))
            }
        }
        if let raw = value(for: "W") {
            if raw.isEmpty || raw == "tt" {
                return (.white, .pass)
            }
            if let pt = BoardPoint(sgf: raw) {
                return (.white, .place(pt))
            }
        }
        return nil
    }

    var addedBlackPoints: [BoardPoint] {
        Self.expandPointList(values(for: "AB"))
    }

    var addedWhitePoints: [BoardPoint] {
        Self.expandPointList(values(for: "AW"))
    }

    var addedEmptyPoints: [BoardPoint] {
        Self.expandPointList(values(for: "AE"))
    }

    /// Expands FF[4] point lists including compressed rectangles (`aa:cc`).
    private static func expandPointList(_ rawValues: [String]) -> [BoardPoint] {
        var result: [BoardPoint] = []
        for raw in rawValues {
            if raw.count == 5, raw[raw.index(raw.startIndex, offsetBy: 2)] == ":" {
                let lhs = String(raw.prefix(2))
                let rhs = String(raw.suffix(2))
                if let p1 = BoardPoint(sgf: lhs), let p2 = BoardPoint(sgf: rhs) {
                    let rLo = min(p1.row, p2.row), rHi = max(p1.row, p2.row)
                    let cLo = min(p1.col, p2.col), cHi = max(p1.col, p2.col)
                    for r in rLo...rHi {
                        for c in cLo...cHi {
                            result.append(BoardPoint(row: r, col: c))
                        }
                    }
                    continue
                }
            }
            if let pt = BoardPoint(sgf: raw) {
                result.append(pt)
            }
        }
        return result
    }

    var isMarkedCorrect: Bool {
        let c = (comment ?? "").uppercased()
        return c.contains("CORRECT") || c.contains("RIGHT")
    }

    var isMarkedWrong: Bool {
        let c = (comment ?? "").uppercased()
        return c.contains("WRONG")
    }

    var containsCorrectLeaf: Bool {
        var stack: [SGFNode] = [self]
        while let node = stack.popLast() {
            if node.isMarkedCorrect { return true }
            stack.append(contentsOf: node.children)
        }
        return false
    }

    var boardSize: Int {
        guard let raw = value(for: "SZ") else { return 19 }
        let first = raw.split(separator: ":").first.map(String.init) ?? raw
        return Int(first) ?? 19
    }

    var komi: Double? {
        Double(value(for: "KM") ?? "")
    }

    var startingPlayer: StoneColor? {
        guard let pl = value(for: "PL")?.uppercased() else { return nil }
        if pl == "B" { return .black }
        if pl == "W" { return .white }
        return nil
    }

    func initialBoard(size: Int, komi: Double, handicap: Int) -> GoBoardState {
        let black = addedBlackPoints
        let white = addedWhitePoints
        let hasSetup = !black.isEmpty || !white.isEmpty
        var board = GoBoardState(
            size: size, komi: komi, handicap: hasSetup ? 0 : handicap,
            startingTurn: startingPlayer ?? (handicap >= 2 ? .white : .black)
        )
        board.handicap = handicap
        for pt in black { board.setSetupStone(.black, at: pt) }
        for pt in white { board.setSetupStone(.white, at: pt) }
        for pt in addedEmptyPoints { board.setSetupStone(nil, at: pt) }
        board.resetPositionHistoryToCurrent()
        return board
    }
}

enum SGFParser {
    /// Parses a standard FF[4] SGF string into its root `SGFNode`.
    static func parse(_ input: String) -> SGFNode? {
        let chars = Array(input)
        var cursor = 0

        func skipWhitespace() {
            while cursor < chars.count && chars[cursor].isWhitespace {
                cursor += 1
            }
        }

        func parseValue() -> String {
            // Assumes chars[cursor] == "["
            cursor += 1
            var result = ""
            while cursor < chars.count {
                let ch = chars[cursor]
                if ch == "\\" && cursor + 1 < chars.count {
                    cursor += 1
                    result.append(chars[cursor])
                    cursor += 1
                } else if ch == "]" {
                    cursor += 1
                    break
                } else {
                    result.append(ch)
                    cursor += 1
                }
            }
            return result
        }

        func parseNodeProperties() -> [String: [String]] {
            var props: [String: [String]] = [:]
            while cursor < chars.count {
                skipWhitespace()
                guard cursor < chars.count else { break }
                let ch = chars[cursor]
                if ch == ";" || ch == "(" || ch == ")" {
                    break
                }
                // Read property identifier (uppercase letters)
                var key = ""
                while cursor < chars.count && chars[cursor].isLetter {
                    key.append(chars[cursor])
                    cursor += 1
                }
                key = key.uppercased()
                guard !key.isEmpty else {
                    cursor += 1
                    continue
                }
                var vals: [String] = []
                while cursor < chars.count {
                    skipWhitespace()
                    if cursor < chars.count && chars[cursor] == "[" {
                        vals.append(parseValue())
                    } else {
                        break
                    }
                }
                if !vals.isEmpty {
                    props[key, default: []].append(contentsOf: vals)
                }
            }
            return props
        }

        /// Mutable builder for constructing immutable `SGFNode` tree.
        final class NodeBuilder {
            var properties: [String: [String]]
            var children: [NodeBuilder] = []
            init(properties: [String: [String]]) {
                self.properties = properties
            }
            func build() -> SGFNode {
                // Iterative post-order build to prevent stack overflow on deep SGFs on background threads
                var order: [NodeBuilder] = []
                var stack: [NodeBuilder] = [self]
                while let node = stack.popLast() {
                    order.append(node)
                    for child in node.children {
                        stack.append(child)
                    }
                }
                var built: [ObjectIdentifier: SGFNode] = [:]
                built.reserveCapacity(order.count)
                for node in order.reversed() {
                    let builtChildren = node.children.compactMap { built[ObjectIdentifier($0)] }
                    built[ObjectIdentifier(node)] = SGFNode(properties: node.properties, children: builtChildren)
                }
                return built[ObjectIdentifier(self)] ?? SGFNode(properties: properties, children: [])
            }
        }

        func parseGameTree() -> NodeBuilder? {
            skipWhitespace()
            guard cursor < chars.count && chars[cursor] == "(" else { return nil }
            cursor += 1 // consume '('

            var root: NodeBuilder?
            var current: NodeBuilder?

            while cursor < chars.count {
                skipWhitespace()
                guard cursor < chars.count else { break }
                let ch = chars[cursor]
                if ch == ";" {
                    cursor += 1
                    let props = parseNodeProperties()
                    let node = NodeBuilder(properties: props)
                    if let cur = current {
                        cur.children.append(node)
                    } else {
                        root = node
                    }
                    current = node
                } else if ch == "(" {
                    if let branch = parseGameTree() {
                        if let cur = current {
                            cur.children.append(branch)
                        } else {
                            root = branch
                            current = branch
                        }
                    }
                } else if ch == ")" {
                    cursor += 1
                    break
                } else {
                    cursor += 1
                }
            }
            return root
        }

        return parseGameTree()?.build()
    }

    private static func formatSGFDate(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .autoupdatingCurrent
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            locale: Locale(identifier: "en_US_POSIX"),
            comps.year ?? 2026,
            comps.month ?? 1,
            comps.day ?? 1
        )
    }

    /// Exports a played game into a standard FF[4] SGF string.
    static func export(
        initialState: GoBoardState,
        blackName: String,
        whiteName: String,
        result: String?,
        date: Date,
        moves: [GoMove]
    ) -> String {
        let dateStr = formatSGFDate(date)

        func escape(_ text: String) -> String {
            text.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "]", with: "\\]")
        }

        var parts: [String] = []
        parts.append("(;GM[1]FF[4]CA[UTF-8]AP[StarYi Go:1.0]")
        parts.append("SZ[\(initialState.size)]")
        parts.append(String(format: "KM[%.1f]", locale: Locale(identifier: "en_US_POSIX"), initialState.komi))
        parts.append("DT[\(dateStr)]")
        parts.append("PB[\(escape(blackName))]")
        parts.append("PW[\(escape(whiteName))]")
        if let result, !result.isEmpty {
            parts.append("RE[\(escape(result))]")
        }
        if initialState.handicap >= 2 {
            parts.append("HA[\(initialState.handicap)]")
        }
        parts.append("PL[\(initialState.currentTurn.sgfTag)]")
        for color in [StoneColor.black, .white] {
            let stones = initialState.grid.indices.filter { initialState.grid[$0] == color }
            if !stones.isEmpty {
                parts.append("A\(color.sgfTag)" + stones.map { "[\(initialState.point(for: $0).sgfCoordinate)]" }.joined())
            }
        }

        for move in moves {
            switch move.action {
            case .place(let pt):
                parts.append(";\(move.color.sgfTag)[\(pt.sgfCoordinate)]")
            case .pass:
                parts.append(";\(move.color.sgfTag)[]")
            case .resign:
                break
            }
        }
        parts.append(")")
        return parts.joined()
    }
}
