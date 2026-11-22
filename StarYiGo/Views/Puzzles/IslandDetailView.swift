//
//  IslandDetailView.swift
//  StarYi Go — Dedicated Nintendo-Style Island Stage Map Page
//

import SwiftUI

struct IslandDetailView: View {
    @EnvironmentObject var appState: AppState
    let island: GoIsland

    @State private var activePulse: Bool = false
    @State private var shakeCounters: [String: CGFloat] = [:]
    @State private var lockedToastMessage: String?
    @State private var toastDismissTask: Task<Void, Never>?

    private var l10n: L10n { appState.l10n }
    private var pal: GlossyPalette { GlossyPalette.forIsland(island.id) }
    private var puzzles: [GoPuzzle] { StarYiIslands.puzzles(for: island) }
    private var worldNumber: Int { (StarYiIslands.islandIndex(for: island) ?? 0) + 1 }
    private var bossUnlocked: Bool { StarYiIslands.isBossUnlocked(for: island, progress: appState.puzzleProgress) }
    private var bossDefeated: Bool { StarYiIslands.isBossDefeated(for: island, progress: appState.puzzleProgress) }
    private var nextIsland: GoIsland? { StarYiIslands.nextIsland(after: island) }

    var body: some View {
        ZStack {
            islandBackdrop

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let horizontalPad: CGFloat = min(40, max(22, w * 0.035))

                VStack(spacing: 0) {
                    topHeaderBar
                        .padding(.horizontal, horizontalPad)
                        .padding(.top, 16)

                    Spacer(minLength: 12)

                    stageTrailSection(availableWidth: w - horizontalPad * 2, availableHeight: h)
                        .padding(.horizontal, horizontalPad)

                    Spacer(minLength: 14)

                    bossAndNextIslandDock
                        .padding(.horizontal, horizontalPad)
                        .padding(.bottom, 22)
                }
                .frame(width: w, height: h)
            }

            if let toast = lockedToastMessage {
                VStack {
                    Spacer()
                    lockedToastPill(toast)
                        .padding(.bottom, 26)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(20)
                .allowsHitTesting(false)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                activePulse = true
            }
        }
        .onDisappear {
            toastDismissTask?.cancel()
        }
    }

    // MARK: - Themed Nintendo Sunlit Island Backdrop

    private var islandBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.canvasTop,
                    Color.white,
                    AppTheme.canvasBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft sunlit theme glow clouds unique to this island
            Circle()
                .fill(pal.top.opacity(0.18))
                .frame(width: 560, height: 560)
                .blur(radius: 75)
                .offset(x: -360, y: -220)

            Circle()
                .fill(pal.bottom.opacity(0.12))
                .frame(width: 480, height: 480)
                .blur(radius: 80)
                .offset(x: 380, y: 240)

            Circle()
                .fill(AppTheme.sunTop.opacity(0.10))
                .frame(width: 340, height: 340)
                .blur(radius: 65)
                .offset(x: 120, y: -260)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Top Header Bar

    private var topHeaderBar: some View {
        let solved = StarYiIslands.solvedCount(for: island, progress: appState.puzzleProgress)
        let earned = StarYiIslands.earnedStars(for: island, progress: appState.puzzleProgress)
        let maxStars = StarYiIslands.maxStars(for: island)

        return HStack(spacing: 12) {
            GameBackButton(title: l10n.t("common.back")) {
                appState.popRoute()
            }

            Spacer()

            // Island World Crest
            HStack(spacing: 12) {
                CharacterAvatarView(character: island.bossDifficulty, mood: bossDefeated ? .cheering : .greeting, size: 42)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 7) {
                        Text(l10n.t("islands.worldNumber", worldNumber))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(LinearGradient(colors: [pal.top, pal.bottom], startPoint: .top, endPoint: .bottom))
                            )

                        Text(l10n.t(island.nameKey))
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                            .lineLimit(1)
                    }

                    Text(l10n.t(island.descKey))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 22)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [.white, Color(red: 0.95, green: 0.98, blue: 1.0)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: pal.glow.opacity(0.16), radius: 12, y: 5)
            )
            .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
            .overlay(Capsule().strokeBorder(pal.top.opacity(0.28), lineWidth: 1))

            Spacer()

            // Earned Stars + Cleared Count Pill
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                    Text(l10n.t("islands.starsCount", earned, maxStars))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                }

                Divider().frame(height: 16)

                Text(l10n.t("islands.chapterProgress", solved, puzzles.count))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(solved == puzzles.count ? AppTheme.mintBottom : pal.bottom)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [.white, Color(red: 0.95, green: 0.97, blue: 1.0)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: AppTheme.skyBottom.opacity(0.14), radius: 10, y: 4)
            )
            .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
        }
    }

    // MARK: - Nintendo Winding Stage Trail (4 Progressive Stages)

    private func stageTrailSection(availableWidth: CGFloat, availableHeight: CGFloat) -> some View {
        let count = puzzles.count
        let waveOffset: CGFloat = min(22, max(12, availableHeight * 0.028))
        let cardHeight: CGFloat = min(226, max(188, availableHeight * 0.30))

        return ZStack {
            // Winding curved dashed road connecting Stage 1 -> 2 -> 3 -> 4
            Canvas { context, size in
                guard count >= 2 else { return }
                let stepX = size.width / CGFloat(count)
                let midY = size.height / 2

                for i in 0..<(count - 1) {
                    let y1 = midY + (i % 2 == 0 ? waveOffset : -waveOffset)
                    let y2 = midY + ((i + 1) % 2 == 0 ? waveOffset : -waveOffset)
                    let p1 = CGPoint(x: stepX * (CGFloat(i) + 0.5), y: y1)
                    let p2 = CGPoint(x: stepX * (CGFloat(i + 1) + 0.5), y: y2)
                    let ctrl = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2 + (i % 2 == 0 ? -24 : 24))

                    var seg = Path()
                    seg.move(to: p1)
                    seg.addQuadCurve(to: p2, control: ctrl)

                    let nextState = StarYiIslands.stageState(at: i + 1, in: island, progress: appState.puzzleProgress)
                    if nextState.isUnlocked {
                        context.stroke(
                            seg,
                            with: .color(pal.top.opacity(0.28)),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        context.stroke(
                            seg,
                            with: .linearGradient(
                                Gradient(colors: [pal.top, pal.bottom]),
                                startPoint: p1,
                                endPoint: p2
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [10, 10])
                        )
                    } else {
                        // Muted gray ("置灰") locked trail
                        context.stroke(
                            seg,
                            with: .color(Color(red: 0.74, green: 0.78, blue: 0.84).opacity(0.75)),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [7, 11])
                        )
                    }
                }
            }
            .frame(height: cardHeight + waveOffset * 2 + 28)
            .allowsHitTesting(false)

            HStack(spacing: min(22, max(12, availableWidth * 0.02))) {
                ForEach(Array(puzzles.enumerated()), id: \.element.id) { idx, puzzle in
                    let state = StarYiIslands.stageState(at: idx, in: island, progress: appState.puzzleProgress)
                    stageStationCard(
                        stageNumber: idx + 1,
                        puzzle: puzzle,
                        state: state,
                        height: cardHeight
                    )
                    .offset(y: idx % 2 == 0 ? waveOffset : -waveOffset)
                }
            }
        }
        .frame(maxWidth: 1080)
    }

    @ViewBuilder
    private func stageStationCard(
        stageNumber: Int,
        puzzle: GoPuzzle,
        state: StageUnlockState,
        height: CGFloat
    ) -> some View {
        let shakeCount = shakeCounters[puzzle.id] ?? 0

        switch state {
        case .active:
            // BRIGHT, VIVID, GLOWING current stage!
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(pal.top.opacity(activePulse ? 0.34 : 0.14))
                    .blur(radius: activePulse ? 14 : 7)
                    .scaleEffect(activePulse ? 1.04 : 0.99)
                    .allowsHitTesting(false)

                Button {
                    appState.navigationPath.append(.puzzlePlay(puzzleId: puzzle.id, isDailyChallenge: false, isStarterBootcamp: false))
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 40, height: 40)
                                    .shadow(color: pal.rim.opacity(0.32), radius: 5, y: 2)
                                Text("\(stageNumber)")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(LinearGradient(colors: [pal.top, pal.bottom], startPoint: .top, endPoint: .bottom))
                            }

                            Spacer()

                            Text(puzzle.rankBadge)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.18)))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(l10n.t("islands.stageNumber", stageNumber))
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.88))

                            Text(puzzle.title(l10n))
                                .font(.system(size: 19, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: pal.rim.opacity(0.45), radius: 1.5, y: 1.5)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }

                        Spacer(minLength: 4)

                        HStack(spacing: 4) {
                            ForEach(1...3, id: \.self) { _ in
                                Image(systemName: "star")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.white.opacity(0.65))
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Text(l10n.t("islands.stagePlay"))
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10, weight: .black))
                            }
                            .foregroundColor(pal.bottom)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white))
                            .shadow(color: pal.rim.opacity(0.28), radius: 4, y: 2)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
                }
                .buttonStyle(
                    GlossyCapsuleButtonStyle(
                        palette: pal,
                        cornerRadius: 28,
                        rimHeight: 7,
                        whiteBorderWidth: 3.5,
                        showStripeSheen: true
                    )
                )
                .accessibilityIdentifier("IslandStageButton_\(stageNumber)")
            }

        case .cleared(let stars):
            // Crisp celebratory completed stage card (bright white + gold stars + emerald check)
            Button {
                appState.navigationPath.append(.puzzlePlay(puzzleId: puzzle.id, isDailyChallenge: false))
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [AppTheme.mintTop, AppTheme.mintBottom], startPoint: .top, endPoint: .bottom))
                                .frame(width: 38, height: 38)
                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Text(puzzle.rankBadge)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(pal.bottom)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(pal.top.opacity(0.14)))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(l10n.t("islands.stageNumber", stageNumber))
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.mintBottom)

                        Text(puzzle.title(l10n))
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 4)

                    HStack(spacing: 4) {
                        ForEach(1...3, id: \.self) { starIdx in
                            Image(systemName: starIdx <= stars ? "star.fill" : "star")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(
                                    starIdx <= stars
                                    ? AnyShapeStyle(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(AppTheme.subtleBorder)
                                )
                        }
                        Spacer()
                        Text(l10n.t("islands.clearedBadge"))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.mintBottom)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppTheme.mintTop.opacity(0.16)))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            }
            .buttonStyle(
                GlossyCapsuleButtonStyle(
                    palette: .snow,
                    cornerRadius: 28,
                    rimHeight: 6,
                    whiteBorderWidth: 3
                )
            )
            .accessibilityIdentifier("IslandStageButton_\(stageNumber)")

        case .locked:
            // MUTED COOL STONE-GRAY ("置灰") locked stage card — clearly unplayable until previous stage cleared!
            Button {
                triggerLockedFeedback(
                    key: puzzle.id,
                    message: l10n.t("islands.stageLockedToast", max(1, stageNumber - 1))
                )
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [GlossyPalette.locked.top, GlossyPalette.locked.bottom],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.75), lineWidth: 2))
                            Image(systemName: "lock.fill")
                                .font(.system(size: 15, weight: .black))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Text(puzzle.rankBadge)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.50, green: 0.55, blue: 0.62))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.55)))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(l10n.t("islands.stageNumber", stageNumber))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.52, green: 0.56, blue: 0.63))

                        Text(puzzle.title(l10n))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.45, green: 0.49, blue: 0.56))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 4)

                    HStack(spacing: 4) {
                        ForEach(1...3, id: \.self) { _ in
                            Image(systemName: "star")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 0.65, green: 0.69, blue: 0.75))
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text(l10n.t("islands.lockedBadge"))
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.60))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.55)))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            }
            .buttonStyle(
                GlossyCapsuleButtonStyle(
                    palette: .lockedCard,
                    cornerRadius: 28,
                    rimHeight: 5,
                    whiteBorderWidth: 2.5,
                    playTapSound: false
                )
            )
            .opacity(0.92)
            .modifier(LockedShakeEffect(shakes: shakeCount))
            .accessibilityIdentifier("IslandStageLocked_\(stageNumber)")
        }
    }

    // MARK: - Bottom Island Master Boss Duel Pavilion + Next Island Portal

    private var bossAndNextIslandDock: some View {
        let boss = island.bossDifficulty
        let bossShake = shakeCounters["boss"] ?? 0

        return HStack(spacing: 16) {
            if bossUnlocked {
                // UNLOCKED: Blazing vibrant Coral-Gold Nintendo Boss Duel Banner (with Defeated Trophy + Co-op Pair Go!)
                Button {
                    appState.startIslandBossMatch(island: island, isCoopMode: false)
                } label: {
                    HStack(spacing: 16) {
                        CharacterAvatarView(character: boss, mood: bossDefeated ? .cheering : .playful, size: 54)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Label(l10n.t("islands.bossDuel"), systemImage: bossDefeated ? "trophy.fill" : "flame.fill")
                                    .font(.system(size: 19, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: AppTheme.coralRim.opacity(0.45), radius: 1.5, y: 1.5)

                                Text(l10n.t(bossDefeated ? "islands.bossDefeatedBadge" : "islands.bossUnlockedBadge"))
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(bossDefeated ? AppTheme.mintBottom : AppTheme.coralBottom)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.white))
                            }

                            Text(l10n.t("islands.bossSubtitle", l10n.t(boss.nameKey), boss.rankBadge))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.94))
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    GlossyCapsuleButtonStyle(
                        palette: bossDefeated ? .mint : .coral,
                        cornerRadius: 30,
                        rimHeight: 6,
                        whiteBorderWidth: 3.5,
                        showStripeSheen: true
                    )
                )

                // Parent + Child Co-op Pair Go Boss Trial button!
                Button {
                    appState.startIslandBossMatch(island: island, isCoopMode: true)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.white)
                        Text(l10n.t("islands.bossCoop"))
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                }
                .buttonStyle(
                    GlossyCapsuleButtonStyle(
                        palette: .sky,
                        cornerRadius: 28,
                        rimHeight: 6,
                        whiteBorderWidth: 3.5
                    )
                )

                // Seamless shortcut to sail to the newly unlocked Next Island!
                if let next = nextIsland {
                    let nextPal = GlossyPalette.forIsland(next.id)
                    Button {
                        // Replace current islandDetail with the next island so Back still returns cleanly to the World Map
                        if !appState.navigationPath.isEmpty {
                            appState.navigationPath[appState.navigationPath.count - 1] = .islandDetail(islandId: next.id)
                        } else {
                            appState.navigationPath.append(.islandDetail(islandId: next.id))
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(next.bossDifficulty.avatarEmoji)
                                .font(.system(size: 24))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n.t("islands.nextIsland", l10n.t(next.nameKey)))
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: nextPal.rim.opacity(0.42), radius: 1.5, y: 1.5)
                                    .lineLimit(1)
                                Text(l10n.t(next.descKey))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.90))
                                    .lineLimit(1)
                            }
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(
                        GlossyCapsuleButtonStyle(
                            palette: nextPal,
                            cornerRadius: 30,
                            rimHeight: 6,
                            whiteBorderWidth: 3.5
                        )
                    )
                }
            } else {
                // LOCKED BOSS PAVILION: Muted stone-gray ("置灰") until all stages on this island are cleared
                Button {
                    triggerLockedFeedback(
                        key: "boss",
                        message: l10n.t("islands.bossLockedHint", puzzles.count)
                    )
                } label: {
                    HStack(spacing: 16) {
                        ZStack(alignment: .bottomTrailing) {
                            CharacterAvatarView(character: boss, mood: .calm, size: 52, isLocked: true)

                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(
                                    Circle()
                                        .fill(Color(red: 0.44, green: 0.49, blue: 0.56))
                                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                                )
                                .offset(x: 3, y: 3)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(l10n.t("islands.bossDuel"))
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundColor(Color(red: 0.44, green: 0.48, blue: 0.55))

                                Text("\(l10n.t(boss.nameKey)) · \(boss.rankBadge)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 0.52, green: 0.56, blue: 0.63))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.white.opacity(0.58)))
                            }

                            Text(l10n.t("islands.bossLockedHint", puzzles.count))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.52, green: 0.56, blue: 0.63))
                        }

                        Spacer(minLength: 8)

                        HStack(spacing: 5) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .black))
                            Text(l10n.t("islands.lockedBadge"))
                                .font(.system(size: 13, weight: .black, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.47, green: 0.52, blue: 0.59))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.62)))
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    GlossyCapsuleButtonStyle(
                        palette: .lockedCard,
                        cornerRadius: 30,
                        rimHeight: 5,
                        whiteBorderWidth: 2.5,
                        playTapSound: false
                    )
                )
                .modifier(LockedShakeEffect(shakes: bossShake))
            }
        }
        .frame(maxWidth: 1080)
    }

    // MARK: - Locked Feedback Toast & Shake

    private func triggerLockedFeedback(key: String, message: String) {
        SoundAndHapticsManager.shared.playWrong()
        withAnimation(.easeInOut(duration: 0.36)) {
            shakeCounters[key, default: 0] += 3
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            lockedToastMessage = message
        }
        toastDismissTask?.cancel()
        toastDismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_300_000_000)
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
                .shadow(color: Color.black.opacity(0.16), radius: 14, y: 6)
        )
        .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
    }
}
