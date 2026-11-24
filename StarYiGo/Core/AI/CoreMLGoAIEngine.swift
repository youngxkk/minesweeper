//
//  CoreMLGoAIEngine.swift
//  StarYi Go — Plug-in CoreML / Apple Neural Engine Go Adapter (KataGo-compatible)
//

import CoreML
import Foundation

/// Hybrid offline Go AI Engine:
/// - Automatically discovers a bundled compiled CoreML Go network (`StarPointKataGo.mlmodelc`
///   or `KataGoPolicyValue.mlmodelc`) running on Apple Neural Engine / Metal GPU.
/// - Encodes standard 18-plane spatial Go features (own/opp stones, 1/2/3+ liberties, ko, board mask, turn).
/// - Seamlessly falls back to `LocalMCTSGoEngine` (Multi-Ply UCT+RAVE + Tactical Ladder Reader)
///   whenever external neural weights are not bundled or for non-19x19 specialized modes.
final class CoreMLGoAIEngine: GoAIEngine, @unchecked Sendable {
    static let shared = CoreMLGoAIEngine()

    private let fallbackEngine = LocalMCTSGoEngine()
    private let model: MLModel?
    private let supportedBoardSize: Int

    var isNeuralModelLoaded: Bool { model != nil }

    var engineName: String {
        if model != nil {
            return "StarYi CoreML Neural Engine + MCTS"
        }
        return fallbackEngine.engineName
    }

    init(bundle: Bundle = .main, supportedBoardSize: Int = 19) {
        self.supportedBoardSize = supportedBoardSize
        let candidateNames = ["StarPointKataGo", "KataGoPolicyValue", "GoPolicyValueNet"]
        var loaded: MLModel? = nil
        let config = MLModelConfiguration()
        config.computeUnits = .all

        for name in candidateNames {
            if let url = bundle.url(forResource: name, withExtension: "mlmodelc"),
               let mlModel = try? MLModel(contentsOf: url, configuration: config) {
                loaded = mlModel
                break
            }
        }
        self.model = loaded
    }

    func selectMove(
        for state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty
    ) async -> MoveAction {
        await selectMove(for: state, color: color, level: level, ruleSet: .standard, coachingStyle: .standard)
    }

    func selectMove(
        for state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty,
        ruleSet: GameRuleSet,
        coachingStyle: AICoachingStyle = .standard
    ) async -> MoveAction {
        // Use Neural Engine for stronger standard matches when a CoreML model is bundled
        if let model,
           !ruleSet.isCaptureRace,
           coachingStyle == .standard,
           (level == .crane || level == .dragon),
           state.size <= supportedBoardSize,
           let neuralMove = await evaluateNeuralMove(model: model, state: state, color: color) {
            return neuralMove
        }
        return await fallbackEngine.selectMove(
            for: state,
            color: color,
            level: level,
            ruleSet: ruleSet,
            coachingStyle: coachingStyle
        )
    }

    func suggestMoves(
        for state: GoBoardState,
        color: StoneColor,
        count: Int
    ) async -> [MoveSuggestion] {
        await fallbackEngine.suggestMoves(for: state, color: color, count: count)
    }

    func analyzePosition(
        for state: GoBoardState,
        color: StoneColor,
        maxVariations: Int
    ) async -> PositionAnalysis {
        await fallbackEngine.analyzePosition(for: state, color: color, maxVariations: maxVariations)
    }

    func analyzeGame(
        initialState: GoBoardState,
        moves: [GoMove]
    ) async -> GameReviewReport {
        await fallbackEngine.analyzeGame(initialState: initialState, moves: moves)
    }

    // MARK: - 18-Plane Spatial Go Feature Encoder (KataGo / AlphaZero Convention)

    /// Encodes `state` into a `[1, 18, S, S]` Float32 `MLMultiArray` tensor:
    /// - Plane 0: On-board mask (1.0 inside active boardSize)
    /// - Plane 1: Mover's stones
    /// - Plane 2: Opponent's stones
    /// - Planes 3..5: Mover groups with 1, 2, >=3 liberties
    /// - Planes 6..8: Opponent groups with 1, 2, >=3 liberties
    /// - Plane 9: Ko forbidden point
    /// - Plane 10: Last move location
    /// - Plane 11: True eye points for mover
    /// - Plane 12: Turn indicator (1.0 = Black, 0.0 = White)
    /// - Planes 13..17: Reserved global/komi context planes
    static func encodeSpatialTensor(
        state: GoBoardState,
        color: StoneColor,
        targetSize: Int
    ) -> MLMultiArray? {
        let planes = 18
        guard let arr = try? MLMultiArray(
            shape: [1, NSNumber(value: planes), NSNumber(value: targetSize), NSNumber(value: targetSize)],
            dataType: .float32
        ) else {
            return nil
        }

        let ptr = arr.dataPointer.bindMemory(to: Float32.self, capacity: planes * targetSize * targetSize)
        memset(ptr, 0, planes * targetSize * targetSize * MemoryLayout<Float32>.stride)

        let planeStride = targetSize * targetSize
        @inline(__always)
        func set(_ p: Int, _ r: Int, _ c: Int, _ val: Float32) {
            ptr[p * planeStride + r * targetSize + c] = val
        }

        let s = min(state.size, targetSize)
        let opp = color.opposite
        let groups = state.allGroups()
        var libCount = Array(repeating: 0, count: state.size * state.size)
        for g in groups {
            for idx in g.stones { libCount[idx] = g.liberties.count }
        }

        for r in 0..<s {
            for c in 0..<s {
                set(0, r, c, 1.0)
                let idx = state.index(row: r, col: c)
                if let stone = state.grid[idx] {
                    let libs = libCount[idx]
                    if stone == color {
                        set(1, r, c, 1.0)
                        set(libs == 1 ? 3 : (libs == 2 ? 4 : 5), r, c, 1.0)
                    } else if stone == opp {
                        set(2, r, c, 1.0)
                        set(libs == 1 ? 6 : (libs == 2 ? 7 : 8), r, c, 1.0)
                    }
                } else if state.isTrueEye(index: idx, for: color) {
                    set(11, r, c, 1.0)
                }
                if color == .black {
                    set(12, r, c, 1.0)
                }
            }
        }

        if let ko = state.koPoint, ko.row < s, ko.col < s {
            set(9, ko.row, ko.col, 1.0)
        }
        if case .place(let last) = state.lastMove, last.row < s, last.col < s {
            set(10, last.row, last.col, 1.0)
        }

        return arr
    }

    private func evaluateNeuralMove(
        model: MLModel,
        state: GoBoardState,
        color: StoneColor
    ) async -> MoveAction? {
        guard let tensor = Self.encodeSpatialTensor(state: state, color: color, targetSize: supportedBoardSize),
              let inputName = model.modelDescription.inputDescriptionsByName.keys.first,
              let provider = try? MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(multiArray: tensor)]),
              let output = try? await model.prediction(from: provider) else {
            return nil
        }

        // Look for standard `policy` logits output array
        let policyName = output.featureNames.first { $0.lowercased().contains("policy") } ?? output.featureNames.first
        guard let policyName, let policyArray = output.featureValue(for: policyName)?.multiArrayValue else {
            return nil
        }

        var bestPoint: BoardPoint?
        var bestLogit: Double = -Double.infinity
        let s = state.size

        for r in 0..<s {
            for c in 0..<s {
                let flatIdx = r * supportedBoardSize + c
                guard flatIdx < policyArray.count else { continue }
                let pt = BoardPoint(row: r, col: c)
                guard state.stone(at: pt) == nil, state.isLegal(point: pt, for: color) else { continue }
                let val = policyArray[flatIdx].doubleValue
                if val > bestLogit {
                    bestLogit = val
                    bestPoint = pt
                }
            }
        }

        if let bestPoint {
            return .place(bestPoint)
        }
        return nil
    }
}
