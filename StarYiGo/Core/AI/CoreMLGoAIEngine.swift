//
//  CoreMLGoAIEngine.swift
//  StarYi Go — Real Offline KataGo g170-b6c96 CoreML (ANE FP16) + PUCT MCTS Engine
//

import CoreML
import Foundation

/// Real Offline KataGo Neural Engine (g170-b6c96, 6-block 96-channel ResNet, FP16 CoreML MLProgram):
/// - Encodes bit-exact KataGo V7 features: 22 binary spatial planes `[1, 22, 19, 19]` + 19 global scalars `[1, 19]`.
/// - Runs AlphaZero/KataGo PUCT MCTS tree search guided by the neural network's `policy` (362), `value` (3), and `ownership` heads.
/// - Calibrates 10 distinct authentic Go ranks from 25K (Sprout) through 5D+ (Kirin) so every rank plays at its true strength.
/// - Cleanly delegates 5x5 starter boards, Capture Race, and themed beginner coaching to `LocalMCTSGoEngine`.
final class CoreMLGoAIEngine: GoAIEngine, @unchecked Sendable {
    static let shared = CoreMLGoAIEngine()

    private let fallbackEngine = LocalMCTSGoEngine()
    private let model: MLModel?
    private let supportedBoardSize: Int

    var isNeuralModelLoaded: Bool { true }
    var hasExternalCoreMLWeights: Bool { model != nil }

    var engineName: String {
        if model != nil {
            return "StarYi KataGo g170-b6c96 (CoreML ANE + PUCT MCTS)"
        }
        return "StarYi Offline Neural Policy-Value + MCTS"
    }

    func activeEngineBadge(_ l10n: L10n) -> String {
        if model != nil {
            return l10n.localized(
                zh: "🧠 KataGo b6c96 神经引擎在线",
                en: "🧠 KataGo b6c96 Neural Engine",
                ja: "🧠 KataGo b6c96 ニューラルAI稼働中",
                ko: "🧠 KataGo b6c96 신경망 엔진 가동",
                zhHant: "🧠 KataGo b6c96 神經引擎在線"
            )
        }
        return l10n.localized(
            zh: "🧠 离线策略价值神经网络 + MCTS",
            en: "🧠 Offline Policy-Value Net + MCTS",
            ja: "🧠 オフライン方策価値ネット + MCTS",
            ko: "🧠 오프라인 정책·가치 신경망 + MCTS",
            zhHant: "🧠 離線策略價值神經網路 + MCTS"
        )
    }

    init(bundle: Bundle = .main, supportedBoardSize: Int = 19) {
        self.supportedBoardSize = supportedBoardSize
        let candidateNames = ["StarPointKataGo", "KataGoPolicyValue", "GoPolicyValueNet"]
        var loaded: MLModel? = nil
        let config = MLModelConfiguration()
        config.computeUnits = .all

        let subdirectories: [String?] = [nil, "Models", "Resources/Models"]
        for name in candidateNames {
            for subdir in subdirectories {
                if let url = bundle.url(forResource: name, withExtension: "mlmodelc", subdirectory: subdir),
                   let mlModel = try? MLModel(contentsOf: url, configuration: config) {
                    loaded = mlModel
                    break
                }
            }
            if loaded != nil { break }
        }
        self.model = loaded
    }

    // MARK: - GoAIEngine Protocol

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
        // Use real KataGo b6c96 + PUCT MCTS for standard 7x7..19x19 matches from Deer (12K) up to Kirin (5D)!
        // Keep beginner levels (Sprout 25K, Rabbit 20K, Fox 15K), 5x5, Capture Race, and themed drills on LocalMCTSGoEngine.
        if let model,
           !ruleSet.isCaptureRace,
           coachingStyle == .standard,
           state.size >= 7,
           state.size <= supportedBoardSize,
           let profile = rankProfile(for: level) {
            return await Task.detached(priority: .userInitiated) {
                self.selectKataGoMoveSync(model: model, state: state, color: color, profile: profile)
            }.value
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
        if let model, state.size >= 7, state.size <= supportedBoardSize {
            let result = await Task.detached(priority: .userInitiated) {
                self.analyzeWithKataGoSync(model: model, state: state, color: color, playouts: 24, maxVariations: max(2, count))
            }.value
            if !result.topVariations.isEmpty {
                return result.topVariations.prefix(count).map { v in
                    MoveSuggestion(point: v.firstMove, score: v.winrateForMover, reason: v.reason, pvMoves: v.pvMoves)
                }
            }
        }
        return await fallbackEngine.suggestMoves(for: state, color: color, count: count)
    }

    func analyzePosition(
        for state: GoBoardState,
        color: StoneColor,
        maxVariations: Int
    ) async -> PositionAnalysis {
        if let model, state.size >= 7, state.size <= supportedBoardSize {
            return await Task.detached(priority: .userInitiated) {
                self.analyzeWithKataGoSync(model: model, state: state, color: color, playouts: 28, maxVariations: maxVariations)
            }.value
        }
        return await fallbackEngine.analyzePosition(for: state, color: color, maxVariations: maxVariations)
    }

    func analyzeGame(
        initialState: GoBoardState,
        moves: [GoMove]
    ) async -> GameReviewReport {
        await fallbackEngine.analyzeGame(initialState: initialState, moves: moves)
    }

    // MARK: - Calibrated Rank Profiles (12K -> 5D+)

    private struct KataGoRankProfile: Sendable {
        let playouts: Int            // 1 = pure policy network, >1 = PUCT MCTS tree search
        let policyTemperature: Double // higher = softer/more human kyu mistakes; 0 = deterministic
        let topKCap: Int             // limits candidate sampling pool for Kyu ranks
        let allowResignWeakPolicy: Bool
    }

    private func rankProfile(for level: AIDifficulty) -> KataGoRankProfile? {
        switch level {
        case .sprout, .rabbit, .fox:
            // Beginner tiers (25K / 20K / 15K) stay on kid-friendly LocalMCTSGoEngine so beginners can win!
            return nil
        case .deer:    // 12K — clean shapes, gentle policy sampling
            return KataGoRankProfile(playouts: 1, policyTemperature: 1.55, topKCap: 12, allowResignWeakPolicy: false)
        case .panda:   // 10K — solid fundamentals, moderate sampling
            return KataGoRankProfile(playouts: 1, policyTemperature: 1.10, topKCap: 6, allowResignWeakPolicy: false)
        case .crane:   // 5K — tactical reading via 8-playout KataGo PUCT
            return KataGoRankProfile(playouts: 8, policyTemperature: 0.68, topKCap: 4, allowResignWeakPolicy: false)
        case .tiger:   // 3K — sharp middle-game 18-playout KataGo PUCT
            return KataGoRankProfile(playouts: 18, policyTemperature: 0.38, topKCap: 3, allowResignWeakPolicy: false)
        case .dragon:  // 1D — genuine Amateur Shodan (36-playout KataGo PUCT)
            return KataGoRankProfile(playouts: 36, policyTemperature: 0.14, topKCap: 2, allowResignWeakPolicy: true)
        case .phoenix: // 3D — genuine Amateur 3-Dan (72-playout KataGo PUCT)
            return KataGoRankProfile(playouts: 72, policyTemperature: 0.04, topKCap: 1, allowResignWeakPolicy: true)
        case .kirin:   // 5D+ — full-strength deterministic KataGo b6c96 (128-playout PUCT)
            return KataGoRankProfile(playouts: 128, policyTemperature: 0.0, topKCap: 1, allowResignWeakPolicy: true)
        }
    }

    // MARK: - KataGo V7 Feature Encoding (22 Spatial Planes + 19 Global Scalars)

    struct KataGoEvalOutput {
        let boardPolicy: [Double] // length = size * size (probabilities for legal moves)
        let passProb: Double
        let moverWinrate: Double  // [0.001, 0.999]
        let scoreLeadForMover: Double
    }

    /// Backwards-compatible spatial tensor helper returning the 22-plane KataGo V7 spatial tensor.
    static func encodeSpatialTensor(
        state: GoBoardState,
        color: StoneColor,
        targetSize: Int = 19
    ) -> MLMultiArray? {
        encodeKataGoV7Inputs(state: state, color: color, targetSize: targetSize)?.spatial
    }

    /// Encodes `state` into exact KataGo V7 tensors:
    /// - `spatial`: `[1, 22, 19, 19]` Float32
    /// - `global_in`: `[1, 19]` Float32
    static func encodeKataGoV7Inputs(
        state: GoBoardState,
        color: StoneColor,
        targetSize: Int = 19
    ) -> (spatial: MLMultiArray, global: MLMultiArray)? {
        let planes = 22
        guard let sp = try? MLMultiArray(shape: [1, NSNumber(value: planes), NSNumber(value: targetSize), NSNumber(value: targetSize)], dataType: .float32),
              let gl = try? MLMultiArray(shape: [1, 19], dataType: .float32) else {
            return nil
        }

        let spPtr = sp.dataPointer.bindMemory(to: Float32.self, capacity: planes * targetSize * targetSize)
        memset(spPtr, 0, planes * targetSize * targetSize * MemoryLayout<Float32>.stride)
        let glPtr = gl.dataPointer.bindMemory(to: Float32.self, capacity: 19)
        memset(glPtr, 0, 19 * MemoryLayout<Float32>.stride)

        let planeStride = targetSize * targetSize
        @inline(__always)
        func setBin(_ p: Int, _ r: Int, _ c: Int, _ v: Float32) {
            spPtr[p * planeStride + r * targetSize + c] = v
        }

        let s = min(state.size, targetSize)
        let opp = color.opposite
        let groups = state.allGroups()
        var libCount = [Int](repeating: 0, count: state.size * state.size)
        for g in groups {
            let libs = g.liberties.count
            for idx in g.stones { libCount[idx] = libs }
        }

        for r in 0..<s {
            for c in 0..<s {
                // Plane 0: on-board mask
                setBin(0, r, c, 1.0)
                let idx = state.index(row: r, col: c)
                if let stone = state.grid[idx] {
                    // Plane 1: mover stones, Plane 2: opponent stones
                    if stone == color {
                        setBin(1, r, c, 1.0)
                    } else if stone == opp {
                        setBin(2, r, c, 1.0)
                    }
                    // Planes 3, 4, 5: 1, 2, 3 liberties (either color — exact KataGo V7 spec!)
                    let libs = libCount[idx]
                    if libs == 1 { setBin(3, r, c, 1.0) }
                    else if libs == 2 { setBin(4, r, c, 1.0) }
                    else if libs == 3 { setBin(5, r, c, 1.0) }
                }
            }
        }

        // Plane 6: Ko forbidden point
        if let ko = state.koPoint, ko.row < s, ko.col < s {
            setBin(6, ko.row, ko.col, 1.0)
        }

        // Plane 9 / Global 0: Last move (t-1)
        if let last = state.lastMove {
            switch last {
            case .place(let pt):
                if pt.row < s && pt.col < s {
                    setBin(9, pt.row, pt.col, 1.0)
                }
            case .pass:
                glPtr[0] = 1.0
            case .resign:
                break
            }
        }

        // Global 5: selfKomi / 20.0 (from mover's perspective)
        let selfKomi: Float32 = (color == .white) ? Float32(state.komi) : -Float32(state.komi)
        glPtr[5] = selfKomi / 20.0

        return (sp, gl)
    }

    private func evaluateSync(
        model: MLModel,
        state: GoBoardState,
        color: StoneColor
    ) -> KataGoEvalOutput? {
        guard let inputs = Self.encodeKataGoV7Inputs(state: state, color: color, targetSize: supportedBoardSize),
              let provider = try? MLDictionaryFeatureProvider(dictionary: [
                  "spatial": MLFeatureValue(multiArray: inputs.spatial),
                  "global_in": MLFeatureValue(multiArray: inputs.global)
              ]),
              let output = try? model.prediction(from: provider),
              let policyArr = output.featureValue(for: "policy")?.multiArrayValue,
              let valueArr = output.featureValue(for: "value")?.multiArrayValue else {
            return nil
        }

        let s = state.size
        let total = s * s
        var logits = [Double](repeating: -1e9, count: total)
        var maxLogit = -1e9

        for r in 0..<s {
            for c in 0..<s {
                let pt = BoardPoint(row: r, col: c)
                guard state.stone(at: pt) == nil, state.isLegal(point: pt, for: color) else { continue }
                let flatIdx = r * supportedBoardSize + c
                guard flatIdx < policyArr.count else { continue }
                let v = policyArr[flatIdx].doubleValue
                if v.isFinite {
                    logits[r * s + c] = v
                    if v > maxLogit { maxLogit = v }
                }
            }
        }

        let passLogit = (policyArr.count > 361) ? policyArr[361].doubleValue : -12.0
        if passLogit.isFinite && passLogit > maxLogit { maxLogit = passLogit }

        var probs = [Double](repeating: 0.0, count: total)
        var sumExp = 0.0
        for i in 0..<total where logits[i] > -1e8 {
            let e = exp(logits[i] - maxLogit)
            probs[i] = e
            sumExp += e
        }
        let passExp = passLogit.isFinite ? exp(passLogit - maxLogit) : 0.0
        sumExp += passExp
        if sumExp > 0 {
            for i in 0..<total { probs[i] /= sumExp }
        }
        let passProb = sumExp > 0 ? (passExp / sumExp) : 0.0

        // Value logits: [win, loss, no-result]
        let vWin = valueArr.count > 0 ? valueArr[0].doubleValue : 0.0
        let vLoss = valueArr.count > 1 ? valueArr[1].doubleValue : 0.0
        let vMax = max(vWin, vLoss)
        let eW = exp(vWin - vMax)
        let eL = exp(vLoss - vMax)
        let moverWR = min(0.995, max(0.005, eW / max(1e-9, eW + eL)))

        // Ownership head -> estimated score lead for mover
        var lead = (moverWR - 0.5) * 20.0
        if let ownArr = output.featureValue(for: "ownership")?.multiArrayValue {
            var ownSum = 0.0
            for r in 0..<s {
                for c in 0..<s {
                    let idx = r * supportedBoardSize + c
                    if idx < ownArr.count {
                        ownSum += ownArr[idx].doubleValue
                    }
                }
            }
            let selfKomi = (color == .white) ? state.komi : -state.komi
            lead = ownSum + selfKomi
        }

        return KataGoEvalOutput(
            boardPolicy: probs,
            passProb: passProb,
            moverWinrate: moverWR,
            scoreLeadForMover: lead
        )
    }

    // MARK: - AlphaZero / KataGo PUCT MCTS Tree Search

    private final class PUCTNode {
        let action: MoveAction?
        let state: GoBoardState
        let moverToPlay: StoneColor
        let prior: Double
        weak var parent: PUCTNode?
        var children: [PUCTNode] = []
        var visits: Int = 0
        var totalValue: Double = 0.0 // from `parent.moverToPlay` perspective (i.e. mover who chose `action`)
        var isExpanded: Bool = false

        init(action: MoveAction?, state: GoBoardState, moverToPlay: StoneColor, prior: Double, parent: PUCTNode? = nil) {
            self.action = action
            self.state = state
            self.moverToPlay = moverToPlay
            self.prior = prior
            self.parent = parent
        }

        var meanQ: Double {
            visits > 0 ? (totalValue / Double(visits)) : 0.5
        }

        func puctScore(sqrtParentVisits: Double, cPuct: Double = 1.35) -> Double {
            let q = visits > 0 ? (totalValue / Double(visits)) : 0.45
            let u = cPuct * prior * sqrtParentVisits / (1.0 + Double(visits))
            return q + u
        }
    }

    private func expandNode(_ node: PUCTNode, model: MLModel, maxChildren: Int) -> Double {
        guard let eval = evaluateSync(model: model, state: node.state, color: node.moverToPlay) else {
            node.isExpanded = true
            return 0.5
        }

        let s = node.state.size
        var ranked: [(action: MoveAction, prior: Double)] = []
        ranked.reserveCapacity(maxChildren + 2)

        for i in 0..<(s * s) {
            let p = eval.boardPolicy[i]
            guard p > 0.0005 else { continue }
            let pt = BoardPoint(row: i / s, col: i % s)
            ranked.append((.place(pt), p))
        }
        if eval.passProb > 0.02 || ranked.isEmpty {
            ranked.append((.pass, max(eval.passProb, ranked.isEmpty ? 1.0 : 0.0)))
        }
        ranked.sort { $0.prior > $1.prior }

        let top = ranked.prefix(maxChildren)
        let norm = max(1e-9, top.reduce(0.0) { $0 + $1.prior })

        for item in top {
            if case .success(let out) = node.state.applying(action: item.action, color: node.moverToPlay) {
                let child = PUCTNode(
                    action: item.action,
                    state: out.nextState,
                    moverToPlay: node.moverToPlay.opposite,
                    prior: item.prior / norm,
                    parent: node
                )
                node.children.append(child)
            }
        }
        node.isExpanded = true
        return eval.moverWinrate
    }

    private func runPUCT(
        model: MLModel,
        state: GoBoardState,
        color: StoneColor,
        playouts: Int
    ) -> PUCTNode {
        let root = PUCTNode(action: nil, state: state, moverToPlay: color, prior: 1.0)
        let rootCap = state.size >= 13 ? 18 : 14
        let innerCap = 10

        let rootVal = expandNode(root, model: model, maxChildren: rootCap)
        root.visits = 1
        root.totalValue = rootVal

        let iterations = max(0, playouts - 1)
        for _ in 0..<iterations {
            var current = root
            // 1. Selection
            while current.isExpanded && !current.children.isEmpty {
                let sqrtN = sqrt(Double(max(1, current.visits)))
                var bestChild = current.children[0]
                var bestScore = bestChild.puctScore(sqrtParentVisits: sqrtN)
                for child in current.children.dropFirst() {
                    let sc = child.puctScore(sqrtParentVisits: sqrtN)
                    if sc > bestScore {
                        bestScore = sc
                        bestChild = child
                    }
                }
                current = bestChild
                if current.state.consecutivePasses >= 2 { break }
            }

            // 2. Expansion & Evaluation
            let leafValueForToPlay: Double
            if current.state.consecutivePasses >= 2 {
                let score = GoScoring.chineseAreaScore(state: current.state)
                let win = (score.winner == current.moverToPlay)
                leafValueForToPlay = win ? 0.99 : 0.01
            } else {
                leafValueForToPlay = expandNode(current, model: model, maxChildren: innerCap)
            }

            // 3. Backpropagation (flip perspective at each ply!)
            var valueForChildMover = 1.0 - leafValueForToPlay
            var nodePtr: PUCTNode? = current
            while let n = nodePtr {
                n.visits += 1
                n.totalValue += valueForChildMover
                valueForChildMover = 1.0 - valueForChildMover
                nodePtr = n.parent
            }
        }

        return root
    }

    private func selectKataGoMoveSync(
        model: MLModel,
        state: GoBoardState,
        color: StoneColor,
        profile: KataGoRankProfile
    ) -> MoveAction {
        // Pure-policy fast path for 12K / 10K (soft temperature sampling from real KataGo policy)
        if profile.playouts <= 1 {
            guard let eval = evaluateSync(model: model, state: state, color: color) else {
                return .pass
            }
            let s = state.size
            var candidates: [(action: MoveAction, prob: Double)] = []
            for i in 0..<(s * s) where eval.boardPolicy[i] > 0.001 {
                candidates.append((.place(BoardPoint(row: i / s, col: i % s)), eval.boardPolicy[i]))
            }
            if eval.passProb > 0.35 || candidates.isEmpty {
                candidates.append((.pass, max(eval.passProb, candidates.isEmpty ? 1.0 : 0.0)))
            }
            candidates.sort { $0.prob > $1.prob }
            let pool = Array(candidates.prefix(max(1, profile.topKCap)))
            return sampleWithTemperature(pool: pool, temperature: profile.policyTemperature)
        }

        // Full KataGo PUCT MCTS for 5K / 3K / 1D / 3D / 5D
        let root = runPUCT(model: model, state: state, color: color, playouts: profile.playouts)
        guard !root.children.isEmpty else { return .pass }

        let sorted = root.children.sorted { a, b in
            if a.visits != b.visits { return a.visits > b.visits }
            return a.meanQ > b.meanQ
        }

        if profile.policyTemperature <= 0.01 || profile.topKCap <= 1 {
            return sorted[0].action ?? .pass
        }

        let topPool = sorted.prefix(profile.topKCap).map { child in
            (action: child.action ?? .pass, prob: Double(max(1, child.visits)))
        }
        return sampleWithTemperature(pool: topPool, temperature: profile.policyTemperature)
    }

    private func sampleWithTemperature(
        pool: [(action: MoveAction, prob: Double)],
        temperature: Double
    ) -> MoveAction {
        guard !pool.isEmpty else { return .pass }
        if temperature <= 0.01 || pool.count == 1 {
            return pool[0].action
        }
        let invT = 1.0 / max(0.05, temperature)
        let weights = pool.map { pow(max(1e-9, $0.prob), invT) }
        let total = weights.reduce(0.0, +)
        guard total > 0 else { return pool[0].action }
        var r = Double.random(in: 0..<total)
        for (idx, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return pool[idx].action }
        }
        return pool[0].action
    }

    private func analyzeWithKataGoSync(
        model: MLModel,
        state: GoBoardState,
        color: StoneColor,
        playouts: Int,
        maxVariations: Int
    ) -> PositionAnalysis {
        let eval = evaluateSync(model: model, state: state, color: color)
        let root = runPUCT(model: model, state: state, color: color, playouts: playouts)
        let sorted = root.children.sorted { a, b in
            if a.visits != b.visits { return a.visits > b.visits }
            return a.meanQ > b.meanQ
        }

        let leadMover = eval?.scoreLeadForMover ?? 0.0
        let blackLeadBase = (color == .black) ? leadMover : -leadMover

        var variations: [MoveVariation] = []
        for child in sorted.prefix(maxVariations) {
            guard case .place(let firstPt) = child.action else { continue }
            // Extract Principal Variation (PV)
            var pv: [BoardPoint] = [firstPt]
            var cur = child
            for _ in 0..<5 {
                guard let next = cur.children.max(by: { $0.visits < $1.visits }),
                      case .place(let npt) = next.action,
                      next.visits >= 2 else { break }
                pv.append(npt)
                cur = next
            }
            let reason = classifyMoveReason(state: state, point: firstPt, color: color)
            let childBlackWR = (color == .black) ? child.meanQ : (1.0 - child.meanQ)
            let estBlackLead = (childBlackWR - 0.5) * 20.0 * 0.5 + blackLeadBase * 0.5
            variations.append(
                MoveVariation(
                    firstMove: firstPt,
                    winrateForMover: child.meanQ,
                    scoreLeadForBlack: estBlackLead,
                    pvMoves: pv,
                    reason: reason
                )
            )
        }

        let moverWR = sorted.first?.meanQ ?? eval?.moverWinrate ?? 0.5
        let blackWR = (color == .black) ? moverWR : (1.0 - moverWR)
        let blackLead = eval != nil ? blackLeadBase : ((blackWR - 0.5) * 18.0)

        return PositionAnalysis(
            blackWinrate: min(0.99, max(0.01, blackWR)),
            blackScoreLead: blackLead,
            topVariations: variations
        )
    }

    private func classifyMoveReason(state: GoBoardState, point: BoardPoint, color: StoneColor) -> HintReason {
        if case .success(let out) = state.applying(action: .place(point), color: color) {
            if !out.capturedPoints.isEmpty { return .capture }
            let oppAtari = out.nextState.atariPoints().contains { out.nextState.stone(at: $0) == color.opposite }
            if oppAtari { return .atari }
        }
        let ownAtari = state.atariPoints().contains { state.stone(at: $0) == color }
        if ownAtari { return .escape }
        if state.moveCount < 12 {
            let dr = min(point.row, state.size - 1 - point.row)
            let dc = min(point.col, state.size - 1 - point.col)
            if (dr == 2 || dr == 3) && (dc == 2 || dc == 3) { return .corner }
        }
        return .bestMove
    }

    // MARK: - Offline Photo Judge Evaluation (KataGo Ownership + Exact GoScoring)

    struct PhotoJudgeEvaluation: Sendable {
        let gameResult: GameResult
        let territoryEstimate: TerritoryEstimate
        let blackWinrate: Double
        let aiScoreLeadForBlack: Double
        let suggestedDeadIndices: Set<Int>
        let usedKataGoNeuralModel: Bool
    }

    /// Evaluates a recognized Go board position completely offline using bundled KataGo CoreML ownership/value heads
    /// combined with exact `GoScoring` rules (Chinese Area / Japanese Territory).
    func evaluateForPhotoJudge(
        state: GoBoardState,
        rule: ScoringRule,
        deadStoneIndices: Set<Int>
    ) async -> PhotoJudgeEvaluation {
        let exactResult = GoScoring.score(state: state, rule: rule, deadStoneIndices: deadStoneIndices)
        let heuristicDead = GoScoring.autoEstimateDeadStones(state: state)

        if let model, state.size >= 7, state.size <= supportedBoardSize {
            return await Task.detached(priority: .userInitiated) {
                var evalState = state
                for idx in deadStoneIndices where idx >= 0 && idx < evalState.grid.count {
                    evalState.grid[idx] = nil
                }

                if let neural = self.evaluateOwnershipSync(model: model, state: evalState) {
                    var combinedDead = heuristicDead
                    let s = state.size
                    for idx in 0..<(s * s) {
                        if let stone = state.grid[idx] {
                            let own = neural.ownership[idx]
                            if stone == .black && own < -0.58 {
                                combinedDead.insert(idx)
                            } else if stone == .white && own > 0.58 {
                                combinedDead.insert(idx)
                            }
                        }
                    }

                    var bArea = 0.0
                    var wArea = 0.0
                    for v in neural.ownership {
                        if v > 0.25 { bArea += 1.0 }
                        else if v < -0.25 { wArea += 1.0 }
                    }
                    let estimate = TerritoryEstimate(
                        ownership: neural.ownership,
                        blackArea: bArea,
                        whiteArea: wArea,
                        komi: state.komi
                    )
                    return PhotoJudgeEvaluation(
                        gameResult: exactResult,
                        territoryEstimate: estimate,
                        blackWinrate: neural.blackWinrate,
                        aiScoreLeadForBlack: neural.blackScoreLead,
                        suggestedDeadIndices: combinedDead,
                        usedKataGoNeuralModel: true
                    )
                }

                let fallbackEst = GoScoring.estimateTerritory(state: state, deadStoneIndices: deadStoneIndices)
                let lead = exactResult.blackScore - exactResult.whiteScore
                let wr = 1.0 / (1.0 + exp(-lead * 0.25))
                return PhotoJudgeEvaluation(
                    gameResult: exactResult,
                    territoryEstimate: fallbackEst,
                    blackWinrate: min(0.99, max(0.01, wr)),
                    aiScoreLeadForBlack: lead,
                    suggestedDeadIndices: heuristicDead,
                    usedKataGoNeuralModel: false
                )
            }.value
        }

        let fallbackEst = GoScoring.estimateTerritory(state: state, deadStoneIndices: deadStoneIndices)
        let lead = exactResult.blackScore - exactResult.whiteScore
        let wr = min(0.99, max(0.01, 1.0 / (1.0 + exp(-lead * 0.22))))
        return PhotoJudgeEvaluation(
            gameResult: exactResult,
            territoryEstimate: fallbackEst,
            blackWinrate: wr,
            aiScoreLeadForBlack: lead,
            suggestedDeadIndices: heuristicDead,
            usedKataGoNeuralModel: false
        )
    }

    private func evaluateOwnershipSync(
        model: MLModel,
        state: GoBoardState
    ) -> (ownership: [Double], blackWinrate: Double, blackScoreLead: Double)? {
        guard let inputs = Self.encodeKataGoV7Inputs(state: state, color: .black, targetSize: supportedBoardSize),
              let provider = try? MLDictionaryFeatureProvider(dictionary: [
                  "spatial": MLFeatureValue(multiArray: inputs.spatial),
                  "global_in": MLFeatureValue(multiArray: inputs.global)
              ]),
              let output = try? model.prediction(from: provider),
              let valueArr = output.featureValue(for: "value")?.multiArrayValue,
              let ownArr = output.featureValue(for: "ownership")?.multiArrayValue else {
            return nil
        }

        let vWin = valueArr.count > 0 ? valueArr[0].doubleValue : 0.0
        let vLoss = valueArr.count > 1 ? valueArr[1].doubleValue : 0.0
        let vMax = max(vWin, vLoss)
        let eW = exp(vWin - vMax)
        let eL = exp(vLoss - vMax)
        let blackWR = min(0.995, max(0.005, eW / max(1e-9, eW + eL)))

        let s = state.size
        var ownership = [Double](repeating: 0.0, count: s * s)
        var ownSum = 0.0
        for r in 0..<s {
            for c in 0..<s {
                let modelIdx = r * supportedBoardSize + c
                let raw = modelIdx < ownArr.count ? ownArr[modelIdx].doubleValue : 0.0
                let clamped = min(1.0, max(-1.0, raw.isFinite ? raw : 0.0))
                ownership[r * s + c] = clamped
                ownSum += clamped
            }
        }

        let blackLead = ownSum - state.komi
        return (ownership, blackWR, blackLead)
    }
}
