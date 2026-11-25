//
//  GoPassportView.swift
//  StarYi Go — Animal Crossing-Style "Go Sailor Passport": 6-Axis Radar, 20-Island Stamp Book, Wax Seal & Collectible Stones
//

import SwiftUI
import UIKit

/// Pure calculator for the 6-axis Go Ability Radar Chart (unit-testable & deterministic).
enum GoRadarCalculator {
    struct AxisScore: Identifiable, Sendable {
        let category: PuzzleCategory
        let value: Double // 0.15 ... 1.0
        let solvedCount: Int
        let totalCount: Int
        var id: String { category.rawValue }
    }

    static func computeAxes(progress: PuzzleProgressStore) -> [AxisScore] {
        let catalog = DojoPuzzleBank.fullCatalog
        let grouped = Dictionary(grouping: catalog, by: { $0.category })
        let campaignBonus = Double(min(100, progress.totalCampaignStars)) / 500.0

        return PuzzleCategory.allCases.map { category in
            let puzzles = grouped[category] ?? []
            let total = max(1, puzzles.count)
            let solved = puzzles.filter { (progress.starsByPuzzleId[$0.id] ?? 0) > 0 }.count
            // Scale cleanly so even beginners see a growing polygon and masters reach 1.0
            let masteryRatio = min(1.0, Double(solved) / Double(max(6, min(24, total))))
            let value = min(1.0, max(0.16, 0.16 + masteryRatio * 0.74 + campaignBonus * 0.5))
            return AxisScore(category: category, value: value, solvedCount: solved, totalCount: puzzles.count)
        }
    }
}

struct GoPassportView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var gameCenter = GameCenterService.shared
    @State private var stoneFeedbackMessage: String? = nil
    @State private var renderedShareImage: UIImage? = nil

    private var l10n: L10n { appState.l10n }
    private var radarAxes: [GoRadarCalculator.AxisScore] {
        GoRadarCalculator.computeAxes(progress: appState.puzzleProgress)
    }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        passportIdentityCard
                        mySavedGamesCard
                        radarChartCard
                        stoneCabinetCard
                        islandStampBookCard
                        leaderboardsButton
                    }
                    .frame(maxWidth: 820)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 34)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            renderShareableSnapshot()
            gameCenter.authenticateIfNeeded()
            gameCenter.syncAllProgress(profile: appState.profile, puzzleProgress: appState.puzzleProgress)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            GameBackButton(title: l10n.t("common.back")) {
                appState.popRoute()
            }

            Spacer()

            GameTitleCrest(
                title: l10n.localized(
                    zh: "围棋航海护照",
                    en: "Go Sailor Passport",
                    ja: "囲碁・航海パスポート",
                    ko: "바둑 항해 여권",
                    zhHant: "圍棋航海護照"
                ),
                subtitle: l10n.localized(
                    zh: "星弈群岛官方段位认证与集章册",
                    en: "Official StarYi Rank Seal & \(StarYiCampaign.allIslands.count)-Island Stamp Book",
                    ja: "星囲諸島 公式棋力認定＆\(StarYiCampaign.allIslands.count)島スタンプ帳",
                    ko: "별바둑 군도 공식 급단 인증 및 \(StarYiCampaign.allIslands.count)개 섬 스탬프북",
                    zhHant: "星弈群島官方段位認證與集章冊"
                )
            )

            Spacer()

            if let shareImage = renderedShareImage {
                ShareLink(
                    item: Image(uiImage: shareImage),
                    preview: SharePreview(
                        "\(appState.profile.nickname) · \(appState.profile.rankString)",
                        image: Image(uiImage: shareImage)
                    )
                ) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .black))
                        Text(l10n.localized(zh: "分享护照", en: "Share", ja: "シェア", ko: "공유", zhHant: "分享護照"))
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
            } else {
                Color.clear.frame(width: 84, height: 36)
            }
        }
    }

    // MARK: - 1. Passport Identity Card with Nintendo Wax Seal

    private var passportIdentityCard: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                StarYiMascotView(
                    emojiKey: appState.profile.avatarEmoji,
                    size: 84,
                    mood: .proud
                )
                .shadow(color: AppTheme.sunBottom.opacity(0.32), radius: 10, y: 4)

                Text("Lv.\(appState.profile.adventureLevel)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppTheme.mintBottom))
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(appState.profile.nickname)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text(appState.settings.stoneStyle.badgeEmoji)
                        .font(.system(size: 16))
                }

                HStack(spacing: 12) {
                    statChip("⭐", "\(appState.puzzleProgress.totalStars)")
                    statChip("👑", "\(appState.puzzleProgress.defeatedBossIslandIds.count)/\(StarYiCampaign.allIslands.count)")
                    statChip("🔥", "\(appState.puzzleProgress.bestPuzzleRushScore)")
                    statChip("🪙", "\(appState.profile.starCoins)")
                }
            }

            Spacer(minLength: 8)

            // Certified Go Rank Wax Seal!
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppTheme.coralTop, AppTheme.coralBottom, Color(red: 0.68, green: 0.12, blue: 0.18)],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 42
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .strokeBorder(Color(red: 1.0, green: 0.88, blue: 0.56), style: StrokeStyle(lineWidth: 2.5, dash: [4, 3]))
                                .padding(5)
                        )
                        .shadow(color: AppTheme.coralBottom.opacity(0.35), radius: 8, y: 4)

                    VStack(spacing: 0) {
                        Text(l10n.localized(zh: "认证", en: "RANK", ja: "認定", ko: "인증", zhHant: "認證"))
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.92, blue: 0.68))
                        Text(appState.profile.rankString)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [.white, Color(red: 0.97, green: 0.95, blue: 0.89)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(AppTheme.sunTop.opacity(0.65), lineWidth: 3))
                .shadow(color: AppTheme.skyBottom.opacity(0.14), radius: 14, y: 6)
        )
    }

    private func statChip(_ emoji: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(emoji).font(.system(size: 12))
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.9)))
    }

    // MARK: - 1.5 Personal Match History (我的对局记录)

    private var mySavedGamesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text("\(l10n.t("archive.tab.myGames")) (\(appState.savedGames.count))")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(AppTheme.grapeBottom)
                }
                Spacer()
                Text(l10n.localized(
                    zh: "AI 复盘与战绩记录",
                    en: "AI Review & Replays",
                    ja: "AI復習＆対局記録",
                    ko: "AI 복기 및 대국 기록",
                    zhHant: "AI 復盤與戰績記錄"
                ))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
            }

            if appState.savedGames.isEmpty {
                HStack(spacing: 10) {
                    Text("📜").font(.system(size: 26))
                    Text(l10n.localized(
                        zh: "完成任意对局后会自动保存在这里，随时可以回看复盘！",
                        en: "Finished matches are saved right here for replay and AI review!",
                        ja: "対局が終わると自動的にここに保存され、いつでも見返せます！",
                        ko: "대국을 마치면 자동으로 여기에 저장되어 언제든 복기할 수 있어요!",
                        zhHant: "完成任意對局後會自動保存在這裡，隨時可以回看復盤！"
                    ))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppTheme.canvasBackground))
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.savedGames.prefix(20)) { record in
                        HStack(spacing: 10) {
                            Button {
                                appState.navigationPath.append(.reviewGame(recordId: record.id))
                            } label: {
                                HStack(spacing: 10) {
                                    Text("\(record.boardSize)×\(record.boardSize)")
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(AppTheme.skyBottom))

                                    Text(record.resultString)
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(AppTheme.sunBottom))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(record.blackName) vs \(record.whiteName)")
                                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                                            .foregroundColor(AppTheme.inkPrimary)
                                            .lineLimit(1)
                                        Text("\(l10n.t("game.moveCount", record.moveCount)) · \(record.date.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(AppTheme.inkSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppTheme.grapeBottom)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.95))
                                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppTheme.subtleBorder, lineWidth: 1.5))
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("ArchiveGameRecord")

                            Button(role: .destructive) {
                                appState.deleteSavedGame(id: record.id)
                            } label: {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.coralBottom)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(AppTheme.coralTop.opacity(0.12)))
                            }
                            .tactileButton(scale: 0.9)
                        }
                    }
                }
            }
        }
        .warmCard(cornerRadius: 24, padding: 16)
    }

    // MARK: - 2. Six-Axis Go Ability Radar Chart

    private var radarChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label {
                    Text(l10n.localized(
                        zh: "围棋六维棋力雷达",
                        en: "6-Axis Go Mastery Radar",
                        ja: "囲碁6能力レーダーチャート",
                        ko: "바둑 6대 능력 레이더 차트",
                        zhHant: "圍棋六維棋力雷達"
                    ))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                } icon: {
                    Image(systemName: "hexagon.fill")
                        .foregroundColor(AppTheme.skyBottom)
                }
                Spacer()
                Text(CoreMLGoAIEngine.shared.activeEngineBadge(l10n))
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.skyBottom)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.skyTop.opacity(0.12)))
            }

            HStack(spacing: 16) {
                GoRadarChartCanvas(axes: radarAxes, l10n: l10n)
                    .frame(width: 220, height: 220)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(radarAxes) { axis in
                        HStack(spacing: 8) {
                            Text(axis.category.localizedTitle(l10n))
                                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                .foregroundColor(AppTheme.inkPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(round(axis.value * 100)))%")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(AppTheme.skyBottom)
                        }
                        GeometryReader { barGeo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.canvasBackground)
                                Capsule()
                                    .fill(LinearGradient(colors: [AppTheme.skyTop, AppTheme.mintBottom], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(8, barGeo.size.width * axis.value))
                            }
                        }
                        .frame(height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .warmCard(cornerRadius: 26, padding: 18)
    }

    // MARK: - 3. Collectible Stone Skins Cabinet (Boss Rewards + Star Coins)

    private var stoneCabinetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(l10n.localized(
                        zh: "收藏级棋子皮肤（击败海域 Boss 解锁）",
                        en: "Collectible Stone Finishes (Boss Rewards)",
                        ja: "コレクション碁石スキン（ボス撃破で解放）",
                        ko: "수집용 바둑돌 스킨 (해역 보스 격파 보상)",
                        zhHant: "收藏級棋子皮膚（擊敗海域 Boss 解鎖）"
                    ))
                    .font(.system(size: 15.5, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundColor(AppTheme.sunBottom)
                }
                Spacer()
                if let msg = stoneFeedbackMessage {
                    Text(msg)
                        .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.coralBottom)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(StoneStyle.allCases) { style in
                    let unlocked = appState.isStoneStyleUnlocked(style)
                    let equipped = appState.settings.stoneStyle == style

                    Button {
                        if unlocked {
                            stoneFeedbackMessage = nil
                            appState.updateSettings { $0.stoneStyle = style }
                            SoundAndHapticsManager.shared.playStonePlace(at: BoardPoint(row: 4, col: 4), boardSize: 9, isAtari: false)
                        } else if appState.unlockStoneStyle(style) {
                            stoneFeedbackMessage = nil
                        } else {
                            stoneFeedbackMessage = style.unlockHint(l10n)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                stonePreviewOrb(style: style, isBlack: true)
                                stonePreviewOrb(style: style, isBlack: false)
                            }
                            .padding(.top, 4)

                            Text("\(style.badgeEmoji) \(style.displayName(l10n))")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(equipped ? AppTheme.skyBottom : AppTheme.inkPrimary)
                                .lineLimit(1)

                            Text(
                                equipped
                                ? l10n.localized(zh: "已装备", en: "Equipped", ja: "装備中", ko: "장착 중", zhHant: "已裝備")
                                : (unlocked
                                   ? l10n.localized(zh: "点击切换", en: "Tap to Equip", ja: "タップで変更", ko: "탭하여 장착", zhHant: "點擊切換")
                                   : style.unlockHint(l10n))
                            )
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(equipped ? AppTheme.mintBottom : AppTheme.inkSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(equipped ? AppTheme.skyTop.opacity(0.10) : AppTheme.canvasBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(equipped ? AppTheme.skyTop : Color.white, lineWidth: equipped ? 2.5 : 1.5)
                                )
                        )
                    }
                    .tactileCard(sound: false)
                }
            }
        }
        .warmCard(cornerRadius: 26, padding: 18)
    }

    private func stonePreviewOrb(style: StoneStyle, isBlack: Bool) -> some View {
        let colors: [Color] = {
            switch (style, isBlack) {
            case (.classicSlateShell, true):
                return [Color(white: 0.34), Color(white: 0.08)]
            case (.classicSlateShell, false):
                return [.white, Color(red: 0.85, green: 0.87, blue: 0.90)]
            case (.coralPearl, true):
                return [Color(red: 0.14, green: 0.32, blue: 0.44), Color(red: 0.04, green: 0.11, blue: 0.19)]
            case (.coralPearl, false):
                return [.white, Color(red: 0.86, green: 0.87, blue: 0.90)]
            case (.kyotoLacquer, true):
                return [Color(red: 0.25, green: 0.20, blue: 0.15), Color(red: 0.05, green: 0.04, blue: 0.03)]
            case (.kyotoLacquer, false):
                return [Color(red: 1.0, green: 0.97, blue: 0.88), Color(red: 0.91, green: 0.82, blue: 0.62)]
            case (.starlightJade, true):
                return [Color(red: 0.26, green: 0.22, blue: 0.56), Color(red: 0.06, green: 0.06, blue: 0.20)]
            case (.starlightJade, false):
                return [Color(red: 0.92, green: 1.0, blue: 0.96), Color(red: 0.68, green: 0.92, blue: 0.82)]
            }
        }()
        return Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 28, height: 28)
            .overlay(Circle().strokeBorder(Color.white.opacity(isBlack ? 0.2 : 0.9), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
    }

    // MARK: - 4. Multi-Sea Voyage Stamp Book

    private var islandStampBookCard: some View {
        let seaCount = StarYiCampaign.allSeas.count
        let islandCount = StarYiCampaign.allIslands.count
        return VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(l10n.localized(
                    zh: "\(seaCount) 大海域 · \(islandCount) 岛航海集章册",
                    en: "\(seaCount) Seas · \(islandCount)-Island Voyage Stamp Book",
                    ja: "\(seaCount)海域・\(islandCount)島 航海スタンプ帳",
                    ko: "\(seaCount)대 해역 · \(islandCount)개 섬 항해 스탬프북",
                    zhHant: "\(seaCount) 大海域 · \(islandCount) 島航海集章冊"
                ))
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
            } icon: {
                Image(systemName: "seal.fill")
                    .foregroundColor(AppTheme.coralBottom)
            }

            ForEach(StarYiCampaign.allSeas) { sea in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(sea.emoji) \(sea.localizedName(l10n))")
                            .font(.system(size: 13.5, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                        Spacer()
                        Text(sea.rankRange)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(AppTheme.skyBottom)
                    }

                    HStack(spacing: 8) {
                        ForEach(sea.islands) { island in
                            islandStampCell(island)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.78)))
            }
        }
        .warmCard(cornerRadius: 26, padding: 18)
    }

    private func islandStampCell(_ island: CampaignIsland) -> some View {
        let stars = StarYiCampaign.earnedStars(for: island, progress: appState.puzzleProgress)
        let bossBeaten = appState.puzzleProgress.defeatedBossIslandIds.contains(island.id)
        let stamped = bossBeaten || stars >= 3
        let strokeColor: Color = stamped ? AppTheme.sunBottom : AppTheme.subtleBorder
        let dash: [CGFloat] = stamped ? [] : [4, 3]

        return VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                StarYiMascotView(
                    difficulty: island.boss.difficulty,
                    size: 48,
                    mood: stamped ? .proud : .thinking,
                    showRing: stamped
                )
                .overlay(
                    Circle().strokeBorder(
                        strokeColor,
                        style: StrokeStyle(lineWidth: 2, dash: dash)
                    )
                )
                .opacity(stamped ? 1.0 : 0.45)

                if bossBeaten {
                    Text("👑")
                        .font(.system(size: 13))
                        .offset(x: 4, y: -4)
                }
            }

            Text(island.localizedName(l10n))
                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                .foregroundColor(stamped ? AppTheme.inkPrimary : AppTheme.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private var leaderboardsButton: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Game Center")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                        Text(
                            gameCenter.isAuthenticated
                            ? (gameCenter.playerDisplayName ?? l10n.localized(zh: "已连接 Apple Game Center", en: "Connected to Apple Game Center", ja: "Game Center 接続済み", ko: "Game Center 연결됨", zhHant: "已連接 Apple Game Center"))
                            : l10n.localized(zh: "登录同步全球排行、成就与好友回合对战", en: "Sign in for Leaderboards, Achievements & Friend Matches", ja: "サインインしてランキング・実績・フレンド対局を利用", ko: "로그인하여 글로벌 랭킹·업적·친구 대국 이용", zhHant: "登入同步全球排行、成就與好友回合對戰")
                        )
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                    }
                }
                Spacer()
                if !gameCenter.isAuthenticated {
                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        gameCenter.authenticateIfNeeded(presentLoginIfNeeded: true)
                    } label: {
                        Text(l10n.localized(zh: "登录", en: "Sign In", ja: "サインイン", ko: "로그인", zhHant: "登入"))
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2))
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.mintBottom)
                        .accessibilityLabel(l10n.localized(zh: "已登录 Game Center", en: "Signed in to Game Center", ja: "Game Center サインイン済み", ko: "Game Center 로그인됨", zhHant: "已登入 Game Center"))
                }
            }

            HStack(spacing: 10) {
                Button {
                    SoundAndHapticsManager.shared.playUITap()
                    gameCenter.presentLeaderboards()
                } label: {
                    Label(
                        l10n.localized(zh: "全球排行", en: "Leaderboards", ja: "ランキング", ko: "랭킹", zhHant: "全球排行"),
                        systemImage: "trophy.fill"
                    )
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))

                Button {
                    SoundAndHapticsManager.shared.playUITap()
                    gameCenter.presentAchievements()
                } label: {
                    Label(
                        l10n.localized(zh: "成就勋章", en: "Achievements", ja: "実績バッジ", ko: "업적 배지", zhHant: "成就勳章"),
                        systemImage: "rosette"
                    )
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .sun, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))

                if !gameCenter.isMultiplayerRestricted {
                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        gameCenter.presentTurnBasedFriendMatch()
                    } label: {
                        Label(
                            l10n.localized(zh: "好友对战", en: "Friends", ja: "フレンド", ko: "친구 대국", zhHant: "好友對戰"),
                            systemImage: "person.2.fill"
                        )
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                }
            }
        }
        .warmCard(cornerRadius: 24, padding: 16)
    }

    @MainActor
    private func renderShareableSnapshot() {
        let snapshot = VStack(spacing: 14) {
            passportIdentityCard
            radarChartCard
        }
        .padding(20)
        .frame(width: 520)
        .background(AppTheme.brightArenaBackground)

        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = 2.0
        renderedShareImage = renderer.uiImage
    }
}

/// Crisp custom Canvas hexagonal 6-Axis Go Ability Radar Chart.
private struct GoRadarChartCanvas: View {
    let axes: [GoRadarCalculator.AxisScore]
    let l10n: L10n

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = min(size.width, size.height) * 0.36
            let count = max(3, axes.count)

            func point(index: Int, radius: CGFloat) -> CGPoint {
                let angle = -CGFloat.pi / 2 + CGFloat(index) * (2 * .pi / CGFloat(count))
                return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            }

            // Concentric rings
            for step in 1...4 {
                let r = maxR * CGFloat(step) / 4.0
                var ring = Path()
                for i in 0..<count {
                    let pt = point(index: i, radius: r)
                    if i == 0 { ring.move(to: pt) } else { ring.addLine(to: pt) }
                }
                ring.closeSubpath()
                ctx.stroke(ring, with: .color(AppTheme.skyBottom.opacity(step == 4 ? 0.28 : 0.14)), lineWidth: step == 4 ? 1.5 : 1)
            }

            // Spokes
            for i in 0..<count {
                var spoke = Path()
                spoke.move(to: center)
                spoke.addLine(to: point(index: i, radius: maxR))
                ctx.stroke(spoke, with: .color(AppTheme.skyBottom.opacity(0.16)), lineWidth: 1)
            }

            // Filled Mastery Polygon
            var poly = Path()
            for (i, axis) in axes.enumerated() {
                let pt = point(index: i, radius: maxR * CGFloat(axis.value))
                if i == 0 { poly.move(to: pt) } else { poly.addLine(to: pt) }
            }
            poly.closeSubpath()
            ctx.fill(poly, with: .color(AppTheme.skyTop.opacity(0.32)))
            ctx.stroke(poly, with: .color(AppTheme.skyBottom), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))

            // Vertex dots + Labels
            for (i, axis) in axes.enumerated() {
                let pt = point(index: i, radius: maxR * CGFloat(axis.value))
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)), with: .color(AppTheme.mintBottom))
                ctx.stroke(Path(ellipseIn: CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)), with: .color(.white), lineWidth: 1.5)

                let labelPt = point(index: i, radius: maxR + 22)
                let labelText = Text(axis.category.localizedTitle(l10n))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                ctx.draw(labelText, at: labelPt, anchor: .center)
            }
        }
    }
}
