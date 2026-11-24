//
//  GameCenterService.swift
//  StarYi Go — Kid-Safe Global Leaderboards, Achievements, Dashboard & Turn-Based Friend Match via Apple GameKit
//

import Foundation
import GameKit
import UIKit

@MainActor
final class GameCenterService: NSObject, ObservableObject, GKGameCenterControllerDelegate, GKTurnBasedMatchmakerViewControllerDelegate {
    static let shared = GameCenterService()

    enum LeaderboardID {
        static let puzzleRushWeekly = "staryigo.leaderboard.puzzlerush.weekly"
        static let totalCampaignStars = "staryigo.leaderboard.campaign.stars"
        static let totalWins = "staryigo.leaderboard.matches.wins"
    }

    enum AchievementID {
        static let firstVictory = "staryigo.achievement.firstwin"
        static let sea1Cleared = "staryigo.achievement.sea1"
        static let sea2Cleared = "staryigo.achievement.sea2"
        static let sea3Cleared = "staryigo.achievement.sea3"
        static let sea4Cleared = "staryigo.achievement.sea4"
        static let puzzleRush15 = "staryigo.achievement.rush15"
        static let certifiedShodan = "staryigo.achievement.shodan"
        static let dailyStreak7 = "staryigo.achievement.streak7"
        static let codexScholar = "staryigo.achievement.codex20"
    }

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var playerDisplayName: String? = nil
    @Published private(set) var isUnderage: Bool = false
    @Published private(set) var isMultiplayerRestricted: Bool = false
    @Published private(set) var lastStatusMessage: String? = nil

    private var didAttemptAuth = false
    private var pendingAuthViewController: UIViewController? = nil

    private override init() {
        super.init()
    }

    /// Safely authenticates Game Center without interfering with automated UI tests.
    func authenticateIfNeeded(presentLoginIfNeeded: Bool = false) {
        if ProcessInfo.processInfo.environment["STARYIGO_UI_TEST_SUITE"] != nil {
            return
        }
        if presentLoginIfNeeded, let authVC = pendingAuthViewController {
            presentTopViewController(authVC)
            pendingAuthViewController = nil
            return
        }
        guard !didAttemptAuth else { return }
        didAttemptAuth = true

        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let vc = viewController {
                    self.pendingAuthViewController = vc
                    self.isAuthenticated = false
                    if presentLoginIfNeeded {
                        self.presentTopViewController(vc)
                        self.pendingAuthViewController = nil
                    }
                    return
                }
                if error == nil && GKLocalPlayer.local.isAuthenticated {
                    self.isAuthenticated = true
                    self.playerDisplayName = GKLocalPlayer.local.displayName
                    self.isUnderage = GKLocalPlayer.local.isUnderage
                    self.isMultiplayerRestricted = GKLocalPlayer.local.isMultiplayerGamingRestricted
                    self.pendingAuthViewController = nil
                    self.configureAccessPoint(active: false)
                } else {
                    self.isAuthenticated = false
                }
            }
        }
    }

    /// Configures Apple's native floating Game Center Access Point (kept hidden during board gameplay).
    func configureAccessPoint(active: Bool) {
        guard ProcessInfo.processInfo.environment["STARYIGO_UI_TEST_SUITE"] == nil else { return }
        GKAccessPoint.shared.location = .topTrailing
        GKAccessPoint.shared.showHighlights = true
        GKAccessPoint.shared.isActive = active && isAuthenticated
    }

    /// Syncs local profile & campaign milestones to Game Center whenever authenticated.
    func syncAllProgress(profile: UserProfile, puzzleProgress: PuzzleProgressStore) {
        guard isAuthenticated else { return }
        if puzzleProgress.bestPuzzleRushScore > 0 {
            reportPuzzleRushScore(puzzleProgress.bestPuzzleRushScore)
        }
        if puzzleProgress.totalStars > 0 {
            reportCampaignStars(puzzleProgress.totalStars)
        }
        if profile.totalWins > 0 {
            GKLeaderboard.submitScore(profile.totalWins, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [LeaderboardID.totalWins]) { _ in }
            reportAchievement(id: AchievementID.firstVictory, percentComplete: 100)
        }
        if profile.dailyStreak > 0 {
            let pct = min(100.0, (Double(profile.dailyStreak) / 7.0) * 100.0)
            reportAchievement(id: AchievementID.dailyStreak7, percentComplete: pct)
        }
        if profile.unlockedCodexIds.count > 0 {
            let pct = min(100.0, (Double(profile.unlockedCodexIds.count) / 20.0) * 100.0)
            reportAchievement(id: AchievementID.codexScholar, percentComplete: pct)
        }
        if profile.certifiedRankTier >= 6 {
            reportAchievement(id: AchievementID.certifiedShodan, percentComplete: 100)
        }
    }

    func reportPuzzleRushScore(_ score: Int) {
        guard isAuthenticated, score > 0 else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [LeaderboardID.puzzleRushWeekly]) { _ in }
        let pct = min(100.0, (Double(score) / 15.0) * 100.0)
        reportAchievement(id: AchievementID.puzzleRush15, percentComplete: pct)
    }

    func reportCampaignStars(_ stars: Int) {
        guard isAuthenticated, stars > 0 else { return }
        GKLeaderboard.submitScore(stars, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [LeaderboardID.totalCampaignStars]) { _ in }
    }

    func reportAchievement(id: String, percentComplete: Double) {
        guard isAuthenticated else { return }
        let ach = GKAchievement(identifier: id)
        ach.percentComplete = min(100, max(0, percentComplete))
        ach.showsCompletionBanner = true
        GKAchievement.report([ach]) { _ in }
    }

    // MARK: - Native Game Center UI Sheets

    func presentDashboard() {
        presentGameCenter(state: .dashboard)
    }

    func presentLeaderboards() {
        presentGameCenter(state: .leaderboards)
    }

    func presentAchievements() {
        presentGameCenter(state: .achievements)
    }

    private func presentGameCenter(state: GKGameCenterViewControllerState) {
        authenticateIfNeeded(presentLoginIfNeeded: true)
        guard isAuthenticated else { return }
        let vc = GKGameCenterViewController(state: state)
        vc.gameCenterDelegate = self
        presentTopViewController(vc)
    }

    /// Presents Apple's Kid-Safe Turn-Based Matchmaker for async friend matches (zero free-text chat).
    func presentTurnBasedFriendMatch() {
        authenticateIfNeeded(presentLoginIfNeeded: true)
        guard isAuthenticated, !isMultiplayerRestricted else { return }
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        let mmvc = GKTurnBasedMatchmakerViewController(matchRequest: request)
        mmvc.turnBasedMatchmakerDelegate = self
        presentTopViewController(mmvc)
    }

    private func presentTopViewController(_ vc: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(vc, animated: true)
    }

    // MARK: - Delegates

    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in
            gameCenterViewController.dismiss(animated: true)
        }
    }

    nonisolated func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) {
        Task { @MainActor in
            viewController.dismiss(animated: true)
        }
    }

    nonisolated func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: Error) {
        Task { @MainActor in
            self.lastStatusMessage = error.localizedDescription
            viewController.dismiss(animated: true)
        }
    }
}
