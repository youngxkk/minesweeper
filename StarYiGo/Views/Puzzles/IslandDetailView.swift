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
    @State private var showMistakeReviewSheet: Bool = false
    @State private var pendingLaunchNodeAfterRecovery: CampaignNode? = nil
    @State private var pendingLaunchSectionAfterRecovery: Int? = nil
    @State private var sectionPickerNode: CampaignNode? = nil
    @State private var activePulse: Bool = false
    @State private var shakeCounters: [String: CGFloat] = [:]
    @State private var lockedToastMessage: String?
    @State private var toastDismissTask: Task<Void, Never>?

    private var l10n: L10n { appState.l10n }
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
        .sheet(isPresented: $showMistakeReviewSheet) {
            let fallbackIds = campaignIsland.nodes.flatMap(\.puzzleIds)
            let fallbackPuzzles = fallbackIds.compactMap { appState.findAnyPuzzle(withId: $0) }
            MistakeReviewRecoverySheet(
                reviewPuzzles: appState.pendingMistakeReviewPuzzles(fallbackPuzzles: fallbackPuzzles),
                headerNote: pendingLaunchNodeAfterRecovery != nil
                    ? l10n.localized(
                        zh: "体力已耗尽 · 复盘错题即可立刻满血进入关卡",
                        en: "Out of hearts — review mistakes to refill and enter stage",
                        ja: "ハート0 · 間違いを復習して全回復してからステージへ",
                        ko: "하트 소진 · 오답 복습으로 회복 후 바로 스테이지 진입",
                        zhHant: "體力已耗盡 · 復盤錯題即可立刻滿血進入關卡"
                    )
                    : nil,
                onRecovered: {
                    if let pending = pendingLaunchNodeAfterRecovery {
                        let sec = pendingLaunchSectionAfterRecovery
                        pendingLaunchNodeAfterRecovery = nil
                        pendingLaunchSectionAfterRecovery = nil
                        launchNode(pending, sectionIndex: sec)
                    }
                }
            )
            .environmentObject(appState)
            .presentationSizing(.page)
        }
        .sheet(item: $sectionPickerNode) { node in
            nodeSectionPickerSheet(for: node)
        }
        .onAppear {
            appState.refreshGauntletHearts()
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
        let solvedPuzzles = StarYiCampaign.solvedPuzzleCount(for: campaignIsland, progress: appState.puzzleProgress)
        let totalPuzzles = campaignIsland.totalPuzzleCount

        return ZStack {
            HStack(spacing: 12) {
                CharacterAvatarView(character: campaignIsland.boss.difficulty, mood: bossDefeated ? .cheering : .greeting, size: 42)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 7) {
                        Text(l10n.localized(
                            zh: "海域\(seaNumber)-\(campaignIsland.orderInSea + 1) · \(campaignIsland.rankRange)",
                            en: "Sea \(seaNumber)-\(campaignIsland.orderInSea + 1) · \(campaignIsland.rankRange)",
                            ja: "海域\(seaNumber)-\(campaignIsland.orderInSea + 1) · \(campaignIsland.rankRange)",
                            ko: "해역 \(seaNumber)-\(campaignIsland.orderInSea + 1) · \(campaignIsland.rankRange)",
                            zhHant: "海域\(seaNumber)-\(campaignIsland.orderInSea + 1) · \(campaignIsland.rankRange)"
                        ))
                            .font(AppFont.rounded(size: 11, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(LinearGradient(colors: [pal.top, pal.bottom], startPoint: .top, endPoint: .bottom)))

                        Text(campaignIsland.localizedName(l10n))
                            .font(AppFont.rounded(size: 18, weight: .black))
                            .foregroundColor(AppTheme.inkPrimary)
                            .lineLimit(1)
                    }

                    Text(campaignIsland.desc(isChinese: l10n.language.isChinese))
                        .font(AppFont.rounded(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 20)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.white.opacity(0.96)).shadow(color: pal.glow.opacity(0.16), radius: 12, y: 5))
            .overlay(Capsule().strokeBorder(.white, lineWidth: 3))

            HStack(spacing: 12) {
                GameBackButton(title: l10n.t("common.back")) {
                    appState.popRoute()
                }

                Spacer()

                HStack(spacing: 8) {
                    GauntletHeartsBadge(onTapWhenNotFull: {
                        pendingLaunchNodeAfterRecovery = nil
                        showMistakeReviewSheet = true
                    })

                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.sunBottom)
                            Text("\(earned)/\(maxStars)")
                                .font(AppFont.rounded(size: 14, weight: .black))
                                .foregroundColor(AppTheme.inkPrimary)
                        }
                        Divider().frame(height: 15)
                        Text(l10n.localized(
                            zh: "\(solved)/\(nodes.count)关",
                            en: "\(solved)/\(nodes.count)",
                            ja: "\(solved)/\(nodes.count)面",
                            ko: "\(solved)/\(nodes.count)",
                            zhHant: "\(solved)/\(nodes.count)關"
                        ))
                            .font(AppFont.rounded(size: 13, weight: .heavy))
                            .foregroundColor(solved == nodes.count ? AppTheme.mintBottom : pal.bottom)
                        if totalPuzzles > 0 {
                            Divider().frame(height: 15)
                            Text(l10n.localized(
                                zh: "\(solvedPuzzles)/\(totalPuzzles)题",
                                en: "\(solvedPuzzles)/\(totalPuzzles)Q",
                                ja: "\(solvedPuzzles)/\(totalPuzzles)問",
                                ko: "\(solvedPuzzles)/\(totalPuzzles)문제",
                                zhHant: "\(solvedPuzzles)/\(totalPuzzles)題"
                            ))
                                .font(AppFont.rounded(size: 12.5, weight: .heavy))
                                .foregroundColor(AppTheme.inkSecondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white.opacity(0.96)).shadow(color: AppTheme.skyBottom.opacity(0.14), radius: 10, y: 4))
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
                }
            }
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
                        Text(localizedTierBadge(tier))
                            .font(AppFont.rounded(size: 12, weight: .black))
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
                    Text(IslandMicroDemos.spec(for: campaignIsland.id).icon).font(AppFont.rounded(size: 13, weight: .regular))
                    Text(l10n.localized(zh: "3秒动画演示", en: "3s Visual Demo", ja: "3秒アニメ手本", ko: "3초 시범", zhHant: "3秒動畫演示"))
                        .font(AppFont.rounded(size: 12, weight: .black))
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
                        Text("👻").font(AppFont.rounded(size: 14, weight: .regular))
                        Text(l10n.localized(
                            zh: "消灭 \(dueGhosts.count) 只错题幽灵（2×星币）",
                            en: "Bust \(dueGhosts.count) Mistake Ghost(s) (2× 🪙)",
                            ja: "ミスおばけ \(dueGhosts.count) 体を退治（星コイン2倍）",
                            ko: "오답 유령 \(dueGhosts.count)마리 퇴치 (별코인 2배)",
                            zhHant: "消滅 \(dueGhosts.count) 隻錯題幽靈（2×星幣）"
                        ))
                            .font(AppFont.rounded(size: 12, weight: .black))
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
        let totalSecs = node.sectionCount
        let clearedSecs = StarYiCampaign.clearedSectionCount(for: node, progress: appState.puzzleProgress)

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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            ZStack {
                                Circle().fill(Color.white).frame(width: 34, height: 34)
                                Image(systemName: node.kind.symbolName)
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(pal.bottom)
                            }
                            Spacer()
                            Text(node.rankBadge)
                                .font(AppFont.rounded(size: 11, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.black.opacity(0.20)))
                        }

                        Text(localizedNodeTypeTag(node))
                            .font(AppFont.rounded(size: 10.5, weight: .black))
                            .foregroundColor(.white.opacity(0.92))
                            .lineLimit(1)

                        Text(node.title(isChinese: l10n.language.isChinese))
                            .font(AppFont.rounded(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)

                        if totalSecs > 1 {
                            VStack(alignment: .leading, spacing: 3) {
                                GeometryReader { barGeo in
                                    let ratio = CGFloat(clearedSecs) / CGFloat(max(1, totalSecs))
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.28))
                                        Capsule().fill(Color.white)
                                            .frame(width: max(ratio > 0 ? 8 : 0, barGeo.size.width * ratio))
                                    }
                                }
                                .frame(height: 6)

                                Text(l10n.localized(
                                    zh: "已完成 \(clearedSecs)/\(totalSecs) 节",
                                    en: "\(clearedSecs)/\(totalSecs) sets cleared",
                                    ja: "\(clearedSecs)/\(totalSecs) 節クリア",
                                    ko: "\(clearedSecs)/\(totalSecs)세트 완료",
                                    zhHant: "已完成 \(clearedSecs)/\(totalSecs) 節"
                                ))
                                    .font(AppFont.rounded(size: 10, weight: .heavy))
                                    .foregroundColor(.white.opacity(0.92))
                            }
                        }

                        Spacer(minLength: 2)

                        HStack {
                            Text(l10n.localized(
                                zh: "第\(stageNumber)关",
                                en: "Stage \(stageNumber)",
                                ja: "ステージ \(stageNumber)",
                                ko: "스테이지 \(stageNumber)",
                                zhHant: "第\(stageNumber)關"
                            ))
                                .font(AppFont.rounded(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                            Spacer()
                            HStack(spacing: 3) {
                                Text(totalSecs > 1
                                     ? l10n.localized(
                                        zh: "第\(min(totalSecs, clearedSecs + 1))节",
                                        en: "Set \(min(totalSecs, clearedSecs + 1))",
                                        ja: "第\(min(totalSecs, clearedSecs + 1))節",
                                        ko: "\(min(totalSecs, clearedSecs + 1))세트",
                                        zhHant: "第\(min(totalSecs, clearedSecs + 1))節"
                                     )
                                     : l10n.t("islands.stagePlay"))
                                    .font(AppFont.rounded(size: 11.5, weight: .black))
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9.5, weight: .black, design: .rounded))
                            }
                            .foregroundColor(pal.bottom)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white))
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: pal, cornerRadius: 26, rimHeight: 6, whiteBorderWidth: 3.5, showStripeSheen: true, pressStyle: .card))
                .accessibilityIdentifier("IslandStageButton_\(stageNumber)")
            }

        case .cleared(let stars):
            Button {
                if totalSecs > 1 {
                    sectionPickerNode = node
                    SoundAndHapticsManager.shared.playUITap()
                } else {
                    launchNode(node)
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [AppTheme.mintTop, AppTheme.mintBottom], startPoint: .top, endPoint: .bottom))
                                .frame(width: 34, height: 34)
                            Image(systemName: earnedTier == .examCrown ? "crown.fill" : "checkmark")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text(node.rankBadge)
                            .font(AppFont.rounded(size: 11, weight: .black))
                            .foregroundColor(pal.bottom)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(pal.top.opacity(0.14)))
                    }

                    Text(localizedNodeTypeTag(node))
                        .font(AppFont.rounded(size: 10.5, weight: .heavy))
                        .foregroundColor(AppTheme.mintBottom)
                        .lineLimit(1)

                    Text(node.title(isChinese: l10n.language.isChinese))
                        .font(AppFont.rounded(size: 16, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)

                    Spacer(minLength: 2)

                    HStack(spacing: 3) {
                        ForEach(1...3, id: \.self) { starIdx in
                            Image(systemName: starIdx <= stars ? "star.fill" : "star")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(starIdx <= stars ? AppTheme.sunBottom : AppTheme.subtleBorder)
                        }
                        Spacer()
                        if let tier = earnedTier, tier > .normal {
                            Text(tier == .examCrown ? "👑" : "🔄")
                                .font(AppFont.rounded(size: 13, weight: .regular))
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
                            Image(systemName: "lock.fill").font(.system(size: 14, weight: .black, design: .rounded)).foregroundColor(.white)
                        }
                        Spacer()
                        Text(node.rankBadge)
                            .font(AppFont.rounded(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.50, green: 0.55, blue: 0.62))
                    }

                    Text(localizedNodeTypeTag(node))
                        .font(AppFont.rounded(size: 10.5, weight: .bold))
                        .foregroundColor(Color(red: 0.52, green: 0.56, blue: 0.63))
                        .lineLimit(1)

                    Text(node.title(isChinese: l10n.language.isChinese))
                        .font(AppFont.rounded(size: 16, weight: .heavy))
                        .foregroundColor(Color(red: 0.45, green: 0.49, blue: 0.56))
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)

                    Spacer(minLength: 2)

                    HStack(spacing: 3) {
                        ForEach(1...3, id: \.self) { _ in
                            Image(systemName: "star").font(.system(size: 13, design: .rounded)).foregroundColor(Color(red: 0.65, green: 0.69, blue: 0.75))
                        }
                        Spacer()
                        Text(l10n.t("islands.lockedBadge"))
                            .font(AppFont.rounded(size: 10.5, weight: .heavy))
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

    private func launchNode(_ node: CampaignNode, sectionIndex: Int? = nil) {
        SoundAndHapticsManager.shared.playUITap()
        switch node.kind {
        case .puzzleGauntlet:
            appState.refreshGauntletHearts()
            if appState.currentGauntletHearts <= 0 {
                pendingLaunchNodeAfterRecovery = node
                pendingLaunchSectionAfterRecovery = sectionIndex
                showMistakeReviewSheet = true
                return
            }
            let targetSection = sectionIndex ?? StarYiCampaign.nextSectionIndex(for: node, progress: appState.puzzleProgress)
            appState.navigationPath.append(.puzzleGauntlet(nodeId: node.id, masteryTier: selectedMasteryTier, sectionIndex: targetSection))
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

    // MARK: - Section Picker Sheet (for replaying any 5-puzzle set inside a cleared multi-section node)

    private func nodeSectionPickerSheet(for node: CampaignNode) -> some View {
        let cleared = StarYiCampaign.clearedSections(for: node, progress: appState.puzzleProgress)
        let columns = [GridItem(.adaptive(minimum: 132, maximum: 180), spacing: 12)]

        return NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(node.title(isChinese: l10n.language.isChinese))
                        .font(AppFont.rounded(size: 22, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text(l10n.localized(
                        zh: "共 \(node.puzzleIds.count) 题 · 分为 \(node.sectionCount) 个小节（每节 5 题）· 当前模式：\(localizedTierBadge(selectedMasteryTier))",
                        en: "\(node.puzzleIds.count) puzzles · \(node.sectionCount) sets (5Q each) · Mode: \(localizedTierBadge(selectedMasteryTier))",
                        ja: "全 \(node.puzzleIds.count) 問 · \(node.sectionCount) 節（各5問）· モード：\(localizedTierBadge(selectedMasteryTier))",
                        ko: "총 \(node.puzzleIds.count)문제 · \(node.sectionCount)세트 (각 5문제) · 모드: \(localizedTierBadge(selectedMasteryTier))",
                        zhHant: "共 \(node.puzzleIds.count) 題 · 分為 \(node.sectionCount) 個小節（每節 5 題）· 當前模式：\(localizedTierBadge(selectedMasteryTier))"
                    ))
                        .font(AppFont.rounded(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary)
                }
                .padding(.top, 8)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<node.sectionCount, id: \.self) { secIdx in
                            let sliceCount = node.puzzleIds(forSection: secIdx).count
                            let isDone = cleared.contains(secIdx)
                            Button {
                                sectionPickerNode = nil
                                launchNode(node, sectionIndex: secIdx)
                            } label: {
                                VStack(spacing: 6) {
                                    HStack {
                                        Text(l10n.localized(
                                            zh: "第 \(secIdx + 1) 节",
                                            en: "Set \(secIdx + 1)",
                                            ja: "第 \(secIdx + 1) 節",
                                            ko: "\(secIdx + 1)세트",
                                            zhHant: "第 \(secIdx + 1) 節"
                                        ))
                                            .font(AppFont.rounded(size: 15, weight: .black))
                                        Spacer()
                                        Image(systemName: isDone ? "checkmark.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 16, weight: .black))
                                            .foregroundColor(isDone ? AppTheme.mintBottom : pal.bottom)
                                    }
                                    HStack {
                                        Text(l10n.localized(
                                            zh: "\(sliceCount) 题",
                                            en: "\(sliceCount) puzzles",
                                            ja: "\(sliceCount) 問",
                                            ko: "\(sliceCount)문제",
                                            zhHant: "\(sliceCount) 題"
                                        ))
                                            .font(AppFont.rounded(size: 12, weight: .bold))
                                            .foregroundColor(AppTheme.inkSecondary)
                                        Spacer()
                                    }
                                }
                                .foregroundColor(AppTheme.inkPrimary)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(isDone ? AppTheme.mintTop.opacity(0.75) : pal.top.opacity(0.45), lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                }
            }
            .background(AppTheme.brightArenaBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.t("common.close")) {
                        sectionPickerNode = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
                                Label(boss.title(isChinese: l10n.language.isChinese), systemImage: bossDefeated ? "trophy.fill" : "flame.fill")
                                    .font(AppFont.rounded(size: 17, weight: .black))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                Text(l10n.t(bossDefeated ? "islands.bossDefeatedBadge" : "islands.bossUnlockedBadge"))
                                    .font(AppFont.rounded(size: 10.5, weight: .black))
                                    .foregroundColor(bossDefeated ? AppTheme.mintBottom : AppTheme.coralBottom)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.white))
                            }

                            Text(boss.tagline(isChinese: l10n.language.isChinese))
                                .font(AppFont.rounded(size: 12.5, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.94))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 6)

                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 26, weight: .black, design: .rounded))
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
                            Text(isCrossSea ? "✈️" : next.boss.difficulty.avatarEmoji).font(AppFont.rounded(size: 22, weight: .regular))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(isCrossSea
                                     ? l10n.localized(
                                        zh: "飞往新海域 · \(next.localizedName(l10n))",
                                        en: "Fly to New Sea · \(next.localizedName(l10n))",
                                        ja: "新海域へ出発 · \(next.localizedName(l10n))",
                                        ko: "새 해역으로 이동 · \(next.localizedName(l10n))",
                                        zhHant: "飛往新海域 · \(next.localizedName(l10n))"
                                     )
                                     : l10n.t("islands.nextIsland", next.localizedName(l10n)))
                                    .font(AppFont.rounded(size: 15, weight: .black))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(next.rankRange)
                                    .font(AppFont.rounded(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.92))
                            }
                            Image(systemName: "arrow.right.circle.fill").font(.system(size: 20, weight: .black, design: .rounded)).foregroundColor(.white)
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
                                .font(.system(size: 10.5, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color(red: 0.44, green: 0.49, blue: 0.56)).overlay(Circle().strokeBorder(.white, lineWidth: 1.5)))
                                .offset(x: 3, y: 3)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(boss.title(isChinese: l10n.language.isChinese))
                                    .font(AppFont.rounded(size: 16.5, weight: .black))
                                    .foregroundColor(Color(red: 0.44, green: 0.48, blue: 0.55))
                                Text(boss.difficulty.rankBadge)
                                    .font(AppFont.rounded(size: 11, weight: .bold))
                                    .foregroundColor(Color(red: 0.52, green: 0.56, blue: 0.63))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.58)))
                            }
                            Text(l10n.localized(
                                zh: "完成本岛全部 \(nodes.count) 关后自动解锁下一岛，并开启守岛 Boss 挑战！",
                                en: "Clear all \(nodes.count) stages to unlock the next island and challenge the Island Master Boss!",
                                ja: "この島の全 \(nodes.count) ステージをクリアすると次の島が解放され、島のボスに挑戦できます！",
                                ko: "이 섬의 \(nodes.count)개 스테이지를 모두 클리어하면 다음 섬이 열리고 섬 보스에 도전할 수 있어요!",
                                zhHant: "完成本島全部 \(nodes.count) 關後自動解鎖下一島，並開啟守島 Boss 挑戰！"
                            ))
                                .font(AppFont.rounded(size: 12.5, weight: .bold))
                                .foregroundColor(Color(red: 0.52, green: 0.56, blue: 0.63))
                        }

                        Spacer(minLength: 6)

                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill").font(.system(size: 11, weight: .black, design: .rounded))
                            Text(l10n.t("islands.lockedBadge")).font(AppFont.rounded(size: 12, weight: .black))
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
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color(red: 0.46, green: 0.51, blue: 0.59)))
            Text(message)
                .font(AppFont.rounded(size: 14.5, weight: .heavy))
                .foregroundColor(AppTheme.inkPrimary)
        }
        .padding(.leading, 10)
        .padding(.trailing, 20)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.white.opacity(0.96)).shadow(color: Color.black.opacity(0.16), radius: 14, y: 6))
        .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
    }

    private func localizedTierBadge(_ tier: StageMasteryTier) -> String {
        switch tier {
        case .normal:
            return l10n.localized(zh: "★ 普通", en: "★ Normal", ja: "★ 通常", ko: "★ 보통", zhHant: "★ 普通")
        case .transformed:
            return l10n.localized(zh: "🔄 旋转换色", en: "🔄 Flip", ja: "🔄 回転・反転", ko: "🔄 회전·반전", zhHant: "🔄 旋轉換色")
        case .examCrown:
            return l10n.localized(zh: "👑 无提示考", en: "👑 No-Hint", ja: "👑 ノーヒント", ko: "👑 노힌트 시험", zhHant: "👑 無提示考")
        }
    }

    private func localizedNodeTypeTag(_ node: CampaignNode) -> String {
        switch node.kind {
        case .puzzleGauntlet(let ids, let forceExam):
            let sections = node.sectionCount
            if forceExam {
                if sections > 1 {
                    return l10n.localized(
                        zh: "考场连闯 · \(ids.count)题（\(sections)节）",
                        en: "Exam · \(ids.count)Q (\(sections) Sets)",
                        ja: "試験 · \(ids.count)問（\(sections)節）",
                        ko: "시험 · \(ids.count)문제 (\(sections)세트)",
                        zhHant: "考場連闖 · \(ids.count)題（\(sections)節）"
                    )
                }
                return l10n.localized(
                    zh: "考场连闯 · \(ids.count)题",
                    en: "Exam Set · \(ids.count)Q",
                    ja: "試験チャレンジ · \(ids.count)問",
                    ko: "시험 연전 · \(ids.count)문제",
                    zhHant: "考場連闖 · \(ids.count)題"
                )
            }
            if sections > 1 {
                return l10n.localized(
                    zh: "题组连闯 · \(ids.count)题（\(sections)节）",
                    en: "Puzzle · \(ids.count)Q (\(sections) Sets)",
                    ja: "パズル · \(ids.count)問（\(sections)節）",
                    ko: "퍼즐 · \(ids.count)문제 (\(sections)세트)",
                    zhHant: "題組連闖 · \(ids.count)題（\(sections)節）"
                )
            }
            return l10n.localized(
                zh: "题组连闯 · \(ids.count)题",
                en: "Puzzle Set · \(ids.count)Q",
                ja: "連続パズル · \(ids.count)問",
                ko: "연속 퍼즐 · \(ids.count)문제",
                zhHant: "題組連闖 · \(ids.count)題"
            )
        case .miniDrill(let drillKind, _, let count):
            let title = drillKind.localizedTitle(l10n)
            return l10n.localized(
                zh: "\(title) · \(count)题",
                en: "\(title) · \(count)Q",
                ja: "\(title) · \(count)問",
                ko: "\(title) · \(count)문제",
                zhHant: "\(title) · \(count)題"
            )
        case .josekiTrial:
            return l10n.localized(
                zh: "定式破招课",
                en: "Joseki Trial",
                ja: "定石・ハメ手対策",
                ko: "정석·속임수 격파",
                zhHant: "定式破招課"
            )
        case .tacticalScenario:
            return l10n.localized(
                zh: "残局实战演练",
                en: "Tactical Duel",
                ja: "実戦シチュエーション",
                ko: "실전 전술 대결",
                zhHant: "殘局實戰演練"
            )
        }
    }
}
