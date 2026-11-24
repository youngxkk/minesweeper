//
//  AppState.swift
//  StarYi Go
//

import Combine
import Foundation
import SwiftUI
import UIKit

enum AppRoute: Hashable {
    case playGame
    case puzzleHub(initialMistakesOnly: Bool)
    case islandDetail(islandId: String)
    case puzzlePlay(puzzleId: String, isDailyChallenge: Bool = false, isStarterBootcamp: Bool = false)
    case puzzleGauntlet(nodeId: String, masteryTier: StageMasteryTier = .normal)
    case puzzleRush
    case seaSkipGate(seaId: String)
    case srsGhostBuster(islandId: String)
    case codex
    case archive
    case reviewGame(recordId: UUID)
    case trainingDojo
    case josekiTrainer(courseId: String, campaignNodeId: String? = nil)
    case miniDrill(kind: MiniDrillKind, campaignNodeId: String? = nil, startOffset: Int = 0, targetCount: Int? = nil)
    case rankExamHall
    case rankExamTest(tier: Int)
    case passport
    case photoJudge
}

@MainActor
final class AppState: ObservableObject {
    @Published var profile: UserProfile
    @Published var familyProfiles: [UserProfile]
    @Published var settings: AppSettings
    private var pendingIslandUnlocks: Set<String> = []
    @Published var puzzleProgress: PuzzleProgressStore
    @Published var savedGames: [SavedGameRecord]
    @Published var photoJudgeHistory: [PhotoJudgeRecord]
    @Published var navigationPath: [AppRoute] = [] {
        didSet { syncMusicMood() }
    }
    @Published var showSettingsSheet: Bool = false
    @Published var showEyeCareAlert: Bool = false
    @Published var newlyUnlockedCodexToast: GoCodexEntry? = nil

    /// Keeps an ongoing game alive so kids can return home and resume seamlessly.
    @Published var activeGameViewModel: GameViewModel?
    @Published var pausedAIMatch: PausedAIMatchSnapshot? = nil

    private let storage: StorageService
    private var eyeCareTimer: Timer?
    private var codexToastTask: Task<Void, Never>?
    private var activeSessionMinutes: Int = 0

    var l10n: L10n {
        L10n(language: settings.language)
    }

    var isDailyChallengeClearedToday: Bool {
        profile.dailyChallengeCompletedStamp == StorageService.todayStamp()
    }

    init(storage: StorageService = .shared) {
        self.storage = storage
        let loadedProfile = storage.loadProfile()
        let loadedFamily = storage.loadFamilyProfiles()
        let loadedSettings = storage.loadSettings()
        let loadedPuzzles = storage.loadPuzzleProgress(for: loadedProfile.id)
        let loadedGames = storage.loadSavedGames()
        let loadedPhotoHistory = storage.loadPhotoJudgeHistory()
        let loadedPausedMatch = storage.loadPausedAIMatch(for: loadedProfile.id)

        self.profile = loadedProfile
        self.familyProfiles = loadedFamily
        self.settings = loadedSettings
        self.puzzleProgress = loadedPuzzles
        self.savedGames = loadedGames
        self.photoJudgeHistory = loadedPhotoHistory
        self.pausedAIMatch = loadedPausedMatch

        syncFeedbackSettings()
        restartEyeCareTimer()
        syncMusicMood()
    }

    // MARK: - Persistence & Multi-Kid Family Profiles

    func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        mutate(&settings)
        storage.saveSettings(settings)
        syncFeedbackSettings()
        restartEyeCareTimer()
    }

    func updateProfile(_ mutate: (inout UserProfile) -> Void) {
        mutate(&profile)
        storage.saveProfile(profile)
        familyProfiles = storage.loadFamilyProfiles()
    }

    func switchProfile(to target: UserProfile) {
        guard target.id != profile.id else { return }
        storage.saveProfile(profile)
        storage.savePuzzleProgress(puzzleProgress, for: profile.id)

        profile = target
        storage.saveProfile(profile)
        pendingIslandUnlocks.removeAll()
        puzzleProgress = storage.loadPuzzleProgress(for: target.id)
        familyProfiles = storage.loadFamilyProfiles()
        pausedAIMatch = storage.loadPausedAIMatch(for: target.id)
        activeGameViewModel = nil
        SoundAndHapticsManager.shared.playUITap()
    }

    func addFamilyProfile(nickname: String, avatarEmoji: String) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? l10n.t("settings.profile.newKidDefault") : trimmed
        let newKid = UserProfile(nickname: finalName, avatarEmoji: avatarEmoji)
        var list = familyProfiles
        list.append(newKid)
        storage.saveFamilyProfiles(list)
        familyProfiles = list
        switchProfile(to: newKid)
    }

    func isThemeUnlocked(_ theme: BoardTheme) -> Bool {
        theme.unlockCoinCost == 0 || profile.unlockedThemeIds.contains(theme.rawValue)
    }

    @discardableResult
    func unlockBoardTheme(_ theme: BoardTheme) -> Bool {
        if isThemeUnlocked(theme) {
            updateSettings { $0.boardTheme = theme }
            return true
        }
        guard profile.starCoins >= theme.unlockCoinCost else {
            SoundAndHapticsManager.shared.playWrong()
            SoundAndHapticsManager.shared.playVoice(.notEnoughCoins, delay: 0.12)
            return false
        }
        updateProfile { p in
            p.starCoins -= theme.unlockCoinCost
            p.unlockedThemeIds.insert(theme.rawValue)
        }
        updateSettings { $0.boardTheme = theme }
        SoundAndHapticsManager.shared.playSuccess()
        SoundAndHapticsManager.shared.playVoice(.shopUnlock, delay: 0.14)
        return true
    }

    func isStoneStyleUnlocked(_ style: StoneStyle) -> Bool {
        if style.unlockCoinCost == 0 && style.bossUnlockIslandId == nil {
            return true
        }
        if profile.unlockedStoneStyleIds.contains(style.rawValue) {
            return true
        }
        if let bossId = style.bossUnlockIslandId, puzzleProgress.defeatedBossIslandIds.contains(bossId) {
            return true
        }
        return false
    }

    @discardableResult
    func unlockStoneStyle(_ style: StoneStyle) -> Bool {
        if isStoneStyleUnlocked(style) {
            updateSettings { $0.stoneStyle = style }
            return true
        }
        guard profile.starCoins >= style.unlockCoinCost else {
            SoundAndHapticsManager.shared.playWrong()
            SoundAndHapticsManager.shared.playVoice(.notEnoughCoins, delay: 0.12)
            return false
        }
        updateProfile { p in
            p.starCoins -= style.unlockCoinCost
            p.unlockedStoneStyleIds.insert(style.rawValue)
        }
        updateSettings { $0.stoneStyle = style }
        SoundAndHapticsManager.shared.playWonderMoment()
        SoundAndHapticsManager.shared.playVoice(.shopUnlock, delay: 0.18)
        return true
    }

    @discardableResult
    func unlockCodexTerm(_ termId: String, showToast: Bool = true) -> GoCodexEntry? {
        guard let entry = GoTermCodex.entry(withId: termId) else { return nil }
        guard !profile.unlockedCodexIds.contains(termId) else { return nil }
        updateProfile { p in
            p.unlockedCodexIds.insert(termId)
            p.starCoins += 5
        }
        if showToast {
            SoundAndHapticsManager.shared.playCodexUnlock()
            SoundAndHapticsManager.shared.playVoice(.codexUnlock, delay: 0.16, interrupt: false)
            withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) {
                newlyUnlockedCodexToast = entry
            }
            codexToastTask?.cancel()
            codexToastTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_400_000_000)
                guard !Task.isCancelled, let self else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    if self.newlyUnlockedCodexToast?.id == entry.id {
                        self.newlyUnlockedCodexToast = nil
                    }
                }
            }
        }
        return entry
    }

    private func syncFeedbackSettings() {
        SoundAndHapticsManager.shared.soundEnabled = settings.soundEnabled
        SoundAndHapticsManager.shared.bgmEnabled = settings.bgmEnabled
        SoundAndHapticsManager.shared.voiceEnabled = settings.voiceEnabled
        SoundAndHapticsManager.shared.voiceLanguageCode = settings.language.isChinese ? "zh" : settings.language.resolvedCode
        SoundAndHapticsManager.shared.zenDojoMode = settings.zenDojoMode
        SoundAndHapticsManager.shared.hapticsEnabled = settings.hapticsEnabled
        SoundAndHapticsManager.shared.updateBGMPlayback()
    }

    func syncMusicMood() {
        guard let last = navigationPath.last else {
            SoundAndHapticsManager.shared.setMusicMood(.island)
            return
        }
        switch last {
        case .playGame:
            if activeGameViewModel?.bossIslandId != nil {
                SoundAndHapticsManager.shared.setMusicMood(.boss)
            } else {
                SoundAndHapticsManager.shared.setMusicMood(.match)
            }
        case .puzzlePlay, .puzzleGauntlet, .puzzleRush, .seaSkipGate, .srsGhostBuster, .reviewGame, .josekiTrainer, .miniDrill, .rankExamTest:
            SoundAndHapticsManager.shared.setMusicMood(.match)
        case .puzzleHub, .islandDetail, .codex, .archive, .trainingDojo, .rankExamHall, .passport, .photoJudge:
            SoundAndHapticsManager.shared.setMusicMood(.island)
        }
    }

    private func restartEyeCareTimer() {
        eyeCareTimer?.invalidate()
        eyeCareTimer = nil
        activeSessionMinutes = 0
        guard settings.eyeCareMinutes > 0 else { return }

        eyeCareTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.activeSessionMinutes += 1
                if self.settings.eyeCareMinutes > 0 && self.activeSessionMinutes >= self.settings.eyeCareMinutes {
                    self.activeSessionMinutes = 0
                    self.showEyeCareAlert = true
                }
            }
        }
    }

    // MARK: - Navigation & Game Launching

    func popRoute() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    func popToHome() {
        navigationPath = []
    }

    func applyAssistPreset(_ preset: AssistPreset) {
        updateSettings { s in
            s.assistPreset = preset
            switch preset {
            case .starter:
                s.showLiveLiberties = true
                s.highlightAtari = true
                s.expressiveStones = true
                s.zenDojoMode = false
            case .intermediate:
                s.showLiveLiberties = false
                s.highlightAtari = true
                s.expressiveStones = false
                s.zenDojoMode = false
            case .examSim:
                s.showLiveLiberties = false
                s.highlightAtari = false
                s.expressiveStones = false
                s.zenDojoMode = true
                s.confirmBeforePlace = true
            case .custom:
                break
            }
        }
    }

    func startNewAIGame(
        boardSize: BoardSize,
        difficulty: AIDifficulty,
        playerColor: StoneColor,
        handicap: Int,
        ruleSet: GameRuleSet = .standard,
        timeControl: TimeControl? = nil,
        scoringRule: ScoringRule? = nil,
        coachingStyle: AICoachingStyle? = nil,
        examTier: Int? = nil
    ) {
        let tc = timeControl ?? settings.preferredTimeControl
        let sr = scoringRule ?? settings.scoringRule
        let cs = coachingStyle ?? settings.preferredCoachingStyle

        if examTier == nil {
            updateSettings {
                $0.preferredBoardSize = boardSize
                $0.preferredDifficulty = difficulty
                $0.preferredPlayerColor = playerColor
                $0.preferredHandicap = handicap
                $0.preferredRuleSet = ruleSet
                $0.preferredTimeControl = tc
                $0.preferredCoachingStyle = cs
            }
        }
        let vm = GameViewModel(
            boardSize: boardSize,
            mode: .vsAI(difficulty: difficulty, playerColor: playerColor),
            ruleSet: ruleSet,
            scoringRule: sr,
            timeControl: tc,
            coachingStyle: cs,
            handicap: ruleSet.isCaptureRace ? 0 : handicap,
            bossIslandId: nil,
            examTier: examTier,
            aiEngine: CoreMLGoAIEngine.shared,
            appState: self
        )
        activeGameViewModel = vm
        navigationPath.append(.playGame)
    }

    func savePausedAIMatch(_ snapshot: PausedAIMatchSnapshot) {
        pausedAIMatch = snapshot
        storage.savePausedAIMatch(snapshot, for: profile.id)
    }

    func clearPausedAIMatch() {
        pausedAIMatch = nil
        storage.savePausedAIMatch(nil, for: profile.id)
    }

    func resumePausedAIMatch() {
        guard let snapshot = pausedAIMatch else { return }
        activeGameViewModel?.setSuspended(true)
        clearPausedAIMatch()
        let vm = GameViewModel(
            resuming: snapshot,
            aiEngine: CoreMLGoAIEngine.shared,
            appState: self
        )
        activeGameViewModel = vm
        if navigationPath.last != .playGame {
            navigationPath.append(.playGame)
        }
    }

    func startRankExamMatch(spec: RankExamSpec) {
        startNewAIGame(
            boardSize: spec.boardSize,
            difficulty: spec.opponentDifficulty,
            playerColor: .black,
            handicap: 0,
            ruleSet: .standard,
            timeControl: spec.timeControl,
            scoringRule: settings.scoringRule,
            coachingStyle: .standard,
            examTier: spec.tier
        )
    }

    func startCaptureRaceQuickPlay(
        boardSize: BoardSize = .five,
        target: Int = 3,
        difficulty: AIDifficulty = .sprout
    ) {
        let vm = GameViewModel(
            boardSize: boardSize,
            mode: .vsAI(difficulty: difficulty, playerColor: .black),
            ruleSet: .captureRace(target: target),
            handicap: 0,
            bossIslandId: nil,
            appState: self
        )
        activeGameViewModel = vm
        navigationPath.append(.playGame)
    }

    func startCampaignBossMatch(island: CampaignIsland) {
        let boss = island.boss
        let vm = GameViewModel(
            boardSize: boss.boardSize,
            mode: .vsAI(difficulty: boss.difficulty, playerColor: .black),
            ruleSet: boss.ruleSet,
            scoringRule: settings.scoringRule,
            timeControl: boss.timeControl,
            coachingStyle: boss.coachingStyle,
            handicap: 0,
            bossIslandId: island.id,
            aiEngine: CoreMLGoAIEngine.shared,
            appState: self
        )
        activeGameViewModel = vm
        navigationPath.append(.playGame)
    }

    func startTacticalScenario(_ scenario: TacticalScenario, campaignNodeId: String? = nil) {
        let ruleSet: GameRuleSet
        if case .captureRace(let target) = scenario.goal {
            ruleSet = .captureRace(target: target)
        } else {
            ruleSet = .standard
        }
        let vm = GameViewModel(
            boardSize: scenario.boardSize,
            mode: .vsAI(difficulty: scenario.opponentDifficulty, playerColor: scenario.playerColor),
            ruleSet: ruleSet,
            scoringRule: .chinese,
            timeControl: .unlimited,
            coachingStyle: scenario.coachingStyle,
            handicap: 0,
            bossIslandId: nil,
            examTier: nil,
            tacticalScenario: scenario,
            campaignNodeId: campaignNodeId,
            aiEngine: CoreMLGoAIEngine.shared,
            appState: self
        )
        activeGameViewModel = vm
        navigationPath.append(.playGame)
    }

    func startIslandBossMatch(island: GoIsland) {
        let vm = GameViewModel(
            boardSize: .nine,
            mode: .vsAI(difficulty: island.bossDifficulty, playerColor: .black),
            ruleSet: .standard,
            handicap: 0,
            bossIslandId: island.id,
            appState: self
        )
        activeGameViewModel = vm
        navigationPath.append(.playGame)
    }

    /// Backwards-compatible helper
    func startIslandBossMatch(difficulty: AIDifficulty) {
        if let matched = StarYiIslands.allIslands.first(where: { $0.bossDifficulty == difficulty }) {
            startIslandBossMatch(island: matched)
        } else {
            let vm = GameViewModel(
                boardSize: .nine,
                mode: .vsAI(difficulty: difficulty, playerColor: .black),
                ruleSet: .standard,
                handicap: 0,
                appState: self
            )
            activeGameViewModel = vm
            navigationPath.append(.playGame)
        }
    }

    func startTwoPlayerGame(boardSize: BoardSize, handicap: Int = 0, ruleSet: GameRuleSet = .standard) {
        let vm = GameViewModel(
            boardSize: boardSize,
            mode: .twoPlayer,
            ruleSet: ruleSet,
            scoringRule: settings.scoringRule,
            timeControl: settings.preferredTimeControl,
            handicap: ruleSet.isCaptureRace ? 0 : handicap,
            aiEngine: CoreMLGoAIEngine.shared,
            appState: self
        )
        activeGameViewModel = vm
        navigationPath.append(.playGame)
    }

    func resumeActiveGame() {
        guard activeGameViewModel != nil else { return }
        navigationPath.append(.playGame)
    }

    // MARK: - Progress, Rewards, Streaks & Archive Recording

    private func advanceDailyStreak(_ p: inout UserProfile) {
        let today = StorageService.todayStamp()
        if p.lastStreakDateStamp != today {
            if p.lastStreakDateStamp == StorageService.yesterdayStamp() {
                p.dailyStreak += 1
            } else {
                p.dailyStreak = 1
            }
            p.lastStreakDateStamp = today
        }
        p.dailyDateStamp = today
        p.dailyCompletedCount += 1
    }

    func recordPuzzleSolved(
        puzzleId: String,
        stars: Int,
        isDailyChallenge: Bool = false,
        isStarterBootcamp: Bool = false
    ) -> GoCodexEntry? {
        let clamped = max(1, min(3, stars))
        let existing: Int
        if isStarterBootcamp {
            existing = puzzleProgress.starterBootcampStars[puzzleId] ?? 0
            if clamped > existing {
                puzzleProgress.starterBootcampStars[puzzleId] = clamped
            }
        } else {
            existing = puzzleProgress.starsByPuzzleId[puzzleId] ?? 0
            if existing == 0 {
                let previouslyLocked = StarYiIslands.allIslands.filter {
                    !StarYiIslands.unlockState(for: $0, progress: puzzleProgress).isUnlocked
                }
                let previouslyLockedCampaign = StarYiCampaign.allIslands.filter {
                    !StarYiCampaign.unlockState(for: $0, progress: puzzleProgress).isUnlocked
                }
                puzzleProgress.starsByPuzzleId[puzzleId] = clamped
                for island in previouslyLocked where StarYiIslands.unlockState(for: island, progress: puzzleProgress).isUnlocked {
                    pendingIslandUnlocks.insert(island.id)
                }
                for island in previouslyLockedCampaign where StarYiCampaign.unlockState(for: island, progress: puzzleProgress).isUnlocked {
                    pendingIslandUnlocks.insert(island.id)
                }
            } else if clamped > existing {
                puzzleProgress.starsByPuzzleId[puzzleId] = clamped
            }
            // Spaced-Repetition (SRS) Mistake Book progression: 1d -> 3d -> 7d -> Mastered!
            if let srsIdx = puzzleProgress.srsMistakeItems.firstIndex(where: { $0.puzzleId == puzzleId }) {
                if let nextItem = puzzleProgress.srsMistakeItems[srsIdx].advancingOnCorrect() {
                    puzzleProgress.srsMistakeItems[srsIdx] = nextItem
                } else {
                    puzzleProgress.srsMistakeItems.remove(at: srsIdx)
                    puzzleProgress.mistakeBookIds.removeAll { $0 == puzzleId }
                }
            } else {
                puzzleProgress.mistakeBookIds.removeAll { $0 == puzzleId }
            }
        }
        storage.savePuzzleProgress(puzzleProgress, for: profile.id)

        let coinReward = (existing == 0 ? 15 : 4) + (isDailyChallenge ? 15 : 0) + (clamped == 3 ? 5 : 0)
        updateProfile { p in
            p.xp += (existing == 0 ? 25 : 8) + (isDailyChallenge ? 20 : 0)
            p.starCoins += coinReward
            advanceDailyStreak(&p)
            if isDailyChallenge {
                p.dailyChallengeCompletedStamp = StorageService.todayStamp()
            }
        }

        if let termId = GoTermCodex.codexTermId(forPuzzleId: puzzleId) {
            return unlockCodexTerm(termId, showToast: true)
        }
        return nil
    }

    func consumeIslandUnlocks() -> Set<String> {
        let unlocked = pendingIslandUnlocks
        pendingIslandUnlocks.removeAll()
        return unlocked
    }

    func recordCampaignNodeCleared(
        nodeId: String,
        stars: Int,
        masteryTier: StageMasteryTier
    ) {
        let clampedStars = max(1, min(3, stars))
        let prevStars = puzzleProgress.campaignNodeStars[nodeId] ?? 0
        let prevTier = puzzleProgress.campaignNodeMasteryTier[nodeId] ?? 0

        let previouslyLockedIslands = StarYiCampaign.allIslands.filter {
            !StarYiCampaign.unlockState(for: $0, progress: puzzleProgress).isUnlocked
        }

        if clampedStars > prevStars {
            puzzleProgress.campaignNodeStars[nodeId] = clampedStars
        }
        if masteryTier.rawValue > prevTier {
            puzzleProgress.campaignNodeMasteryTier[nodeId] = masteryTier.rawValue
        }

        for island in previouslyLockedIslands where StarYiCampaign.unlockState(for: island, progress: puzzleProgress).isUnlocked {
            pendingIslandUnlocks.insert(island.id)
        }

        storage.savePuzzleProgress(puzzleProgress, for: profile.id)

        let tierBonus = masteryTier == .examCrown ? 25 : (masteryTier == .transformed ? 12 : 0)
        let coinReward = (prevStars == 0 ? 25 : 8) + tierBonus + (clampedStars == 3 ? 10 : 0)
        updateProfile { p in
            p.xp += (prevStars == 0 ? 40 : 12) + tierBonus
            p.starCoins += coinReward
            advanceDailyStreak(&p)
        }

        // Report campaign star milestone to Apple Game Center
        GameCenterService.shared.reportCampaignStars(puzzleProgress.totalCampaignStars)
    }

    func unlockSeaViaSkipGate(seaId: String) {
        guard let targetSea = StarYiCampaign.sea(withId: seaId) else { return }
        // Unlock target sea and all preceding seas so player isn't blocked from replaying earlier content
        for sea in StarYiCampaign.allSeas where sea.index <= targetSea.index {
            puzzleProgress.unlockedSeaIds.insert(sea.id)
        }
        puzzleProgress.didCompletePlacement = true
        storage.savePuzzleProgress(puzzleProgress, for: profile.id)
        updateProfile { p in
            p.xp += 60
            p.starCoins += 40
            advanceDailyStreak(&p)
        }
    }

    func applyPlacementChoice(_ option: PlacementOption) {
        if let targetSea = StarYiCampaign.sea(withId: option.targetSeaId) {
            for sea in StarYiCampaign.allSeas where sea.index <= targetSea.index {
                puzzleProgress.unlockedSeaIds.insert(sea.id)
            }
        }
        puzzleProgress.didCompletePlacement = true
        storage.savePuzzleProgress(puzzleProgress, for: profile.id)
        if option.recommendedRankTier > profile.certifiedRankTier {
            updateProfile { p in
                p.certifiedRankTier = option.recommendedRankTier
            }
        }
        switch option.id {
        case "pl-30k":
            settings.preferredBoardSize = .nine
            settings.preferredDifficulty = .sprout
        case "pl-18k":
            settings.preferredBoardSize = .thirteen
            settings.preferredDifficulty = .fox
        case "pl-10k":
            settings.preferredBoardSize = .thirteen
            settings.preferredDifficulty = .panda
        case "pl-1d":
            settings.preferredBoardSize = .nineteen
            settings.preferredDifficulty = .dragon
        default:
            break
        }
        storage.saveSettings(settings)
    }

    func markPlacementDismissed() {
        guard !puzzleProgress.didCompletePlacement else { return }
        puzzleProgress.didCompletePlacement = true
        storage.savePuzzleProgress(puzzleProgress, for: profile.id)
    }

    func recordPuzzleRushRun(score: Int, highestRankBadge: String) {
        let isNewRecord = score > puzzleProgress.bestPuzzleRushScore
        if isNewRecord {
            puzzleProgress.bestPuzzleRushScore = score
            puzzleProgress.bestPuzzleRushRank = highestRankBadge
        }
        storage.savePuzzleProgress(puzzleProgress, for: profile.id)
        updateProfile { p in
            p.xp += max(10, score * 6)
            p.starCoins += max(5, score * 3) + (isNewRecord && score >= 5 ? 20 : 0)
            advanceDailyStreak(&p)
        }

        GameCenterService.shared.reportPuzzleRushScore(score)
    }

    func adaptiveDailyPuzzle(for date: Date = Date()) -> GoPuzzle {
        PuzzlePackLoader.rankAdaptiveDailyPuzzle(for: date, certifiedRankTier: profile.certifiedRankTier)
    }

    func recordPuzzleMistake(puzzleId: String, isStarterBootcamp: Bool = false) {
        guard !isStarterBootcamp else { return }
        if !puzzleProgress.mistakeBookIds.contains(puzzleId) {
            puzzleProgress.mistakeBookIds.append(puzzleId)
        }
        if let idx = puzzleProgress.srsMistakeItems.firstIndex(where: { $0.puzzleId == puzzleId }) {
            puzzleProgress.srsMistakeItems[idx] = SRSMistakeItem.initial(puzzleId: puzzleId)
        } else {
            puzzleProgress.srsMistakeItems.append(SRSMistakeItem.initial(puzzleId: puzzleId))
        }
        storage.savePuzzleProgress(puzzleProgress, for: profile.id)
    }

    func addPersonalBlunderPuzzle(_ puzzle: GoPuzzle) {
        if !puzzleProgress.customMistakePuzzles.contains(where: { $0.id == puzzle.id }) {
            puzzleProgress.customMistakePuzzles.insert(puzzle, at: 0)
            if puzzleProgress.customMistakePuzzles.count > 50 {
                puzzleProgress.customMistakePuzzles = Array(puzzleProgress.customMistakePuzzles.prefix(50))
            }
        }
        recordPuzzleMistake(puzzleId: puzzle.id, isStarterBootcamp: false)
    }

    func markJosekiCompleted(_ courseId: String) {
        let isNew = puzzleProgress.completedJosekiIds.insert(courseId).inserted
        storage.savePuzzleProgress(puzzleProgress, for: profile.id)
        updateProfile { p in
            p.xp += isNew ? 35 : 10
            p.starCoins += isNew ? 20 : 5
            advanceDailyStreak(&p)
        }
    }

    func recordExamWrittenPass(tier: Int) {
        puzzleProgress.rankExamRecord.writtenPassedTiers.insert(tier)
        checkAndCertifyExamRank(tier: tier)
        storage.savePuzzleProgress(puzzleProgress, for: profile.id)
        updateProfile { p in
            p.xp += 45
            p.starCoins += 25
            advanceDailyStreak(&p)
        }
    }

    func recordExamMatchResult(tier: Int, didWin: Bool) {
        guard let spec = RankExamSystem.spec(for: tier) else { return }
        var history = puzzleProgress.rankExamRecord.matchHistoryByTier[tier] ?? []
        if history.count >= spec.matchSeriesLength {
            history = []
        }
        history.append(didWin)
        puzzleProgress.rankExamRecord.matchHistoryByTier[tier] = history
        checkAndCertifyExamRank(tier: tier)
        storage.savePuzzleProgress(puzzleProgress, for: profile.id)
    }

    private func checkAndCertifyExamRank(tier: Int) {
        guard let spec = RankExamSystem.spec(for: tier) else { return }
        if puzzleProgress.rankExamRecord.isFullyCertified(spec) {
            if puzzleProgress.rankExamRecord.certifiedDateByTier[tier] == nil {
                puzzleProgress.rankExamRecord.certifiedDateByTier[tier] = Date()
            }
            if tier > profile.certifiedRankTier {
                updateProfile { p in
                    p.certifiedRankTier = tier
                    p.starCoins += 60
                    p.xp += 100
                }
            }
        }
    }

    func findAnyPuzzle(withId id: String) -> GoPuzzle? {
        if let custom = puzzleProgress.customMistakePuzzles.first(where: { $0.id == id }) {
            return custom
        }
        if let dojo = DojoPuzzleBank.findPuzzle(withId: id) {
            return dojo
        }
        return StarYiIslands.findAnyPuzzle(withId: id)
    }

    func saveCompletedGame(
        _ record: SavedGameRecord,
        didHumanWin: Bool,
        capturesByHuman: Int,
        opponentDifficulty: AIDifficulty? = nil,
        bossIslandId: String? = nil
    ) {
        savedGames.insert(record, at: 0)
        if savedGames.count > 100 {
            savedGames = Array(savedGames.prefix(100))
        }
        storage.saveSavedGames(savedGames)

        var defeatedNewBoss = false
        var bossRewardStyle: StoneStyle? = nil
        if didHumanWin, let bossId = bossIslandId {
            let previouslyLockedCampaign = StarYiCampaign.allIslands.filter {
                !StarYiCampaign.unlockState(for: $0, progress: puzzleProgress).isUnlocked
            }
            if !puzzleProgress.defeatedBossIslandIds.contains(bossId) {
                puzzleProgress.defeatedBossIslandIds.insert(bossId)
                storage.savePuzzleProgress(puzzleProgress, for: profile.id)
                defeatedNewBoss = true
            }
            for island in previouslyLockedCampaign where StarYiCampaign.unlockState(for: island, progress: puzzleProgress).isUnlocked {
                pendingIslandUnlocks.insert(island.id)
            }
            if let reward = StoneStyle.allCases.first(where: { $0.bossUnlockIslandId == bossId }) {
                bossRewardStyle = reward
            }
            // Report Sea-clear Game Center achievements for Sea Bosses
            if bossId == "s1-lighthouse" {
                GameCenterService.shared.reportAchievement(id: GameCenterService.AchievementID.sea1Cleared, percentComplete: 100)
            } else if bossId == "s2-summit" {
                GameCenterService.shared.reportAchievement(id: GameCenterService.AchievementID.sea2Cleared, percentComplete: 100)
            } else if bossId == "s3-sanctum" {
                GameCenterService.shared.reportAchievement(id: GameCenterService.AchievementID.sea3Cleared, percentComplete: 100)
            } else if bossId == "s4-zenith" {
                GameCenterService.shared.reportAchievement(id: GameCenterService.AchievementID.sea4Cleared, percentComplete: 100)
            }
        }

        let isEarlyResignation = !didHumanWin && record.moveCount < 10 && record.resultString.hasSuffix("+R")
        if !isEarlyResignation {
            updateProfile { p in
                p.xp += didHumanWin ? (defeatedNewBoss ? 80 : 40) : 15
                p.starCoins += didHumanWin ? (defeatedNewBoss ? 50 : 20) : 8
                if let reward = bossRewardStyle {
                    p.unlockedStoneStyleIds.insert(reward.rawValue)
                }
                if didHumanWin {
                    p.totalWins += 1
                    // Dual-track authentic rank upgrade: defeating a master certifies your real Go rank!
                    if let diff = opponentDifficulty, diff.certifiedRankTier > p.certifiedRankTier {
                        p.certifiedRankTier = diff.certifiedRankTier
                    }
                    if p.certifiedRankTier >= 6 {
                        GameCenterService.shared.reportAchievement(id: GameCenterService.AchievementID.certifiedShodan, percentComplete: 100)
                    }
                }
                p.totalCaptures += capturesByHuman
                advanceDailyStreak(&p)
            }
        }
        if defeatedNewBoss && bossRewardStyle != nil {
            SoundAndHapticsManager.shared.playWonderMoment()
        }
    }

    func deleteSavedGame(id: UUID) {
        savedGames.removeAll { $0.id == id }
        storage.saveSavedGames(savedGames)
    }

    // MARK: - Photo Judge History (max 100 records)

    @discardableResult
    func upsertPhotoJudgeRecord(_ record: PhotoJudgeRecord, warpedImage: UIImage? = nil) -> PhotoJudgeRecord {
        var updated = record
        if let warpedImage {
            if let filename = storage.savePhotoJudgeImage(warpedImage, for: record.id) {
                updated.imageFilename = filename
            }
        }

        if let existingIdx = photoJudgeHistory.firstIndex(where: { $0.id == record.id }) {
            let existing = photoJudgeHistory[existingIdx]
            if updated.imageFilename == nil {
                updated.imageFilename = existing.imageFilename
            }
            photoJudgeHistory[existingIdx] = updated
        } else {
            photoJudgeHistory.insert(updated, at: 0)
            if photoJudgeHistory.count > PhotoJudgeRecord.maxStoredCount {
                let evicted = photoJudgeHistory.dropFirst(PhotoJudgeRecord.maxStoredCount)
                for old in evicted {
                    storage.deletePhotoJudgeImage(filename: old.imageFilename)
                }
                photoJudgeHistory = Array(photoJudgeHistory.prefix(PhotoJudgeRecord.maxStoredCount))
            }
        }

        storage.savePhotoJudgeHistory(photoJudgeHistory)
        return updated
    }

    func deletePhotoJudgeRecord(id: UUID) {
        if let existing = photoJudgeHistory.first(where: { $0.id == id }) {
            storage.deletePhotoJudgeImage(filename: existing.imageFilename)
        }
        photoJudgeHistory.removeAll { $0.id == id }
        storage.savePhotoJudgeHistory(photoJudgeHistory)
    }

    func clearPhotoJudgeHistory() {
        for record in photoJudgeHistory {
            storage.deletePhotoJudgeImage(filename: record.imageFilename)
        }
        photoJudgeHistory.removeAll()
        storage.savePhotoJudgeHistory(photoJudgeHistory)
    }

    func loadPhotoJudgeImage(for record: PhotoJudgeRecord) -> UIImage? {
        storage.loadPhotoJudgeImage(filename: record.imageFilename)
    }

    func findGameRecord(id: UUID) -> SavedGameRecord? {
        if let saved = savedGames.first(where: { $0.id == id }) {
            return saved
        }
        return BuiltInClassicGames.records(l10n: l10n).first(where: { $0.id == id })
    }

    func nextUnsolvedPuzzle() -> GoPuzzle {
        StarYiIslands.orderedPuzzles.first { (puzzleProgress.starsByPuzzleId[$0.id] ?? 0) == 0 }
            ?? StarYiIslands.orderedPuzzles[0]
    }
}
