//
//  IslandDetailView.swift
//  StarYi Go — Multi-Activity Island Trail (5 Mixed Nodes + 3-Tier Mastery + SRS Ghosts + Island Boss)
//

import SwiftUI

struct IslandDetailView: View {
    @EnvironmentObject var appState: AppState
    let campaignIsland: CampaignIsland

    @State private var selectedMasteryTier: StageMasteryTier = .normal
    @State private var showMicroDemoSheet: Bool = false
    @State private var activePulse: Bool = false
    @State private var shakeCounters: [String: CGFloat] = [:]
    @State private var lockedToastMessage: String?
    @State private var toastDismissTask: Task<Void, Never>?

    private var l10n: L10n { appState.l10n }
    private var isZh: Bool { l10n.language.isChinese }
    private var pal: GlossyPalette { GlossyPalette.forIsland(campaignIsland.id) }
    private var nodes: [CampaignNode] { campaignIsland.nodes }
    private var seaNumber: Int { (StarYiCampaign.sea(withId: campaignIsland.seaId)?.index ?? 0) + 1 }
    private var bossUnlocked: Bool { StarYiCampaign.isBossUnlocked(for: campaignIsland, progress: appState.puzzleProgress) }
    private var bossDefeated: Bool { StarYiCampaign.isBossDefeated(for: campaignIsland, progress: appState.puzzleProgress) }
    private var islandCleared: Bool { StarYiCampaign.isIslandCleared(campaignIsland, progress: appState.puzzleProgress) }
    private var nextIsland: CampaignIsland? { StarYiCampaign.nextIsland(after: campaignIsland) }
    private var dueGhosts: [SRSMistakeItem] { StarYiCampaign.dueMistakeGhosts(for: campaignIsland, progress: appState.puzzleProgress) }

    var body: some View {
        ZStack {
            islandBackdrop

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let horizontalPad: CGFloat = min(36, max(18, w * 0.03))

                VStack(spacing: 10) {
                    topHeaderBar
                        .padding(.horizontal, horizontalPad)
                        .padding(.top, 14)

                    masteryAndGhostStrip
                        .padding(.horizontal, horizontalPad)

                    Spacer(minLength: 4)

                    stageTrailSection(availableWidth: w - horizontalPad * 2, availableHeight: h)
                        .padding(.horizontal, horizontalPad)

                    Spacer(minLength: 6)

                    bossAndNextIslandDock
                        .padding(.horizontal, horizontalPad)
                        .padding(.bottom, 18)
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
        .sheet(isPresented: $showMicroDemoSheet) {
            IslandMicroDemoSheet(island: campaignIsland)
                .environmentObject(appState)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                activePulse = true
            }
        }
        .onDisappear {
            toastDismissTask?.cancel()
        }
    }

    // MARK: - Backdrop

    private var islandBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.canvasTop, Color.white, AppTheme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle().fill(pal.top.opacity(0.18)).frame(width: 560, height: 560).blur(radius: 75).offset(x: -360, y: -220)
            Circle().fill(pal.bottom.opacity(0.12)).frame(width: 480, height: 480).blur(radius: 80).offset(x: 380, y: 240)
            Circle().fill(AppTheme.sunTop.opacity(0.10)).frame(width: 340, height: 340).blur(radius: 65).offset(x: 120, y: -260)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Top Header Bar

    private var topHeaderBar: some View {
        let solved = StarYiCampaign.clearedNodeCount(for: campaignIsland, progress: appState.puzzleProgress)
        let earned = StarYiCampaign.earnedStars(for: campaignIsland, progress: appState.puzzleProgress)
        let maxStars = StarYiCampaign.maxStars(for: campaignIsland)

        return HStack(spacing: 12) {
            GameBackButton(title: l10n.t("common.back")) {
                appState.popRoute()
            }

            Spacer()

            HStack(spacing: 12) {
                CharacterAvatarView(character: campaignIsland.boss.difficulty, mood: bossDefeated ? .cheering : .greeting, size: 42)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 7) {
                        Text(isZh ? "海域\(seaNumber)-\(campaignIsland.orderInSea + 1) · \(campaignIsland.rankRange)" : "Sea \(seaNumber)-\(campaignIsland.orderInSea + 1) · \(campaignIsland.rankRange)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(LinearGradient(colors: [pal.top, pal.bottom], startPoint: .top, endPoint: .bottom)))

                        Text(campaignIsland.localizedName(l10n))
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                            .lineLimit(1)
                    }

                    Text(campaignIsland.desc(isChinese: isZh))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 20)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.white.opacity(0.96)).shadow(color: pal.glow.opacity(0.16), radius: 12, y: 5))
            .overlay(Capsule().strokeBorder(.white, lineWidth: 3))

            Spacer()

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(AppTheme.sunBottom)
                    Text("\(earned)/\(maxStars)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                }
                Divider().frame(height: 15)
                Text("\(solved)/\(nodes.count)\(isZh ? "关" : "")")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(solved == nodes.count ? AppTheme.mintBottom : pal.bottom)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(0.96)).shadow(color: AppTheme.skyBottom.opacity(0.14), radius: 10, y: 4))
            .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
        }
    }

    // MARK: - 3-Tier Mastery Mode Selector + SRS Mistake Ghost Bounty Banner

    private var masteryAndGhostStrip: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(StageMasteryTier.allCases) { tier in
                    let active = selectedMasteryTier == tier
                    Button {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                            selectedMasteryTier = tier
                        }
                        SoundAndHapticsManager.shared.playUITap()
                    } label: {
                        Text(tier.badge(isChinese: isZh))
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(active ? .white : AppTheme.inkPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(minHeight: AppTheme.buttonFaceHeight)
                            .background(
                                Capsule().fill(
                                    active
                                        ? (tier == .examCrown ? AppTheme.grapeBottom : (tier == .transformed ? AppTheme.skyBottom : pal.bottom))
                                        : Color.white.opacity(0.92)
                                )
                            )
                    }
                    .tactileButton(scale: 0.96, sound: false)
                }
            }
            .padding(4)
            .background(Capsule().fill(Color.white.opacity(0.70)))

            // 3-Second Silent Visual Micro-Demo button (Nintendo Mario 1-1 zero-word demo!)
            Button {
                showMicroDemoSheet = true
                SoundAndHapticsManager.shared.playUITap()
            } label: {
                HStack(spacing: 5) {
                    Text(IslandMicroDemos.spec(for: campaignIsland.id).icon).font(.system(size: 13))
                    Text(l10n.localized(zh: "3秒动画演示", en: "3s Visual Demo", ja: "3秒アニメ手本", ko: "3초 시범", zhHant: "3秒動畫演示"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))

            if !dueGhosts.isEmpty {
                Button {
                    appState.navigationPath.append(.srsGhostBuster(islandId: campaignIsland.id))
                } label: {
                    HStack(spacing: 6) {
                        Text("👻").font(.system(size: 14))
                        Text(isZh ? "消灭 \(dueGhosts.count) 只错题幽灵（2×星币）" : "Bust \(dueGhosts.count) Mistake Ghost(s) (2× 🪙)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
            }
        }
    }

    // MARK: - Winding 5-Node Mixed Activity Trail

    private func stageTrailSection(availableWidth: CGFloat, availableHeight: CGFloat) -> some View {
        let count = nodes.count
        let waveOffset: CGFloat = min(18, max(8, availableHeight * 0.022))
        let cardHeight: CGFloat = min(214, max(172, availableHeight * 0.29))
        let isNarrow = availableWidth < 820

        let trailContent = ZStack {
            Canvas { context, size in
                guard count >= 2 else { return }
                let stepX = size.width / CGFloat(count)
                let midY = size.height / 2

                for i in 0..<(count - 1) {
                    let y1 = midY + (i % 2 == 0 ? waveOffset : -waveOffset)
                    let y2 = midY + ((i + 1) % 2 == 0 ? waveOffset : -waveOffset)
                    let p1 = CGPoint(x: stepX * (CGFloat(i) + 0.5), y: y1)
                    let p2 = CGPoint(x: stepX * (CGFloat(i + 1) + 0.5), y: y2)
                    let ctrl = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2 + (i % 2 == 0 ? -20 : 20))

                    var seg = Path()
                    seg.move(to: p1)
                    seg.addQuadCurve(to: p2, control: ctrl)

                    let nextState = StarYiCampaign.nodeState(at: i + 1, in: campaignIsland, progress: appState.puzzleProgress)
                    if nextState.isUnlocked {
                        context.stroke(seg, with: .color(pal.top.opacity(0.28)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        context.stroke(
                            seg,
                            with: .linearGradient(Gradient(colors: [pal.top, pal.bottom]), startPoint: p1, endPoint: p2),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [9, 9])
                        )
                    } else {
                        context.stroke(seg, with: .color(Color(red: 0.74, green: 0.78, blue: 0.84).opacity(0.75)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, dash: [7, 10]))
                    }
                }
            }
            .frame(height: cardHeight + waveOffset * 2 + 20)
            .allowsHitTesting(false)

            HStack(spacing: isNarrow ? 14 : min(18, max(10, availableWidth * 0.015))) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, node in
                    let state = StarYiCampaign.nodeState(at: idx, in: campaignIsland, progress: appState.puzzleProgress)
                    nodeStationCard(stageNumber: idx + 1, node: node, state: state, height: cardHeight)
                        .frame(width: isNarrow ? 196 : nil)
                        .offset(y: idx % 2 == 0 ? waveOffset : -waveOffset)
                }
            }
        }
        .frame(maxWidth: 1120)

        return Group {
            if isNarrow {
                ScrollView(.horizontal, showsIndicators: false) {
                    trailContent.padding(.horizontal, 6).padding(.vertical, 12)
                }
            } else {
                trailContent
            }
        }
    }

    @ViewBuilder
    private func nodeStationCard(
        stageNumber: Int,
        node: CampaignNode,
        state: StageUnlockState,
        height: CGFloat
    ) -> some View {
        let shakeCount = shakeCounters[node.id] ?? 0
        let earnedTier = StarYiCampaign.masteryTier(for: node, progress: appState.puzzleProgress)

        switch state {
        case .active:
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(pal.top.opacity(activePulse ? 0.30 : 0.12))
                    .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                    .blur(radius: activePulse ? 10 : 5)
                    .scaleEffect(activePulse ? 1.02 : 0.99)
                    .allowsHitTesting(false)

                Button {
                    launchNode(node)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ZStack {
                                Circle().fill(Color.white).frame(width: 34, height: 34)
                                Image(systemName: node.kind.symbolName)
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundColor(pal.bottom)
                            }
                            Spacer()
                            Text(node.rankBadge)
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.black.opacity(0.20)))
                        }

                        Text(node.kind.typeTag(isChinese: isZh))
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                            .lineLimit(1)

                        Text(node.title(isChinese: isZh))
                            .font(.system(size: 16.5, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)

                        Spacer(minLength: 2)

                        HStack {
                            Text(isZh ? "第\(stageNumber)关" : "Stage \(stageNumber)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                            Spacer()
                            HStack(spacing: 3) {
                                Text(l10n.t("islands.stagePlay"))
                                    .font(.system(size: 11.5, weight: .black, design: .rounded))
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9.5, weight: .black))
                            }
                            .foregroundColor(pal.bottom)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white))
                        }
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: pal, cornerRadius: 26, rimHeight: 6, whiteBorderWidth: 3.5, showStripeSheen: true, pressStyle: .card))
                .accessibilityIdentifier("IslandStageButton_\(stageNumber)")
            }

        case .cleared(let stars):
            Button {
                launchNode(node)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [AppTheme.mintTop, AppTheme.mintBottom], startPoint: .top, endPoint: .bottom))
                                .frame(width: 34, height: 34)
                            Image(systemName: earnedTier == .examCrown ? "crown.fill" : "checkmark")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text(node.rankBadge)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(pal.bottom)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(pal.top.opacity(0.14)))
                    }

                    Text(node.kind.typeTag(isChinese: isZh))
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.mintBottom)
                        .lineLimit(1)

                    Text(node.title(isChinese: isZh))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)

                    Spacer(minLength: 2)

                    HStack(spacing: 3) {
                        ForEach(1...3, id: \.self) { starIdx in
                            Image(systemName: starIdx <= stars ? "star.fill" : "star")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(starIdx <= stars ? AppTheme.sunBottom : AppTheme.subtleBorder)
                        }
                        Spacer()
                        if let tier = earnedTier, tier > .normal {
                            Text(tier == .examCrown ? "👑" : "🔄")
                                .font(.system(size: 13))
                        }
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 26, rimHeight: 5, whiteBorderWidth: 3, pressStyle: .card))
            .accessibilityIdentifier("IslandStageButton_\(stageNumber)")

        case .locked:
            Button {
                triggerLockedFeedback(
                    key: node.id,
                    message: l10n.t("islands.stageLockedToast", max(1, stageNumber - 1))
                )
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ZStack {
                            Circle().fill(GlossyPalette.locked.bottom).frame(width: 34, height: 34)
                            Image(systemName: "lock.fill").font(.system(size: 14, weight: .black)).foregroundColor(.white)
                        }
                        Spacer()
                        Text(node.rankBadge)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.50, green: 0.55, blue: 0.62))
                    }

                    Text(node.kind.typeTag(isChinese: isZh))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.52, green: 0.56, blue: 0.63))
                        .lineLimit(1)

                    Text(node.title(isChinese: isZh))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 0.45, green: 0.49, blue: 0.56))
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)

                    Spacer(minLength: 2)

                    HStack(spacing: 3) {
                        ForEach(1...3, id: \.self) { _ in
                            Image(systemName: "star").font(.system(size: 13)).foregroundColor(Color(red: 0.65, green: 0.69, blue: 0.75))
                        }
                        Spacer()
                        Text(l10n.t("islands.lockedBadge"))
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.60))
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .lockedCard, cornerRadius: 26, rimHeight: 5, whiteBorderWidth: 2.5, playTapSound: false, pressStyle: .card))
            .opacity(0.92)
            .modifier(LockedShakeEffect(shakes: shakeCount))
            .accessibilityIdentifier("IslandStageLocked_\(stageNumber)")
        }
    }

    private func launchNode(_ node: CampaignNode) {
        SoundAndHapticsManager.shared.playUITap()
        switch node.kind {
        case .puzzleGauntlet:
            appState.navigationPath.append(.puzzleGauntlet(nodeId: node.id, masteryTier: selectedMasteryTier))
        case .miniDrill(let kind, let offset, let count):
            appState.navigationPath.append(.miniDrill(kind: kind, campaignNodeId: node.id, startOffset: offset, targetCount: count))
        case .josekiTrial(let courseId):
            appState.navigationPath.append(.josekiTrainer(courseId: courseId, campaignNodeId: node.id))
        case .tacticalScenario(let scenarioId):
            if let scenario = TacticalScenariosLibrary.scenario(withId: scenarioId) {
                appState.startTacticalScenario(scenario, campaignNodeId: node.id)
            }
        }
    }

    // MARK: - Bottom Island Master Boss Duel Pavilion + Next Island Portal

    private var bossAndNextIslandDock: some View {
        let boss = campaignIsland.boss
        let bossShake = shakeCounters["boss"] ?? 0

        return HStack(spacing: 14) {
            if bossUnlocked {
                Button {
                    appState.startCampaignBossMatch(island: campaignIsland)
                } label: {
                    HStack(spacing: 14) {
                        CharacterAvatarView(character: boss.difficulty, mood: bossDefeated ? .cheering : .playful, size: 52)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Label(boss.title(isChinese: isZh), systemImage: bossDefeated ? "trophy.fill" : "flame.fill")
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                Text(l10n.t(bossDefeated ? "islands.bossDefeatedBadge" : "islands.bossUnlockedBadge"))
                                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                                    .foregroundColor(bossDefeated ? AppTheme.mintBottom : AppTheme.coralBottom)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.white))
                            }

                            Text(boss.tagline(isChinese: isZh))
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.94))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 6)

                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: bossDefeated ? .mint : .coral, cornerRadius: 28, rimHeight: 6, whiteBorderWidth: 3.5, showStripeSheen: true, pressStyle: .card))

                if islandCleared, let next = nextIsland {
                    let nextPal = GlossyPalette.forIsland(next.id)
                    let isCrossSea = (next.seaId != campaignIsland.seaId)
                    Button {
                        if !appState.navigationPath.isEmpty {
                            appState.navigationPath[appState.navigationPath.count - 1] = .islandDetail(islandId: next.id)
                        } else {
                            appState.navigationPath.append(.islandDetail(islandId: next.id))
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Text(isCrossSea ? "✈️" : next.boss.difficulty.avatarEmoji).font(.system(size: 22))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(isCrossSea
                                     ? (isZh ? "飞往新海域 · \(next.nameZh)" : "Fly to New Sea · \(next.nameEn)")
                                     : l10n.t("islands.nextIsland", next.name(isChinese: isZh)))
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(next.rankRange)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.92))
                            }
                            Image(systemName: "arrow.right.circle.fill").font(.system(size: 20, weight: .black)).foregroundColor(.white)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: nextPal, cornerRadius: 28, rimHeight: 6, whiteBorderWidth: 3.5, pressStyle: .card))
                }
            } else {
                Button {
                    triggerLockedFeedback(key: "boss", message: l10n.t("islands.bossLockedHint", nodes.count))
                } label: {
                    HStack(spacing: 14) {
                        ZStack(alignment: .bottomTrailing) {
                            CharacterAvatarView(character: boss.difficulty, mood: .calm, size: 50, isLocked: true)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10.5, weight: .black))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color(red: 0.44, green: 0.49, blue: 0.56)).overlay(Circle().strokeBorder(.white, lineWidth: 1.5)))
                                .offset(x: 3, y: 3)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(boss.title(isChinese: isZh))
                                    .font(.system(size: 16.5, weight: .black, design: .rounded))
                                    .foregroundColor(Color(red: 0.44, green: 0.48, blue: 0.55))
                                Text(boss.difficulty.rankBadge)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 0.52, green: 0.56, blue: 0.63))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.58)))
                            }
                            Text(isZh ? "完成本岛全部 \(nodes.count) 关后自动解锁下一岛，并开启守岛 Boss 挑战！" : "Clear all \(nodes.count) stages to unlock the next island and challenge the Island Master Boss!")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.52, green: 0.56, blue: 0.63))
                        }

                        Spacer(minLength: 6)

                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill").font(.system(size: 11, weight: .black))
                            Text(l10n.t("islands.lockedBadge")).font(.system(size: 12, weight: .black, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.47, green: 0.52, blue: 0.59))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.62)))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .lockedCard, cornerRadius: 28, rimHeight: 5, whiteBorderWidth: 2.5, playTapSound: false, pressStyle: .card))
                .modifier(LockedShakeEffect(shakes: bossShake))
            }
        }
        .frame(maxWidth: 1120)
    }

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
                .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
        }
        .padding(.leading, 10)
        .padding(.trailing, 20)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.white.opacity(0.96)).shadow(color: Color.black.opacity(0.16), radius: 14, y: 6))
        .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
    }
}
