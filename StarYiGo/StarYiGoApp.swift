//
//  StarYiGoApp.swift
//  StarYi Go
//

import SwiftUI

@main
struct StarYiGoApp: App {
    @StateObject private var appState: AppState

    init() {
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
        }
    }
}

struct RootNavigationView: View {
    @EnvironmentObject var appState: AppState

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
                            } else {
                                HomeView()
                            }
                        case .puzzleHub(let initialMistakesOnly):
                            PuzzleHubView(initialMistakesOnly: initialMistakesOnly)
                        case .islandDetail(let islandId):
                            if let island = StarYiIslands.island(withId: islandId) {
                                IslandDetailView(island: island)
                            } else {
                                PuzzleHubView(initialMistakesOnly: false)
                            }
                        case .puzzlePlay(let puzzleId, let isDailyChallenge, let isStarterBootcamp):
                            if let puzzle = appState.findAnyPuzzle(withId: puzzleId) {
                                PuzzlePlayView(
                                    puzzle: puzzle,
                                    appState: appState,
                                    isDailyChallenge: isDailyChallenge,
                                    isStarterBootcamp: isStarterBootcamp
                                )
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
                            } else {
                                GameArchiveView()
                            }
                        case .trainingDojo:
                            TrainingDojoView()
                        case .josekiTrainer(let courseId):
                            if let course = JosekiLibrary.course(withId: courseId) {
                                JosekiTrainerView(course: course)
                            } else {
                                TrainingDojoView()
                            }
                        case .miniDrill(let kind):
                            GoMiniDrillPlayView(kind: kind)
                        case .rankExamHall:
                            RankExamHallView()
                        case .rankExamTest(let tier):
                            if let spec = RankExamSystem.spec(for: tier) {
                                RankExamWrittenTestView(spec: spec)
                            } else {
                                RankExamHallView()
                            }
                        }
                    }
            }

            // Global Celebratory Go Codex Term Unlock Banner!
            if let unlocked = appState.newlyUnlockedCodexToast {
                HStack(spacing: 12) {
                    Image(systemName: unlocked.symbolName)
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t("codex.unlockToast.title"))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.sunBottom)
                        Text("\(unlocked.term(l10n)) · +5 🪙")
                            .font(.system(size: 15, weight: .black, design: .rounded))
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
        }
        .tint(AppTheme.jadeAccent)
        .fullScreenCover(isPresented: $appState.showSettingsSheet) {
            SettingsView()
                .environmentObject(appState)
                .environment(\.locale, appState.settings.language.locale)
        }
        .alert(l10n.t("settings.eyecare.alertTitle"), isPresented: $appState.showEyeCareAlert) {
            Button(l10n.t("settings.eyecare.keepPlaying")) {}
        } message: {
            Text(l10n.t("settings.eyecare.alertMessage", appState.settings.eyeCareMinutes))
        }
    }
}
