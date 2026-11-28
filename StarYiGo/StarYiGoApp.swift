//
//  StarYiGoApp.swift
//  StarYi Go
//

import SwiftUI
import UIKit

final class StarYiAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .landscape
    }
}

@main
struct StarYiGoApp: App {
    @UIApplicationDelegateAdaptor(StarYiAppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState

    init() {
        AppFont.registerBundledFonts()
        #if DEBUG
        if let suite = ProcessInfo.processInfo.environment["STARYIGO_UI_TEST_SUITE"],
           suite.hasPrefix("StarYiGoUITests."),
           let defaults = UserDefaults(suiteName: suite) {
            _appState = StateObject(wrappedValue: AppState(storage: StorageService(defaults: defaults)))
            return
        }
        #endif
        _appState = StateObject(wrappedValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .environmentObject(appState)
                .environment(\.locale, appState.settings.language.locale)
                .font(AppFont.rounded(size: 16, weight: .semibold, languageCode: appState.settings.language.resolvedCode))
                .preferredColorScheme(.light)
        }
    }
}

struct HomeLogoFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 0 && next.height > 0 {
            value = next
        }
    }
}

struct RootNavigationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Namespace private var zoomTransitionNamespace

    @State private var splashMorphToHome: Bool = false
    @State private var isWindowPortrait: Bool = false
    @State private var showPortraitOverlay: Bool = false
    @State private var dismissedPortraitForCurrentSession: Bool = false
    @State private var portraitDebounceTask: Task<Void, Never>?

    private var l10n: L10n { appState.l10n }

    var body: some View {
        ZStack(alignment: .top) {
            NavigationStack(path: $appState.navigationPath) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .playGame:
                            if let vm = appState.activeGameViewModel {
                                GamePlayView(viewModel: vm)
                                    .id(ObjectIdentifier(vm))
                            } else {
                                HomeView()
                            }
                        case .puzzleHub(let initialMistakesOnly):
                            if initialMistakesOnly {
                                MistakeBookView()
                            } else {
                                PuzzleHubView(initialMistakesOnly: false)
                            }
                        case .mistakeBook:
                            MistakeBookView()
                        case .islandDetail(let islandId):
                            if let campaignIsland = StarYiCampaign.island(withId: islandId) {
                                IslandDetailView(campaignIsland: campaignIsland)
                                    .id(route)
                            } else if let legacy = StarYiIslands.island(withId: islandId),
                                      let fallback = StarYiCampaign.allIslands.first {
                                IslandDetailView(campaignIsland: StarYiCampaign.island(withId: legacy.id) ?? fallback)
                                    .id(route)
                            } else {
                                PuzzleHubView(initialMistakesOnly: false)
                            }
                        case .puzzlePlay(let puzzleId, let isDailyChallenge, let isStarterBootcamp, let forceRandomTransform, let dailyDojoQueueIds):
                            if let puzzle = appState.findAnyPuzzle(withId: puzzleId) {
                                PuzzlePlayView(
                                    puzzle: puzzle,
                                    appState: appState,
                                    isDailyChallenge: isDailyChallenge,
                                    isStarterBootcamp: isStarterBootcamp,
                                    forceRandomTransform: forceRandomTransform,
                                    dailyDojoQueueIds: dailyDojoQueueIds
                                )
                                .id(route)
                            } else {
                                PuzzleHubView(initialMistakesOnly: false)
                            }
                        case .puzzleGauntlet(let nodeId, let masteryTier, let sectionIndex):
                            if let node = StarYiCampaign.node(withId: nodeId),
                               case .puzzleGauntlet(_, let forceExam) = node.kind {
                                let resolvedSection = sectionIndex ?? StarYiCampaign.nextSectionIndex(for: node, progress: appState.puzzleProgress)
                                let ids = node.puzzleIds(forSection: resolvedSection)
                                let list = ids.compactMap { appState.findAnyPuzzle(withId: $0) }
                                let effectiveTier: StageMasteryTier = forceExam ? max(masteryTier, .examCrown) : masteryTier
                                PuzzleGauntletView(
                                    titleZh: node.titleZh,
                                    titleEn: node.titleEn,
                                    puzzles: list.isEmpty ? [BuiltInPuzzleLibrary.allPuzzles[0]] : list,
                                    campaignNodeId: node.id,
                                    masteryTier: effectiveTier,
                                    isGhostBuster: false,
                                    sectionIndex: resolvedSection,
                                    totalSections: node.sectionCount
                                )
                                .id("\(node.id)#\(effectiveTier.rawValue)#\(resolvedSection)")
                            } else {
                                PuzzleHubView(initialMistakesOnly: false)
                            }
                        case .puzzleRush:
                            PuzzleRushView()
                        case .seaSkipGate(let seaId):
                            if let sea = StarYiCampaign.sea(withId: seaId) {
                                SeaSkipGateView(sea: sea)
                                    .id(route)
                            } else {
                                PuzzleHubView(initialMistakesOnly: false)
                            }
                        case .srsGhostBuster(let islandId):
                            if let island = StarYiCampaign.island(withId: islandId) {
                                let ghosts = StarYiCampaign.dueMistakeGhosts(for: island, progress: appState.puzzleProgress)
                                let list = ghosts.compactMap { appState.findAnyPuzzle(withId: $0.puzzleId) }
                                PuzzleGauntletView(
                                    titleZh: "\(island.nameZh) · 错题幽灵战",
                                    titleEn: "\(island.nameEn) · Ghost Buster",
                                    puzzles: list.isEmpty ? [BuiltInPuzzleLibrary.allPuzzles[0]] : list,
                                    campaignNodeId: nil,
                                    masteryTier: .transformed,
                                    isGhostBuster: true
                                )
                                .id(route)
                            } else {
                                PuzzleHubView(initialMistakesOnly: false)
                            }
                        case .codex:
                            GoCodexView()
                        case .archive:
                            GameArchiveView()
                        case .reviewGame(let recordId):
                            if let record = appState.findGameRecord(id: recordId) {
                                GameReviewView(record: record)
                                    .navigationTransition(.zoom(sourceID: recordId, in: zoomTransitionNamespace))
                            } else {
                                GameArchiveView()
                            }
                        case .trainingDojo:
                            TrainingDojoView()
                        case .dailyDojo:
                            DailyDojoView()
                        case .dailyKnowledge:
                            DailyKnowledgeQuizView()
                        case .josekiTrainer(let courseId, let campaignNodeId):
                            if let course = JosekiLibrary.course(withId: courseId) {
                                JosekiTrainerView(course: course, campaignNodeId: campaignNodeId)
                                    .id(route)
                            } else {
                                TrainingDojoView()
                            }
                        case .miniDrill(let kind, let campaignNodeId, let startOffset, let targetCount, let isDailyDojoWarmup):
                            GoMiniDrillPlayView(
                                kind: kind,
                                campaignNodeId: campaignNodeId,
                                startOffset: startOffset,
                                targetQuestionCount: targetCount,
                                isDailyDojoWarmup: isDailyDojoWarmup
                            )
                            .id(route)
                        case .rankExamHall:
                            RankExamHallView()
                        case .rankExamTest(let tier):
                            if let spec = RankExamSystem.spec(for: tier) {
                                RankExamWrittenTestView(spec: spec)
                                    .id(route)
                            } else {
                                RankExamHallView()
                            }
                        case .passport:
                            GoPassportView()
                        case .savedGames:
                            SavedGamesListView()
                        case .photoJudge:
                            PhotoBoardJudgeView()
                        }
                    }
            }
            .environment(\.zoomTransitionNamespace, zoomTransitionNamespace)

            // Global Celebratory Go Codex Term Unlock Banner!
            if let unlocked = appState.newlyUnlockedCodexToast {
                HStack(spacing: 12) {
                    Image(systemName: unlocked.symbolName)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t("codex.unlockToast.title"))
                            .font(AppFont.rounded(size: 11, weight: .black))
                            .foregroundColor(AppTheme.sunBottom)
                        Text("\(unlocked.term(l10n)) · +5 🪙")
                            .font(AppFont.rounded(size: 15, weight: .black))
                            .foregroundColor(AppTheme.inkPrimary)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.97))
                        .shadow(color: AppTheme.sunBottom.opacity(0.28), radius: 16, y: 6)
                )
                .overlay(Capsule().strokeBorder(AppTheme.sunTop, lineWidth: 2.5))
                .padding(.top, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
                .allowsHitTesting(false)
            }

            // Seamless Launch-to-Home transition: exact pixel match with LaunchScreen.storyboard
            // (LaunchSkyBackdrop.jpg + centered universal 300x300 LaunchEmblem.png), then smoothly dissolves into Home.
            if appState.isLaunchSplashActive {
                GeometryReader { geo in
                    ZStack {
                        if let uiImg = UIImage(named: "LaunchSkyBackdrop.jpg") {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .accessibilityIgnoresInvertColors()
                                .opacity(splashMorphToHome ? 0 : 1)
                        } else {
                            Color("LaunchBackground")
                                .opacity(splashMorphToHome ? 0 : 1)
                        }

                        if let emblemImg = UIImage(named: "LaunchEmblem.png") {
                            Image(uiImage: emblemImg)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(width: 300, height: 300)
                                .accessibilityIgnoresInvertColors()
                                .scaleEffect(splashMorphToHome && !reduceMotion ? 1.08 : 1.0)
                                .opacity(splashMorphToHome ? 0 : 1)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(200)
            }

            if showPortraitOverlay {
                LandscapeGuidanceOverlay(l10n: l10n) {
                    dismissPortraitOverlayForCurrentSession()
                }
                .transition(.opacity)
                .zIndex(180)
            }

            if appState.showEyeCareAlert {
                ParentalGateOverlay(
                    l10n: l10n,
                    title: l10n.t("settings.eyecare.alertTitle"),
                    message: "\(l10n.t("settings.eyecare.alertMessage", appState.settings.eyeCareMinutes))\n\(l10n.localized(zh: "如需继续对弈，请家长答对下方算术题解锁：", en: "To keep playing, please ask a parent to solve this math check:", ja: "続けて遊ぶには、保護者の方が下の計算に答えてください：", ko: "계속하려면 보호자께서 아래 계산의 답을 입력해 주세요:", zhHant: "如需繼續對弈，請家長答對下方算術題解鎖："))",
                    iconName: "eye.fill",
                    accentPalette: .mint,
                    confirmButtonTitle: l10n.t("settings.eyecare.keepPlaying"),
                    allowsDismiss: false,
                    onSuccess: {
                        appState.acknowledgeEyeCareBreak()
                    }
                )
                .accessibilityIdentifier("EyeCareParentalGateOverlay")
            }
        }
        .coordinateSpace(name: "RootLaunchSpace")
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width > 0 && proxy.size.height > proxy.size.width * 1.05
        } action: { newIsPortrait in
            handlePortraitStateChange(newIsPortrait)
        }
        .onChange(of: appState.isLaunchSplashActive) { _, _ in
            syncPortraitOverlayVisibility(debounced: false)
        }
        .onChange(of: appState.navigationPath) { _, _ in
            syncPortraitOverlayVisibility(debounced: false)
        }
        .onChange(of: appState.showSettingsSheet) { _, _ in
            syncPortraitOverlayVisibility(debounced: false)
        }
        .task {
            guard appState.isLaunchSplashActive else {
                appState.isLaunchSplashRevealing = true
                return
            }
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }
            appState.isLaunchSplashRevealing = true
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.26)) {
                    splashMorphToHome = true
                }
                try? await Task.sleep(nanoseconds: 280_000_000)
            } else {
                withAnimation(.easeOut(duration: 0.44)) {
                    splashMorphToHome = true
                }
                try? await Task.sleep(nanoseconds: 460_000_000)
            }
            guard !Task.isCancelled else { return }
            appState.isLaunchSplashActive = false
        }
        .tint(AppTheme.jadeAccent)
        .onChange(of: dynamicTypeSize) { _, _ in
            AppFont.clearFontCache()
        }
        .onChange(of: legibilityWeight) { _, _ in
            AppFont.clearFontCache()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            appState.setAppActive(phase == .active)
            if phase == .active {
                enforceMinimumLandscapeWindowSize()
            }
        }
        .fullScreenCover(isPresented: $appState.showSettingsSheet) {
            SettingsView()
                .environmentObject(appState)
                .environment(\.locale, appState.settings.language.locale)
                .font(AppFont.rounded(size: 16, weight: .semibold, languageCode: appState.settings.language.resolvedCode))
                .preferredColorScheme(.light)
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: appState.showEyeCareAlert)
    }

    /// Prevents iPadOS 26+ Freeform Windowing from shrinking the Go board into an unplayable vertical strip
    /// while staying fully compliant with modern resizable-window guidelines (Apple TN3192).
    private func enforceMinimumLandscapeWindowSize() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 1024, height: 700)
        }
    }

    private func handlePortraitStateChange(_ newIsPortrait: Bool) {
        isWindowPortrait = newIsPortrait
        if !newIsPortrait {
            dismissedPortraitForCurrentSession = false
            portraitDebounceTask?.cancel()
            portraitDebounceTask = nil
            setPortraitOverlayVisible(false)
        } else {
            syncPortraitOverlayVisibility(debounced: true)
        }
    }

    private func syncPortraitOverlayVisibility(debounced: Bool) {
        let shouldShow = isWindowPortrait
            && !dismissedPortraitForCurrentSession
            && !appState.isLaunchSplashActive
            && !appState.isPortraitGuidanceExemptRoute
            && !appState.showSettingsSheet

        portraitDebounceTask?.cancel()
        portraitDebounceTask = nil

        guard shouldShow else {
            setPortraitOverlayVisible(false)
            return
        }

        if showPortraitOverlay || !debounced {
            setPortraitOverlayVisible(true)
            return
        }

        portraitDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            let stillShouldShow = isWindowPortrait
                && !dismissedPortraitForCurrentSession
                && !appState.isLaunchSplashActive
                && !appState.isPortraitGuidanceExemptRoute
                && !appState.showSettingsSheet
            if stillShouldShow {
                setPortraitOverlayVisible(true)
            }
        }
    }

    private func dismissPortraitOverlayForCurrentSession() {
        dismissedPortraitForCurrentSession = true
        portraitDebounceTask?.cancel()
        portraitDebounceTask = nil
        setPortraitOverlayVisible(false)
    }

    private func setPortraitOverlayVisible(_ visible: Bool) {
        if showPortraitOverlay != visible {
            withAnimation(.easeInOut(duration: 0.22)) {
                showPortraitOverlay = visible
            }
        }
        if appState.isPortraitGuidanceActive != visible {
            appState.isPortraitGuidanceActive = visible
        }
    }
}
