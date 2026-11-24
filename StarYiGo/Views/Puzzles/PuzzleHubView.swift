//
//  PuzzleHubView.swift
//  StarYi Go — Super Mario Party Style Glossy Archipelago World Map
//

import SwiftUI

struct PuzzleHubView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let initialMistakesOnly: Bool

    @State private var showMistakesDrawer: Bool = false
    @State private var activePulse: Bool = false
    @State private var newlyUnlockedIslandIDs: Set<String> = []
    @State private var shakeCounters: [String: CGFloat] = [:]
    @State private var lockedToastMessage: String?
    @State private var toastDismissTask: Task<Void, Never>?

    private var l10n: L10n { appState.l10n }

    private var mistakePuzzles: [GoPuzzle] {
        appState.puzzleProgress.mistakeBookIds.compactMap { appState.findAnyPuzzle(withId: $0) }
    }

    var body: some View {
        ZStack {
            GeometryReader { fullGeo in
                let fw = fullGeo.size.width
                let fh = fullGeo.size.height

                ZStack {
                    Image("IslandMapBackdrop")
                        .resizable()
                        .scaledToFill()
                        .frame(width: fw, height: fh)
                        .clipped()

                    // Soft cool-gray mist softening locked island regions so unlocked islands pop immediately
                    ForEach(StarYiIslands.allIslands) { island in
                        let state = StarYiIslands.unlockState(for: island, progress: appState.puzzleProgress)
                        if state == .locked {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(red: 0.70, green: 0.75, blue: 0.82).opacity(0.56),
                                            Color(red: 0.75, green: 0.80, blue: 0.87).opacity(0.32),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 18,
                                        endRadius: min(fw, fh) * 0.165
                                    )
                                )
                                .frame(width: min(fw, fh) * 0.33, height: min(fw, fh) * 0.33)
                                .position(x: fw * island.mapX, y: fh * island.mapY)
                                .allowsHitTesting(false)
                        }
                    }

                    let islands = StarYiIslands.allIslands
                    let progress = appState.puzzleProgress

                    Canvas { context, size in
                        for (source, destination) in zip(islands, islands.dropFirst()) {
                            let route = islandRoute(from: source, to: destination, in: size)
                            let isOpen = StarYiIslands.unlockState(for: destination, progress: progress).isUnlocked
                            let dash: [CGFloat] = isOpen ? [] : [5, 12]

                            context.stroke(
                                route,
                                with: .color(isOpen ? AppTheme.sunRim.opacity(0.70) : AppTheme.inkPrimary.opacity(0.52)),
                                style: StrokeStyle(lineWidth: isOpen ? 7 : 5.5, lineCap: .round, dash: dash)
                            )
                            context.stroke(
                                route,
                                with: .color(isOpen ? Color(red: 1, green: 0.93, blue: 0.67) : .white.opacity(0.92)),
                                style: StrokeStyle(lineWidth: isOpen ? 4.5 : 3, lineCap: .round, dash: dash)
                            )
                        }
                    }
                    .frame(width: fw, height: fh)
                    .allowsHitTesting(false)

                    // Interactive Island Map Pins
                    ForEach(StarYiIslands.allIslands) { island in
                        islandMapPin(island)
                            .phaseAnimator([0, 1, 2], trigger: newlyUnlockedIslandIDs.contains(island.id)) { pin, phase in
                                pin.scaleEffect(!reduceMotion && phase == 1 ? 1.13 : 1)
                            } animation: { _ in
                                .spring(response: 0.29, dampingFraction: 0.72)
                            }
                            .position(mapPoint(x: island.mapX, y: island.mapY, in: fullGeo.size))
                    }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    GameBackButton(title: l10n.t("common.back")) {
                        appState.popRoute()
                    }

                    Spacer()

                    GameTitleCrest(
                        title: l10n.t("islands.title"),
                        subtitle: l10n.t("home.puzzleCard.solved", appState.puzzleProgress.solvedCount, BuiltInPuzzleLibrary.allPuzzles.count)
                    )

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            showMistakesDrawer.toggle()
                        }
                    } label: {
                        Label(
                            l10n.t("home.puzzleCard.mistakes", appState.puzzleProgress.mistakeBookIds.count),
                            systemImage: "bookmark.fill"
                        )
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(showMistakesDrawer ? .white : AppTheme.coralBottom)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(
                        GlossyCapsuleButtonStyle(
                            palette: showMistakesDrawer ? .coral : .snow,
                            cornerRadius: 999,
                            rimHeight: 5,
                            whiteBorderWidth: 3
                        )
                    )
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)

                Spacer()

                if showMistakesDrawer {
                    mistakesDock
                        .padding(.horizontal, 28)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let toast = lockedToastMessage {
                    lockedToastPill(toast)
                        .padding(.bottom, 26)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    starterBootcampDock
                        .padding(.horizontal, 28)
                        .padding(.bottom, 18)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if initialMistakesOnly {
                showMistakesDrawer = true
            }
            newlyUnlockedIslandIDs.formUnion(appState.consumeIslandUnlocks())
            if !reduceMotion && !activePulse {
                withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                    activePulse = true
                }
            }
        }
        .onDisappear {
            toastDismissTask?.cancel()
        }
    }

    private func islandRoute(from source: GoIsland, to destination: GoIsland, in size: CGSize) -> Path {
        let start = mapPoint(x: source.mapX, y: source.mapY, in: size)
        let end = mapPoint(x: destination.mapX, y: destination.mapY, in: size)

        // Place each turn in the water between the illustrated islands.
        let controls: (CGPoint, CGPoint)
        switch (source.id, destination.id) {
        case ("bamboo", "canyon"):
            controls = (CGPoint(x: 0.34, y: 0.54), CGPoint(x: 0.16, y: 0.43))
        case ("canyon", "lake"):
            controls = (CGPoint(x: 0.52, y: 0.27), CGPoint(x: 0.40, y: 0.46))
        case ("lake", "temple"):
            controls = (CGPoint(x: 0.51, y: 0.73), CGPoint(x: 0.66, y: 0.75))
        case ("temple", "peak"):
            controls = (CGPoint(x: 0.96, y: 0.58), CGPoint(x: 0.91, y: 0.39))
        default:
            let middleX = (source.mapX + destination.mapX) / 2
            controls = (CGPoint(x: middleX, y: source.mapY), CGPoint(x: middleX, y: destination.mapY))
        }

        var route = Path()
        route.move(to: start)
        route.addCurve(
            to: end,
            control1: mapPoint(x: controls.0.x, y: controls.0.y, in: size),
            control2: mapPoint(x: controls.1.x, y: controls.1.y, in: size)
        )
        return route
    }

    private func mapPoint(x: CGFloat, y: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y - 12)
    }

    // MARK: - Island Map Pin (Active / Cleared / Locked "置灰")

    @ViewBuilder
    private func islandMapPin(_ island: GoIsland) -> some View {
        let puzzles = StarYiIslands.puzzles(for: island)
        let solved = StarYiIslands.solvedCount(for: island, progress: appState.puzzleProgress)
        let unlockState = StarYiIslands.unlockState(for: island, progress: appState.puzzleProgress)
        let pal = GlossyPalette.forIsland(island.id)
        let shakeCount = shakeCounters[island.id] ?? 0

        switch unlockState {
        case .active:
            // BRIGHT, VIVID, GLOWING current island — invites the player right in!
            Button {
                SoundAndHapticsManager.shared.playUITap()
                showMistakesDrawer = false
                appState.navigationPath.append(.islandDetail(islandId: island.id))
            } label: {
                VStack(spacing: 7) {
                    ZStack {
                        // Breathing golden-tinted invite halo
                        Circle()
                            .fill(pal.top.opacity(activePulse ? 0.44 : 0.20))
                            .frame(width: activePulse ? 94 : 80, height: activePulse ? 94 : 80)

                        Circle()
                            .stroke(Color.white.opacity(activePulse ? 0.90 : 0.45), lineWidth: 3)
                            .frame(width: activePulse ? 78 : 70, height: activePulse ? 78 : 70)

                        Circle()
                            .fill(LinearGradient(colors: [pal.top, pal.bottom], startPoint: .top, endPoint: .bottom))
                            .frame(width: 64, height: 64)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                            .shadow(color: pal.glow.opacity(0.55), radius: 12, y: 6)

                        CharacterAvatarView(character: island.bossDifficulty, mood: .greeting, size: 60)
                    }

                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text(l10n.t(island.nameKey))
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.white.opacity(0.92))
                        }

                        Text("\(solved)/\(puzzles.count) ★ · \(l10n.t("islands.tapToEnter"))")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.94))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [pal.top, pal.bottom], startPoint: .top, endPoint: .bottom))
                            .overlay(Capsule().strokeBorder(.white, lineWidth: 2.5))
                            .shadow(color: pal.glow.opacity(0.40), radius: 10, y: 5)
                    )
                }
                .scaleEffect(1.06)
            }
            .buttonStyle(TactileButtonStyle(pressedScale: 0.96, playTapSound: false))
            .accessibilityIdentifier("IslandPin_\(island.id)")

        case .cleared:
            // VIVID, CELEBRATORY completed island with Golden Crown (plus Boss Trophy if Master defeated!)
            let bossDefeated = StarYiIslands.isBossDefeated(for: island, progress: appState.puzzleProgress)
            Button {
                SoundAndHapticsManager.shared.playUITap()
                showMistakesDrawer = false
                appState.navigationPath.append(.islandDetail(islandId: island.id))
            } label: {
                VStack(spacing: 6) {
                    ZStack(alignment: .topTrailing) {
                        CharacterAvatarView(character: island.bossDifficulty, mood: bossDefeated ? .cheering : .calm, size: 58)

                        // Golden Crown completion badge
                        Image(systemName: bossDefeated ? "trophy.fill" : "crown.fill")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                    .shadow(color: AppTheme.sunRim.opacity(0.4), radius: 4, y: 2)
                            )
                            .offset(x: 6, y: -5)
                    }

                    VStack(spacing: 1) {
                        Text(l10n.t(island.nameKey))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                        Text(bossDefeated ? "🏆 \(solved)/\(puzzles.count) ★" : "\(solved)/\(puzzles.count) ★")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.sunBottom)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.96))
                            .overlay(Capsule().strokeBorder(.white, lineWidth: 2.5))
                            .shadow(color: Color.black.opacity(0.16), radius: 8, y: 4)
                    )
                }
            }
            .buttonStyle(TactileButtonStyle(pressedScale: 0.96, playTapSound: false))
            .accessibilityIdentifier("IslandPin_\(island.id)")

        case .locked:
            // MUTED COOL STONE-GRAY ("置灰") locked island with prominent padlock!
            Button {
                let prerequisite = StarYiIslands.allIslands.prefix { $0.id != island.id }.first {
                    !StarYiIslands.isIslandCleared($0, progress: appState.puzzleProgress)
                }
                guard let prerequisite else { return }
                let msg = l10n.t("islands.lockedToast", l10n.t(prerequisite.nameKey))
                triggerLockedFeedback(islandId: island.id, message: msg)
            } label: {
                VStack(spacing: 6) {
                    ZStack(alignment: .bottomTrailing) {
                        CharacterAvatarView(character: island.bossDifficulty, mood: .calm, size: 54, isLocked: true)

                        // Prominent Nintendo Lock Badge
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color(red: 0.44, green: 0.49, blue: 0.56))
                                    .overlay(Circle().strokeBorder(Color.white.opacity(0.92), lineWidth: 2))
                                    .shadow(color: Color.black.opacity(0.18), radius: 4, y: 2)
                            )
                            .offset(x: 4, y: 4)
                            .modifier(LockedShakeEffect(shakes: shakeCount, amplitude: 3))
                    }

                    VStack(spacing: 1) {
                        Text(l10n.t(island.nameKey))
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.42, green: 0.47, blue: 0.54))

                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8.5, weight: .bold))
                            Text(l10n.t("islands.lockedBadge"))
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.50, green: 0.55, blue: 0.62))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.86, green: 0.89, blue: 0.93).opacity(0.94))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.75), lineWidth: 2))
                            .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
                    )
                }
                .scaleEffect(0.93)
            }
            .buttonStyle(TactileButtonStyle(pressedScale: 0.96, playTapSound: false))
            .accessibilityIdentifier("IslandPinLocked_\(island.id)")
        }
    }

    // MARK: - Locked Feedback Toast & Shake

    private func triggerLockedFeedback(islandId: String, message: String) {
        SoundAndHapticsManager.shared.playLockedDoor()
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 0.25)) {
                shakeCounters[islandId, default: 0] += 2
            }
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            showMistakesDrawer = false
            lockedToastMessage = message
        }
        toastDismissTask?.cancel()
        toastDismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    lockedToastMessage = nil
                }
            }
        }
    }

    private func lockedToastPill(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color(red: 0.46, green: 0.51, blue: 0.59)))

            Text(message)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
        }
        .padding(.leading, 10)
        .padding(.trailing, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.96))
                .shadow(color: Color.black.opacity(0.20), radius: 14, y: 6)
        )
        .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
    }

    // MARK: - Zero-Friction 5×5 Starter Bootcamp Dock

    private var starterBootcampDock: some View {
        let solved = StarterBootcamp.solvedCount(progress: appState.puzzleProgress)
        let total = StarterBootcamp.puzzles.count
        let nextLesson = StarterBootcamp.nextUnsolved(progress: appState.puzzleProgress)

        return HStack(spacing: 12) {
            Button {
                appState.navigationPath.append(.puzzlePlay(puzzleId: nextLesson.id, isDailyChallenge: false, isStarterBootcamp: true))
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(LinearGradient(colors: [AppTheme.mintTop, AppTheme.mintBottom], startPoint: .top, endPoint: .bottom)).overlay(Circle().strokeBorder(.white, lineWidth: 2)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(l10n.t("islands.starterDock.title")) (\(solved)/\(total))")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                        Text(l10n.t("islands.starterDock.subtitle"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(AppTheme.mintBottom)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))

            Button {
                appState.navigationPath.append(.trainingDojo)
            } label: {
                Label(l10n.bilingual(zh: "320题道场 / 定式 / 考级", en: "320+ Dojo & Exams"), systemImage: "rosette")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .grape, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))

            Button {
                appState.startCaptureRaceQuickPlay(boardSize: .five, target: 3, difficulty: .sprout)
            } label: {
                Label(l10n.t("islands.starterDock.captureQuick"), systemImage: "flame.fill")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
        }
    }

    // MARK: - Mistake Book Overlay Drawer

    private var mistakesDock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(l10n.t("puzzle.category.mistakes"), systemImage: "bookmark.fill")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.coralBottom)
                Spacer()
                GameCircleButton(icon: "xmark", palette: .snow, tint: AppTheme.inkSecondary, size: 36) {
                    withAnimation { showMistakesDrawer = false }
                }
            }

            if mistakePuzzles.isEmpty {
                HStack(spacing: 10) {
                    Text("🌟").font(.system(size: 28))
                    Text(l10n.t("puzzle.mistakes.empty"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 72)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(mistakePuzzles.enumerated()), id: \.element.id) { idx, puzzle in
                            mistakePuzzleTile(number: idx + 1, puzzle: puzzle)
                                .frame(width: 196)
                        }
                    }
                }
            }
        }
        .padding(18)
        .warmCard(cornerRadius: 30, padding: 0)
    }

    private func mistakePuzzleTile(number: Int, puzzle: GoPuzzle) -> some View {
        let stars = appState.puzzleProgress.starsByPuzzleId[puzzle.id] ?? 0
        let solved = stars > 0

        return Button {
            appState.navigationPath.append(.puzzlePlay(puzzleId: puzzle.id, isDailyChallenge: false, isStarterBootcamp: false))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(number)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [solved ? AppTheme.mintTop : AppTheme.coralTop, solved ? AppTheme.mintBottom : AppTheme.coralBottom],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )

                    Text(puzzle.rankBadge)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.skyBottom)

                    Spacer()
                }

                Text(puzzle.title(l10n))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .lineLimit(1)

                HStack(spacing: 3) {
                    ForEach(1...3, id: \.self) { idx in
                        Image(systemName: idx <= stars ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundColor(idx <= stars ? AppTheme.sunBottom : AppTheme.subtleBorder)
                    }
                    Spacer()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 22, rimHeight: 5, whiteBorderWidth: 3))
    }
}
