//
//  CoreMLGoAIEngine.swift
//  StarYi Go — Real Offline KataGo g170-b6c96 CoreML (ANE FP16) + PUCT MCTS Engine
//

import CoreML
import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// Manages Apple On-Demand Resources (ODR) for the optional 25.5 MB Pro KataGo model (`b18c384nbt`).
/// - When bundled locally (e.g. Simulator/Debug) or already cached, transitions immediately to `.ready`.
/// - When tagged as ODR (`katago-pro-b18c384nbt`) in App Store Connect, downloads seamlessly on demand
///   from Apple's CDN while falling back to the bundled 5.8 MB Standard model (`b10c128`) if offline.
@MainActor
@Observable
final class KataGoProModelODRManager {
    static let shared = KataGoProModelODRManager()
    nonisolated static let odrTag = "katago-pro-b18c384nbt"

    enum DownloadState: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case failed
    }

    #if DEBUG
    private static let debugBypassDefaultsKey = "staryigo.debug.bypassProModelODR"
    /// Debug-only switch (defaults to `true`): when ON, directly uses the locally bundled `b18c384nbt` model
    /// without going through Apple ODR; turn OFF to test the real `NSBundleResourceRequest` ODR flow.
    var bypassODRUseLocalModel: Bool {
        didSet {
            UserDefaults.standard.set(bypassODRUseLocalModel, forKey: Self.debugBypassDefaultsKey)
            if bypassODRUseLocalModel {
                progressObservation?.invalidate()
                progressObservation = nil
                activeRequest?.endAccessingResources()
                activeRequest = nil
                state = .ready
                CoreMLGoAIEngine.shared.setProModelAvailableForUse(true)
            } else {
                activeRequest?.endAccessingResources()
                activeRequest = nil
                state = .notDownloaded
                CoreMLGoAIEngine.shared.setProModelAvailableForUse(false)
                refreshAvailability()
            }
        }
    }
    #endif

    private(set) var state: DownloadState = .notDownloaded
    private var activeRequest: NSBundleResourceRequest?
    private var pendingAvailabilityRequest: NSBundleResourceRequest?
    private var progressObservation: NSKeyValueObservation?

    private init() {
        #if DEBUG
        let stored = UserDefaults.standard.object(forKey: Self.debugBypassDefaultsKey) as? Bool
        self.bypassODRUseLocalModel = stored ?? true
        if self.bypassODRUseLocalModel {
            self.state = .ready
            CoreMLGoAIEngine.shared.setProModelAvailableForUse(true)
            return
        }
        #endif
        CoreMLGoAIEngine.shared.setProModelAvailableForUse(false)
        refreshAvailability()
    }

    func refreshAvailability() {
        #if DEBUG
        if bypassODRUseLocalModel {
            state = .ready
            CoreMLGoAIEngine.shared.setProModelAvailableForUse(true)
            return
        }
        #endif
        let request = NSBundleResourceRequest(tags: [Self.odrTag])
        pendingAvailabilityRequest = request
        request.conditionallyBeginAccessingResources { [weak self] available in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let checkedRequest = self.pendingAvailabilityRequest
                self.pendingAvailabilityRequest = nil
                #if DEBUG
                if self.bypassODRUseLocalModel { return }
                #endif
                if available {
                    self.activeRequest = checkedRequest
                    Bundle.main.setPreservationPriority(1.0, forTags: [Self.odrTag])
                    self.state = .ready
                    CoreMLGoAIEngine.shared.setProModelAvailableForUse(true)
                    CoreMLGoAIEngine.shared.clearMissingPresetCache(for: .b18c384nbt)
                } else if case .downloading = self.state {
                    // Keep active download state
                } else {
                    self.state = .notDownloaded
                    CoreMLGoAIEngine.shared.setProModelAvailableForUse(false)
                }
            }
        }
    }

    func ensureDownloaded() {
        #if DEBUG
        if bypassODRUseLocalModel {
            state = .ready
            CoreMLGoAIEngine.shared.setProModelAvailableForUse(true)
            return
        }
        #endif
        if state == .ready { return }
        if case .downloading = state { return }

        let request = NSBundleResourceRequest(tags: [Self.odrTag])
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        activeRequest = request
        state = .downloading(progress: 0.02)

        progressObservation?.invalidate()
        progressObservation = request.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] prog, _ in
            let frac = max(0.02, min(1.0, prog.fractionCompleted))
            Task { @MainActor [weak self] in
                guard let self, case .downloading = self.state else { return }
                self.state = .downloading(progress: frac)
            }
        }

        request.beginAccessingResources { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.progressObservation?.invalidate()
                self.progressObservation = nil
                #if DEBUG
                if self.bypassODRUseLocalModel { return }
                #endif
                if error == nil {
                    Bundle.main.setPreservationPriority(1.0, forTags: [Self.odrTag])
                    self.state = .ready
                    CoreMLGoAIEngine.shared.setProModelAvailableForUse(true)
                    CoreMLGoAIEngine.shared.clearMissingPresetCache(for: .b18c384nbt)
                } else {
                    self.activeRequest = nil
                    self.state = .failed
                    CoreMLGoAIEngine.shared.setProModelAvailableForUse(false)
                }
            }
        }
    }
}

/// Selectable offline KataGo CoreML neural network models bundled in the app.
enum KataGoModelPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case b6c96 = "b6c96"
    case b10c128 = "b10c128"
    case b18c384nbt = "b18c384nbt"

    var id: String { rawValue }

    /// Default balanced model for all users.
    static let defaultPreset: KataGoModelPreset = .b10c128

    /// Compiled `.mlmodelc` resource name inside `Resources/Models/`.
    var resourceName: String {
        switch self {
        case .b6c96: return "StarPointKataGo"
        case .b10c128: return "StarPointKataGo_b10c128"
        case .b18c384nbt: return "StarPointKataGo_b18c384nbt"
        }
    }

    var technicalName: String {
        switch self {
        case .b6c96: return "g170-b6c96"
        case .b10c128: return "kata1-b10c128"
        case .b18c384nbt: return "kata1-b18c384nbt"
        }
    }

    func shortTitle(_ l10n: L10n) -> String {
        switch self {
        case .b6c96:
            return l10n.localized(zh: "轻量 b6", en: "Light b6", ja: "軽量 b6", ko: "경량 b6", zhHant: "輕量 b6")
        case .b10c128:
            return l10n.localized(zh: "均衡 b10", en: "Balanced b10", ja: "標準 b10", ko: "균형 b10", zhHant: "均衡 b10")
        case .b18c384nbt:
            return l10n.localized(zh: "职业 b18", en: "Pro b18", ja: "プロ b18", ko: "프로 b18", zhHant: "職業 b18")
        }
    }

    func summaryText(_ l10n: L10n) -> String {
        switch self {
        case .b6c96:
            return l10n.localized(
                zh: "KataGo g170-b6c96（极速省电 · 业余 5D 棋力，发热量最低）",
                en: "KataGo g170-b6c96 (Ultra-fast & cool · Amateur 5D strength)",
                ja: "KataGo g170-b6c96（超高速・省電力・アマ5段相当）",
                ko: "KataGo g170-b6c96 (초고속·저전력 · 아마 5단 기력)",
                zhHant: "KataGo g170-b6c96（極速省電 · 業餘 5D 棋力，發熱量最低）"
            )
        case .b10c128:
            return l10n.localized(
                zh: "KataGo kata1-b10c128（默认推荐 · 速度与高段死活/官子精度均衡）",
                en: "KataGo kata1-b10c128 (Default · Great balance of speed and strong reading)",
                ja: "KataGo kata1-b10c128（標準おすすめ・速度と読み精度の好バランス）",
                ko: "KataGo kata1-b10c128 (기본 추천 · 속도와 수읽기 정확도의 최적 균형)",
                zhHant: "KataGo kata1-b10c128（預設推薦 · 速度與高段死活/官子精度均衡）"
            )
        case .b18c384nbt:
            return l10n.localized(
                zh: "KataGo kata1-b18c384nbt（职业级大模型 · 复杂对杀与复盘最精准，思考稍慢）",
                en: "KataGo kata1-b18c384nbt (Pro-grade · Deepest reading & review accuracy, slightly slower)",
                ja: "KataGo kata1-b18c384nbt（プロ級大型モデル・複雑な攻め合いと検討が最高精度）",
                ko: "KataGo kata1-b18c384nbt (프로급 대형 모델 · 복잡한 수상전·복기 최고 정확도)",
                zhHant: "KataGo kata1-b18c384nbt（職業級大模型 · 複雜對殺與複盤最精準，思考稍慢）"
            )
        }
    }
}

/// Real Offline KataGo Neural Engine (multi-model CoreML ANE + PUCT MCTS):
/// - Supports switching between bundled `g170-b6c96`, `kata1-b10c128` (default), and `kata1-b18c384nbt`.
/// - Encodes bit-exact KataGo V7/V8 features: 22 binary spatial planes `[1, 22, 19, 19]` + 19 global scalars `[1, 19]`.
/// - Runs AlphaZero/KataGo PUCT MCTS tree search guided by the neural network's `policy` (362), `value` (3), and `ownership` heads.
/// - Calibrates 10 distinct authentic Go ranks from 25K (Sprout) through 5D+ (Kirin) so every rank plays at its true strength.
/// - Cleanly delegates 5x5 starter boards, Capture Race, and themed beginner coaching to `LocalMCTSGoEngine`.
final class CoreMLGoAIEngine: GoAIEngine, @unchecked Sendable {
    static let shared = CoreMLGoAIEngine()

    private let fallbackEngine = LocalMCTSGoEngine()
    private let bundle: Bundle
    private let supportedBoardSize: Int
    private let lock = NSLock()
    private let loadLock = NSLock()
    private let inferenceLock = NSLock()
    private var _activePreset: KataGoModelPreset = .defaultPreset
    /// Retain only the single currently active model in memory to avoid pinning 30+ MB of ANE/GPU weights.
    private var activeLoadedModel: (preset: KataGoModelPreset, model: MLModel)? = nil
    private var missingPresets: Set<KataGoModelPreset> = []
    private var proModelAvailableForUse: Bool = true
    private var memoryWarningObserver: NSObjectProtocol?

    var activeModelPreset: KataGoModelPreset {
        lock.lock()
        defer { lock.unlock() }
        return _activePreset
    }

    func setActiveModelPreset(_ preset: KataGoModelPreset) {
        lock.lock()
        let changed = (_activePreset != preset)
        _activePreset = preset
        if changed, let loaded = activeLoadedModel, loaded.preset != preset {
            activeLoadedModel = nil
        }
        lock.unlock()
    }

    func evictLoadedModels() {
        lock.lock()
        activeLoadedModel = nil
        lock.unlock()
    }

    func clearMissingPresetCache(for preset: KataGoModelPreset) {
        lock.lock()
        missingPresets.remove(preset)
        lock.unlock()
    }

    func setProModelAvailableForUse(_ available: Bool) {
        lock.lock()
        proModelAvailableForUse = available
        if !available, let loaded = activeLoadedModel, loaded.preset == .b18c384nbt {
            activeLoadedModel = nil
        }
        lock.unlock()
    }

    var isNeuralModelLoaded: Bool { true }
    var hasExternalCoreMLWeights: Bool { resolvedAvailablePreset() != nil }

    var engineName: String {
        if let preset = resolvedAvailablePreset() {
            return "StarYi KataGo \(preset.technicalName) (CoreML ANE + PUCT MCTS)"
        }
        return "StarYi Offline Neural Policy-Value + MCTS"
    }

    func activeEngineBadge(_ l10n: L10n) -> String {
        if let preset = resolvedAvailablePreset() {
            let tag = preset.rawValue
            return l10n.localized(
                zh: "🧠 KataGo \(tag) 神经引擎在线",
                en: "🧠 KataGo \(tag) Neural Engine",
                ja: "🧠 KataGo \(tag) ニューラルAI稼働中",
                ko: "🧠 KataGo \(tag) 신경망 엔진 가동",
                zhHant: "🧠 KataGo \(tag) 神經引擎在線"
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

    init(bundle: Bundle = .main, supportedBoardSize: Int = 19, initialPreset: KataGoModelPreset = .defaultPreset) {
        self.bundle = bundle
        self.supportedBoardSize = supportedBoardSize
        self._activePreset = initialPreset
        #if canImport(UIKit)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.evictLoadedModels()
        }
        #endif
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Lightweight non-blocking bundle check for UI badges (never loads `MLModel` on `@MainActor`).
    private func modelURL(for preset: KataGoModelPreset) -> URL? {
        if preset == .b18c384nbt {
            lock.lock()
            let allowed = proModelAvailableForUse
            lock.unlock()
            if !allowed { return nil }
        }
        let subdirectories: [String?] = [nil, "Models", "Resources/Models"]
        let candidateNames: [String] = (preset == .b6c96)
            ? [preset.resourceName, "KataGoPolicyValue", "GoPolicyValueNet"]
            : [preset.resourceName]
        for name in candidateNames {
            for subdir in subdirectories {
                if let url = bundle.url(forResource: name, withExtension: "mlmodelc", subdirectory: subdir) {
                    return url
                }
            }
        }
        return nil
    }

    private func resolvedAvailablePreset() -> KataGoModelPreset? {
        lock.lock()
        let preferred = _activePreset
        if let loaded = activeLoadedModel, loaded.preset == preferred {
            lock.unlock()
            return loaded.preset
        }
        let missing = missingPresets
        lock.unlock()

        let order: [KataGoModelPreset] = [preferred, .b10c128, .b6c96, .b18c384nbt]
        var seen: Set<KataGoModelPreset> = []
        for preset in order where seen.insert(preset).inserted {
            if !missing.contains(preset), modelURL(for: preset) != nil {
                return preset
            }
        }
        return nil
    }

    /// Loads the specified preset if bundled, retaining only one loaded `MLModel` at a time.
    /// Serialized with `loadLock` so concurrent callers never load duplicate 25 MB models or race with preset changes.
    func loadModel(for preset: KataGoModelPreset) -> MLModel? {
        lock.lock()
        if let loaded = activeLoadedModel, loaded.preset == preset {
            lock.unlock()
            return loaded.model
        }
        if missingPresets.contains(preset) {
            lock.unlock()
            return nil
        }
        lock.unlock()

        loadLock.lock()
        defer { loadLock.unlock() }

        // Re-check after acquiring loadLock in case another thread just finished loading it
        lock.lock()
        if let loaded = activeLoadedModel, loaded.preset == preset {
            lock.unlock()
            return loaded.model
        }
        if missingPresets.contains(preset) {
            lock.unlock()
            return nil
        }
        lock.unlock()

        let config = MLModelConfiguration()
        config.computeUnits = .all

        var found: MLModel? = nil
        if let url = modelURL(for: preset),
           let mlModel = try? MLModel(contentsOf: url, configuration: config) {
            found = mlModel
        }

        lock.lock()
        if let found {
            // Only cache if this preset is still active (or fallback when active is missing)
            if _activePreset == preset || activeLoadedModel == nil {
                activeLoadedModel = (preset, found)
            }
        } else {
            missingPresets.insert(preset)
        }
        lock.unlock()
        return found
    }

    private func resolveActiveModel() -> (preset: KataGoModelPreset, model: MLModel)? {
        let preferred = activeModelPreset
        let order: [KataGoModelPreset] = [preferred, .b10c128, .b6c96, .b18c384nbt]
        var seen: Set<KataGoModelPreset> = []
        for preset in order where seen.insert(preset).inserted {
            if let model = loadModel(for: preset) {
                return (preset, model)
            }
        }
        return nil
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
        let decision = await selectMoveDecision(
            for: state,
            color: color,
            level: level,
            ruleSet: ruleSet,
            coachingStyle: coachingStyle
        )
        return decision.action
    }

    /// Runs a synchronous work closure on a background task while preserving structured cancellation from the parent Task.
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

    func selectMoveDecision(
        for state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty,
        ruleSet: GameRuleSet,
        coachingStyle: AICoachingStyle = .standard
    ) async -> AIMoveDecision {
        // Use real KataGo + PUCT MCTS for standard 7x7..19x19 matches from Deer (12K) up to Kirin (5D)!
        // Keep beginner levels (Sprout 25K, Rabbit 20K, Fox 15K), 5x5, Capture Race, and themed drills on LocalMCTSGoEngine.
        if !ruleSet.isCaptureRace,
           coachingStyle == .standard,
           state.size >= 7,
           state.size <= supportedBoardSize,
           let profile = rankProfile(for: level),
           resolvedAvailablePreset() != nil {
            if let decision = await runCancellableBackground({ [self] () -> AIMoveDecision? in
                guard let active = self.resolveActiveModel() else { return nil }
                return self.selectKataGoDecisionSync(model: active.model, state: state, color: color, profile: profile)
            }) {
                return decision
            }
        }

        let action = await fallbackEngine.selectMove(
            for: state,
            color: color,
            level: level,
            ruleSet: ruleSet,
            coachingStyle: coachingStyle
        )
        return AIMoveDecision(action: action)
    }

    func suggestMoves(
        for state: GoBoardState,
        color: StoneColor,
        count: Int
    ) async -> [MoveSuggestion] {
        if state.size >= 7, state.size <= supportedBoardSize, resolvedAvailablePreset() != nil {
            let result = await runCancellableBackground { [self] () -> PositionAnalysis? in
                guard let active = self.resolveActiveModel() else { return nil }
                return self.analyzeWithKataGoSync(model: active.model, state: state, color: color, playouts: 24, maxVariations: max(2, count))
            }
            if let result, !result.topVariations.isEmpty {
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
        if state.size >= 7, state.size <= supportedBoardSize, resolvedAvailablePreset() != nil {
            if let result = await runCancellableBackground({ [self] () -> PositionAnalysis? in
                guard let active = self.resolveActiveModel() else { return nil }
                return self.analyzeWithKataGoSync(model: active.model, state: state, color: color, playouts: 28, maxVariations: maxVariations)
            }) {
                return result
            }
        }
        return await fallbackEngine.analyzePosition(for: state, color: color, maxVariations: maxVariations)
    }

    func analyzeGame(
        initialState: GoBoardState,
        moves: [GoMove]
    ) async -> GameReviewReport {
        if initialState.size >= 7,
           initialState.size <= supportedBoardSize,
           resolvedAvailablePreset() != nil {
            if let report = await runCancellableBackground({ [self] () -> GameReviewReport? in
                guard let active = self.resolveActiveModel() else { return nil }
                return self.analyzeGameWithKataGoSync(model: active.model, initialState: initialState, moves: moves)
            }) {
                return report
            }
        }
        return await fallbackEngine.analyzeGame(initialState: initialState, moves: moves)
    }

    private func analyzeGameWithKataGoSync(
        model: MLModel,
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

        let initialEval = evaluateSync(model: model, state: initialState, color: initialState.currentTurn)
        let initBlackWR: Double = {
            guard let ev = initialEval else { return 0.5 }
            return initialState.currentTurn == .black ? ev.moverWinrate : (1.0 - ev.moverWinrate)
        }()
        let initBlackLead: Double = {
            guard let ev = initialEval else { return 0.0 }
            return initialState.currentTurn == .black ? ev.scoreLeadForMover : -ev.scoreLeadForMover
        }()

        var winrateHistory: [Double] = [initBlackWR]
        var scoreLeadHistory: [Double] = [initBlackLead]
        var reviewed: [ReviewedMove] = []
        reviewed.reserveCapacity(moves.count)

        var prevEval = initialEval
        var prevBlackWR = initBlackWR
        var prevBlackLead = initBlackLead

        for (i, mv) in moves.enumerated() {
            if Task.isCancelled { break }
            let stateBefore = states[i]
            let stateAfter = states[i + 1]

            let beforeEval: KataGoEvalOutput?
            if let cached = prevEval, stateBefore.currentTurn == mv.color {
                beforeEval = cached
            } else {
                beforeEval = evaluateSync(model: model, state: stateBefore, color: mv.color)
            }

            let afterEval = evaluateSync(model: model, state: stateAfter, color: stateAfter.currentTurn)
            let afterBlackWR: Double = {
                guard let ev = afterEval else { return prevBlackWR }
                return stateAfter.currentTurn == .black ? ev.moverWinrate : (1.0 - ev.moverWinrate)
            }()
            let afterBlackLead: Double = {
                guard let ev = afterEval else { return prevBlackLead }
                return stateAfter.currentTurn == .black ? ev.scoreLeadForMover : -ev.scoreLeadForMover
            }()

            let moverWRBefore = mv.color == .black ? prevBlackWR : (1.0 - prevBlackWR)
            let moverWRAfter = mv.color == .black ? afterBlackWR : (1.0 - afterBlackWR)
            let wrDrop = max(0.0, moverWRBefore - moverWRAfter)

            let moverLeadBefore = mv.color == .black ? prevBlackLead : -prevBlackLead
            let moverLeadAfter = mv.color == .black ? afterBlackLead : -afterBlackLead
            let scoreDrop = max(0.0, moverLeadBefore - moverLeadAfter)

            // Build top-3 candidate variations from KataGo policy head at `stateBefore`
            var topVariations: [MoveVariation] = []
            if let bEval = beforeEval {
                let s = stateBefore.size
                let ranked = bEval.boardPolicy.enumerated()
                    .filter { $0.element > 0.005 }
                    .sorted { $0.element > $1.element }
                    .prefix(3)
                for (flatIdx, _) in ranked {
                    let pt = BoardPoint(row: flatIdx / s, col: flatIdx % s)
                    let blackLead = mv.color == .black ? bEval.scoreLeadForMover : -bEval.scoreLeadForMover
                    topVariations.append(
                        MoveVariation(
                            firstMove: pt,
                            winrateForMover: bEval.moverWinrate,
                            scoreLeadForBlack: blackLead,
                            pvMoves: [pt],
                            reason: .bestMove
                        )
                    )
                }
            }

            let bestCoord = topVariations.first?.firstMove.humanLabel(boardSize: stateBefore.size)
            let quality: MoveQuality
            let diagZh: String
            let diagEn: String

            if wrDrop >= 0.14 || scoreDrop >= 6.0 {
                quality = .blunder
                if let bestCoord {
                    diagZh = "这一手损失较大，KataGo 推荐优先考虑 \(bestCoord)。"
                    diagEn = "Big swing here — KataGo strongly recommends \(bestCoord)."
                } else {
                    diagZh = "这一手胜率下滑较明显，可以结合参考变化复盘。"
                    diagEn = "Noticeable winrate drop on this move."
                }
            } else if wrDrop >= 0.07 || scoreDrop >= 3.0 {
                quality = .mistake
                if let bestCoord {
                    diagZh = "稍有缓手，走 \(bestCoord) 会更积极稳健。"
                    diagEn = "A bit slow — \(bestCoord) keeps stronger momentum."
                } else {
                    diagZh = "这里有更积极的选点可以争取主动。"
                    diagEn = "There was a more active continuation here."
                }
            } else if wrDrop >= 0.035 || scoreDrop >= 1.5 {
                quality = .inaccuracy
                if let bestCoord {
                    diagZh = "小瑕疵，参考点 \(bestCoord) 效率略高。"
                    diagEn = "Slight inaccuracy — \(bestCoord) is a touch more efficient."
                } else {
                    diagZh = "细节上还可以更紧凑一些。"
                    diagEn = "A small refinement was available here."
                }
            } else if let best = topVariations.first?.firstMove,
                      case .place(let played) = mv.action,
                      played == best,
                      (moverWRAfter - moverWRBefore) >= 0.02 {
                quality = .brilliant
                diagZh = "精准妙手！完全契合 KataGo 第一选点。"
                diagEn = "Brilliant move! Matches KataGo's top choice."
            } else {
                quality = .good
                diagZh = "稳健好手，保持了局面平衡与步调。"
                diagEn = "Solid move keeping good balance and pace."
            }

            reviewed.append(
                ReviewedMove(
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
                    topVariations: topVariations
                )
            )

            winrateHistory.append(afterBlackWR)
            scoreLeadHistory.append(afterBlackLead)
            prevEval = afterEval
            prevBlackWR = afterBlackWR
            prevBlackLead = afterBlackLead
        }

        return GameReviewReport(
            initialBlackWinrate: initBlackWR,
            winrateHistory: winrateHistory,
            scoreLeadHistory: scoreLeadHistory,
            reviewedMoves: reviewed
        )
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
        let ownershipForMover: [Double]? // length = size * size, +1 = mover, -1 = opponent
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

        // Planes 9..13 / Globals 0..4: Move history (t-1 .. t-5)
        let historyMoves: [MoveAction] = state.recentMoves.isEmpty
            ? (state.lastMove.map { [$0] } ?? [])
            : state.recentMoves
        let histCount = historyMoves.count
        for offset in 0..<min(5, histCount) {
            let action = historyMoves[histCount - 1 - offset]
            switch action {
            case .place(let pt):
                if pt.row < s && pt.col < s {
                    setBin(9 + offset, pt.row, pt.col, 1.0)
                }
            case .pass:
                glPtr[offset] = 1.0
            case .resign:
                break
            }
        }

        // Planes 14 & 17: Working ladder capture / escape features via exact ladder reader
        // (Plane 14: currently in working ladder; Plane 17: working ladder escape move)
        for g in groups where g.liberties.count == 1 && g.stones.count <= 4 {
            if let repIdx = g.stones.first {
                let repPt = state.point(for: repIdx)
                if repPt.row < s && repPt.col < s {
                    if case .captured = GoTacticalReader.readLadderDefenderToMove(state: state, targetStone: repPt, maxDepth: 24) {
                        for stIdx in g.stones {
                            let pt = state.point(for: stIdx)
                            if pt.row < s && pt.col < s {
                                setBin(14, pt.row, pt.col, 1.0)
                            }
                        }
                    }
                }
            }
        }

        // Global 5: selfKomi / 20.0 (from mover's perspective)
        let selfKomi: Float32 = (color == .white) ? Float32(state.komi) : -Float32(state.komi)
        glPtr[5] = selfKomi / 20.0

        // Global 14: passWouldEndPhase (opponent just passed, so passing now ends the game)
        if state.consecutivePasses >= 1 {
            glPtr[14] = 1.0
        }

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
              ]) else {
            return nil
        }

        inferenceLock.lock()
        let output = try? model.prediction(from: provider)
        inferenceLock.unlock()

        guard let output,
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

        // Ownership head -> estimated score lead for mover + per-point ownership map
        var lead = (moverWR - 0.5) * 20.0
        var ownershipForMover: [Double]? = nil
        if let ownArr = output.featureValue(for: "ownership")?.multiArrayValue {
            var ownSum = 0.0
            var ownMap = [Double](repeating: 0.0, count: total)
            for r in 0..<s {
                for c in 0..<s {
                    let idx = r * supportedBoardSize + c
                    if idx < ownArr.count {
                        let raw = ownArr[idx].doubleValue
                        let clamped = min(1.0, max(-1.0, raw.isFinite ? raw : 0.0))
                        ownMap[r * s + c] = clamped
                        ownSum += clamped
                    }
                }
            }
            let selfKomi = (color == .white) ? state.komi : -state.komi
            lead = ownSum + selfKomi
            ownershipForMover = ownMap
        }

        return KataGoEvalOutput(
            boardPolicy: probs,
            passProb: passProb,
            moverWinrate: moverWR,
            scoreLeadForMover: lead,
            ownershipForMover: ownershipForMover
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

        func puctScore(sqrtParentVisits: Double, parentFPU: Double, cPuct: Double = 1.35) -> Double {
            let q = visits > 0 ? (totalValue / Double(visits)) : parentFPU
            let u = cPuct * prior * sqrtParentVisits / (1.0 + Double(visits))
            return q + u
        }
    }

    private func expandNode(
        _ node: PUCTNode,
        model: MLModel,
        maxChildren: Int,
        precomputedEval: KataGoEvalOutput? = nil
    ) -> Double {
        guard let eval = precomputedEval ?? evaluateSync(model: model, state: node.state, color: node.moverToPlay) else {
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
        playouts: Int,
        precomputedRootEval: KataGoEvalOutput? = nil
    ) -> PUCTNode {
        let root = PUCTNode(action: nil, state: state, moverToPlay: color, prior: 1.0)
        let rootCap = state.size >= 13 ? 18 : 14
        let innerCap = 10

        let rootVal = expandNode(root, model: model, maxChildren: rootCap, precomputedEval: precomputedRootEval)
        root.visits = 1
        root.totalValue = 1.0 - rootVal // Stored from parent's perspective (consistent with backpropagation)

        let iterations = max(0, playouts - 1)
        for _ in 0..<iterations {
            if Task.isCancelled { break }
            var current = root
            // 1. Selection
            while current.isExpanded && !current.children.isEmpty {
                let sqrtN = sqrt(Double(max(1, current.visits)))
                // Relative FPU from current mover's perspective (1.0 - current.meanQ)
                let parentMoverQ = 1.0 - current.meanQ
                let parentFPU = max(0.02, parentMoverQ - 0.18)
                var bestChild = current.children[0]
                var bestScore = bestChild.puctScore(sqrtParentVisits: sqrtN, parentFPU: parentFPU)
                for child in current.children.dropFirst() {
                    let sc = child.puctScore(sqrtParentVisits: sqrtN, parentFPU: parentFPU)
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

    /// Returns true if placing at `pt` is a pointless throw into a sealed, unlivable opponent pocket
    /// (e.g. a 2x6 dead strip or deeply settled opponent territory when losing) that neither captures
    /// nor threatens any opponent group.
    private func isHopelessDeadSpaceThrow(
        point pt: BoardPoint,
        state: GoBoardState,
        color: StoneColor,
        hopelessMask: [Bool],
        ownershipForMover: [Double]?,
        moverWinrate: Double
    ) -> Bool {
        let idx = state.index(row: pt.row, col: pt.col)
        let inDeadPocket = idx < hopelessMask.count && hopelessMask[idx]
        let deepOpponentControl: Bool = {
            guard moverWinrate < 0.15,
                  let own = ownershipForMover,
                  idx < own.count,
                  own[idx] < -0.88 else {
                return false
            }
            return true
        }()
        guard inDeadPocket || deepOpponentControl else { return false }

        // Never suppress genuine captures or ataris against weak opponent walls!
        guard case .success(let outcome) = state.applying(action: .place(pt), color: color) else {
            return true
        }
        if !outcome.capturedPoints.isEmpty { return false }
        let opp = color.opposite
        for n in outcome.nextState.neighbors(of: idx) where outcome.nextState.grid[n] == opp {
            if let oppG = outcome.nextState.groupAndLiberties(at: n), oppG.liberties.count == 1 {
                return false
            }
        }
        return true
    }

    private func selectKataGoDecisionSync(
        model: MLModel,
        state: GoBoardState,
        color: StoneColor,
        profile: KataGoRankProfile
    ) -> AIMoveDecision {
        let rootEval = evaluateSync(model: model, state: state, color: color)
        let groups = state.allGroups()
        var groupIndexAt = Array(repeating: -1, count: state.size * state.size)
        for (gIdx, g) in groups.enumerated() {
            for sIdx in g.stones { groupIndexAt[sIdx] = gIdx }
        }
        let hopelessMask = LocalMCTSGoEngine.computeHopelessOpponentPocketMask(
            state: state,
            for: color,
            groups: groups,
            groupIndexAt: groupIndexAt
        )

        // Pure-policy fast path for 12K / 10K (soft temperature sampling from real KataGo policy)
        if profile.playouts <= 1 {
            guard let eval = rootEval else {
                return AIMoveDecision(action: .pass)
            }
            let s = state.size
            var candidates: [(action: MoveAction, prob: Double)] = []
            for i in 0..<(s * s) where eval.boardPolicy[i] > 0.001 {
                let pt = BoardPoint(row: i / s, col: i % s)
                if isHopelessDeadSpaceThrow(
                    point: pt,
                    state: state,
                    color: color,
                    hopelessMask: hopelessMask,
                    ownershipForMover: eval.ownershipForMover,
                    moverWinrate: eval.moverWinrate
                ) {
                    continue
                }
                candidates.append((.place(pt), eval.boardPolicy[i]))
            }
            if eval.passProb > 0.35 || candidates.isEmpty {
                candidates.append((.pass, max(eval.passProb, candidates.isEmpty ? 1.0 : 0.0)))
            }
            candidates.sort { $0.prob > $1.prob }
            let pool = Array(candidates.prefix(max(1, profile.topKCap)))
            let action = sampleWithTemperature(pool: pool, temperature: profile.policyTemperature)
            return AIMoveDecision(
                action: action,
                moverWinrate: eval.moverWinrate,
                moverScoreLead: eval.scoreLeadForMover,
                ownershipForMover: eval.ownershipForMover
            )
        }

        // Full KataGo PUCT MCTS for 5K / 3K / 1D / 3D / 5D (reuse already-computed rootEval!)
        let root = runPUCT(model: model, state: state, color: color, playouts: profile.playouts, precomputedRootEval: rootEval)
        guard !root.children.isEmpty else {
            return AIMoveDecision(
                action: .pass,
                moverWinrate: rootEval?.moverWinrate,
                moverScoreLead: rootEval?.scoreLeadForMover,
                ownershipForMover: rootEval?.ownershipForMover
            )
        }

        let sorted = root.children.sorted { a, b in
            if a.visits != b.visits { return a.visits > b.visits }
            return a.meanQ > b.meanQ
        }
        let effectiveWR = sorted.first?.meanQ ?? rootEval?.moverWinrate ?? 0.5
        let effectiveLead = rootEval?.scoreLeadForMover

        let filtered = sorted.filter { child in
            guard case .place(let pt) = child.action else { return true }
            return !isHopelessDeadSpaceThrow(
                point: pt,
                state: state,
                color: color,
                hopelessMask: hopelessMask,
                ownershipForMover: rootEval?.ownershipForMover,
                moverWinrate: effectiveWR
            )
        }
        guard !filtered.isEmpty else {
            return AIMoveDecision(
                action: .pass,
                moverWinrate: effectiveWR,
                moverScoreLead: effectiveLead,
                ownershipForMover: rootEval?.ownershipForMover
            )
        }

        let chosenAction: MoveAction
        if profile.policyTemperature <= 0.01 || profile.topKCap <= 1 {
            chosenAction = filtered[0].action ?? .pass
        } else {
            let topPool = filtered.prefix(profile.topKCap).map { child in
                (action: child.action ?? .pass, prob: Double(max(1, child.visits)))
            }
            chosenAction = sampleWithTemperature(pool: topPool, temperature: profile.policyTemperature)
        }

        return AIMoveDecision(
            action: chosenAction,
            moverWinrate: effectiveWR,
            moverScoreLead: effectiveLead,
            ownershipForMover: rootEval?.ownershipForMover
        )
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
        let maxProb = max(1e-9, pool.map(\.prob).max() ?? 1.0)
        let weights = pool.map { pow(max(1e-9, $0.prob / maxProb), invT) }
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
        let root = runPUCT(model: model, state: state, color: color, playouts: playouts, precomputedRootEval: eval)
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

        if state.size >= 7, state.size <= supportedBoardSize, resolvedAvailablePreset() != nil {
            return await runCancellableBackground { [self] in
                guard let active = self.resolveActiveModel() else {
                    let fallbackEst = GoScoring.estimateTerritory(state: state, deadStoneIndices: deadStoneIndices)
                    let lead = exactResult.blackScore - exactResult.whiteScore
                    let wr = min(0.99, max(0.01, 1.0 / (1.0 + exp(-lead * 0.25))))
                    return PhotoJudgeEvaluation(
                        gameResult: exactResult,
                        territoryEstimate: fallbackEst,
                        blackWinrate: wr,
                        aiScoreLeadForBlack: lead,
                        suggestedDeadIndices: heuristicDead,
                        usedKataGoNeuralModel: false
                    )
                }
                var evalState = state
                for idx in deadStoneIndices where idx >= 0 && idx < evalState.grid.count {
                    evalState.grid[idx] = nil
                }

                if let neural = self.evaluateOwnershipSync(model: active.model, state: evalState) {
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
            }
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
              ]) else {
            return nil
        }

        inferenceLock.lock()
        let output = try? model.prediction(from: provider)
        inferenceLock.unlock()

        guard let output,
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
