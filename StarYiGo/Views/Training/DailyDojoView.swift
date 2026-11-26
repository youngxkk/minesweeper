//
//  DailyDojoView.swift
//  StarYi Go — Nintendo-Grade Daily Dojo (每日道场) Hub, Stamp Calendar & Interactive Knowledge Station
//

import SwiftUI

struct DailyDojoView: View {
    @EnvironmentObject var appState: AppState
    @State private var showStampCelebration: Bool = false
    @State private var lastClaimedCoins: Int = 0
    @State private var lastClaimedMilestones: [StampMilestone] = []
    @State private var stampPopScale: CGFloat = 1.0
    @State private var inspectedTerm: GoCodexEntry? = nil

    private var l10n: L10n { appState.l10n }
    private var plan: DailyDojoPlan { appState.todayDailyDojoPlan() }
    private var todayStamp: String { plan.dateStamp }

    private var isWarmupDone: Bool {
        appState.profile.dailyDojoDateStamp == todayStamp && appState.profile.dailyDojoWarmupDone
    }

    private var coreSolvedCount: Int {
        DailyDojoSystem.coreSolvedCount(profile: appState.profile, plan: plan)
    }

    private var isCoreDone: Bool {
        DailyDojoSystem.isCoreStationDone(profile: appState.profile, plan: plan)
    }

    private var isKnowledgeDone: Bool {
        appState.profile.dailyDojoDateStamp == todayStamp && appState.profile.dailyDojoKnowledgeDone
    }

    private var stationsDone: Int {
        DailyDojoSystem.completedStationsCount(profile: appState.profile, plan: plan)
    }

    private var isStampedToday: Bool {
        appState.profile.dailyDojoDateStamp == todayStamp && appState.profile.dailyDojoStampClaimedToday
    }

    private var canClaimStamp: Bool {
        stationsDone >= 3 && !isStampedToday
    }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            GeometryReader { geo in
                let isCompact = geo.size.width < 760
                let pad: CGFloat = isCompact ? 14 : 24

                VStack(spacing: 14) {
                    // Top Bar
                    HStack {
                        GameBackButton(title: l10n.t("common.back")) {
                            appState.popRoute()
                        }
                        Spacer()
                        GameTitleCrest(
                            title: l10n.localized(
                                zh: "每日道场",
                                en: "Daily Dojo",
                                ja: "毎日道場",
                                ko: "매일 도장",
                                zhHant: "每日道場"
                            ),
                            subtitle: plan.weekdayThemeLabel(l10n)
                        )
                        Spacer()
                        // Streak & Total Stamps pill
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(AppTheme.coralBottom)
                                Text("\(appState.profile.dailyStreak)")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundColor(AppTheme.inkPrimary)
                            }
                            Divider().frame(height: 16)
                            HStack(spacing: 4) {
                                Image(systemName: "seal.fill")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(AppTheme.sunBottom)
                                Text("\(appState.profile.dailyDojoStampDates.count)")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundColor(AppTheme.inkPrimary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.95))
                                .shadow(color: AppTheme.inkPrimary.opacity(0.10), radius: 5, y: 2)
                        )
                    }
                    .frame(height: 58)

                    ScrollView(showsIndicators: false) {
                        if isCompact {
                            VStack(spacing: 16) {
                                heroThemeBanner
                                if canClaimStamp {
                                    claimStampCTA
                                }
                                stationOneWarmupCard
                                stationTwoCoreGauntletCard
                                stationThreeKnowledgeCard
                                stampCalendarCard
                            }
                            .padding(.bottom, 24)
                        } else {
                            HStack(alignment: .top, spacing: 20) {
                                VStack(spacing: 14) {
                                    heroThemeBanner
                                    if canClaimStamp {
                                        claimStampCTA
                                    }
                                    stationOneWarmupCard
                                    stationTwoCoreGauntletCard
                                    stationThreeKnowledgeCard
                                }
                                .frame(maxWidth: .infinity)

                                stampCalendarCard
                                    .frame(width: min(370, max(310, geo.size.width * 0.34)))
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 12)
            }

            if showStampCelebration {
                ConfettiBurstView()
                    .ignoresSafeArea()
                    .zIndex(18)

                stampCelebrationModal
                    .zIndex(25)
            }

            if let term = inspectedTerm {
                Color(red: 0.08, green: 0.14, blue: 0.26).opacity(0.42)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) { inspectedTerm = nil }
                    }
                    .zIndex(28)

                GoTermQuickCard(
                    entry: term,
                    l10n: l10n,
                    onOpenCodex: {
                        inspectedTerm = nil
                        appState.navigationPath.append(.codex)
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) { inspectedTerm = nil }
                    }
                )
                .padding(24)
                .zIndex(30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Hero Banner

    private var heroThemeBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.32), lineWidth: 6)
                    .frame(width: 62, height: 62)
                Circle()
                    .trim(from: 0, to: Double(stationsDone) / 3.0)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 62, height: 62)
                if isStampedToday {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(AppTheme.sunTop)
                } else {
                    Text("\(stationsDone)/3")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(l10n.localized(
                        zh: "今日主题 · \(plan.themeCodex.term(l10n))",
                        en: "Today's Focus · \(plan.themeCodex.term(l10n))",
                        ja: "今日のテーマ · \(plan.themeCodex.term(l10n))",
                        ko: "오늘의 주제 · \(plan.themeCodex.term(l10n))",
                        zhHant: "今日主題 · \(plan.themeCodex.term(l10n))"
                    ))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                            inspectedTerm = plan.themeCodex
                        }
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                }

                Text(isStampedToday
                     ? l10n.localized(
                        zh: "今日三关全部通关并已盖章！明天继续解锁新招法！",
                        en: "All 3 stations cleared & stamped today! Come back tomorrow for a new skill!",
                        ja: "今日の3ステージ達成＆スタンプ完了！明日も新しい技に挑戦しよう！",
                        ko: "오늘 3단계 완료 및 도장 획득! 내일 새로운 기술에 도전해요!",
                        zhHant: "今日三關全部通關並已蓋章！明天繼續解鎖新招法！"
                     )
                     : l10n.localized(
                        zh: "无提示独立思考 · 完成 3 站修行即可盖下今日印章，领星币宝箱！",
                        en: "No-hint training · Clear all 3 stations to stamp today's calendar & open the chest!",
                        ja: "ヒントなし特訓 · 3つクリアして今日のスタンプ＆宝箱をゲット！",
                        ko: "힌트 없는 수련 · 3단계 모두 완료하고 오늘의 도장과 보물상자를 열어요!",
                        zhHant: "無提示獨立思考 · 完成 3 站修行即可蓋下今日印章，領星幣寶箱！"
                     ))
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isStampedToday
                            ? [AppTheme.sunTop, AppTheme.sunBottom]
                            : [Color(red: 0.03, green: 0.52, blue: 0.57), Color(red: 0.01, green: 0.35, blue: 0.42)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(.white.opacity(0.85), lineWidth: 3)
                )
                .shadow(color: AppTheme.inkPrimary.opacity(0.14), radius: 10, y: 5)
        )
    }

    // MARK: - Big Tactile Stamp CTA (when 3/3 done!)

    private var claimStampCTA: some View {
        Button {
            let result = appState.claimDailyDojoStamp()
            lastClaimedCoins = result.coinsEarned
            lastClaimedMilestones = result.newMilestones
            withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
                showStampCelebration = true
                stampPopScale = 1.12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    stampPopScale = 1.0
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 24, weight: .black))
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.localized(
                        zh: "盖下今日道场印章！",
                        en: "Stamp Today's Calendar!",
                        ja: "今日の道場スタンプを押す！",
                        ko: "오늘의 도장 찍기!",
                        zhHant: "蓋下今日道場印章！"
                    ))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    Text(l10n.localized(
                        zh: "开启今日宝箱：+40 星币 · +50 XP",
                        en: "Open Daily Chest: +40 Star Coins · +50 XP",
                        ja: "今日の宝箱：+40 星コイン · +50 XP",
                        ko: "오늘의 보물상자: +40 별코인 · +50 XP",
                        zhHant: "開啟今日寶箱：+40 星幣 · +50 XP"
                    ))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .opacity(0.95)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .black))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .sun, cornerRadius: 24, rimHeight: 6, whiteBorderWidth: 3.5, showStripeSheen: true))
        .accessibilityIdentifier("DailyDojoClaimStampButton")
    }

    // MARK: - Station 1: Warmup Mini-Drill

    private var stationOneWarmupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                stationBadge(number: "1", done: isWarmupDone, colors: [AppTheme.mintTop, AppTheme.mintBottom])
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.localized(
                        zh: "第一站 · 热身棋感小游戏",
                        en: "Station 1 · Go Sense Warmup",
                        ja: "第1駅・ウォームアップ",
                        ko: "1단계 · 워밍업 미니 훈련",
                        zhHant: "第一站 · 熱身棋感小遊戲"
                    ))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)

                    Text(l10n.localized(
                        zh: "\(plan.warmupKind.localizedTitle(l10n)) · \(plan.warmupCount) 题（约 1 分钟）",
                        en: "\(plan.warmupKind.localizedTitle(l10n)) · \(plan.warmupCount) Qs (~1 min)",
                        ja: "\(plan.warmupKind.localizedTitle(l10n)) · \(plan.warmupCount)問（約1分）",
                        ko: "\(plan.warmupKind.localizedTitle(l10n)) · \(plan.warmupCount)문제 (약 1분)",
                        zhHant: "\(plan.warmupKind.localizedTitle(l10n)) · \(plan.warmupCount) 題（約 1 分鐘）"
                    ))
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                }
                Spacer()
                Button {
                    appState.navigationPath.append(
                        .miniDrill(
                            kind: plan.warmupKind,
                            campaignNodeId: nil,
                            startOffset: plan.warmupStartOffset,
                            targetCount: plan.warmupCount,
                            isDailyDojoWarmup: true
                        )
                    )
                } label: {
                    Text(isWarmupDone
                         ? l10n.localized(zh: "再热身", en: "Replay", ja: "もう一度", ko: "다시 하기", zhHant: "再熱身")
                         : l10n.localized(zh: "开始热身", en: "Warm Up", ja: "スタート", ko: "시작", zhHant: "開始熱身"))
                        .font(.system(size: 13.5, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: isWarmupDone ? .sky : .mint, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                .accessibilityIdentifier("DailyDojoWarmupButton")
            }
        }
        .warmCard(cornerRadius: 24, padding: 16)
    }

    // MARK: - Station 2: No-Hint 3-Puzzle Theme Gauntlet

    private var stationTwoCoreGauntletCard: some View {
        let queueIds = plan.corePuzzleIds
        let firstUnsolvedSlot = plan.coreSlots.first { !appState.profile.dailyDojoCoreSolvedIds.contains($0.puzzle.id) } ?? plan.coreSlots[0]

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                stationBadge(number: "2", done: isCoreDone, colors: [AppTheme.coralTop, AppTheme.coralBottom])
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(l10n.localized(
                            zh: "第二站 · 无提示主题三连战",
                            en: "Station 2 · No-Hint 3-Stage Trial",
                            ja: "第2駅・ヒントなし3連戦",
                            ko: "2단계 · 힌트 없는 3연전",
                            zhHant: "第二站 · 無提示主題三連戰"
                        ))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)

                        Text("\(coreSolvedCount)/3")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(isCoreDone ? AppTheme.mintBottom : AppTheme.coralBottom))
                    }

                    Text(l10n.localized(
                        zh: "全程禁止提示和看答案！靠自己反复试错通关，赢「一击必杀」或「百折不挠」荣誉！",
                        en: "Zero hints & zero solution peeks! Think, test, and earn One-Shot or Unstoppable honors!",
                        ja: "ヒント・答え表示なし！自分の力で考えてクリアしよう！",
                        ko: "힌트·정답 보기 없음! 스스로 생각하고 도전해 클리어하세요!",
                        zhHant: "全程禁止提示和看答案！靠自己反覆試錯通關，贏「一擊必殺」或「百折不撓」榮譽！"
                    ))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                }
                Spacer(minLength: 8)
                Button {
                    appState.navigationPath.append(
                        .puzzlePlay(
                            puzzleId: firstUnsolvedSlot.puzzle.id,
                            isDailyChallenge: true,
                            isStarterBootcamp: false,
                            forceRandomTransform: firstUnsolvedSlot.stage.forceRandomTransform,
                            dailyDojoQueueIds: queueIds
                        )
                    )
                } label: {
                    Text(isCoreDone
                         ? l10n.localized(zh: "再挑战", en: "Replay", ja: "もう一度", ko: "다시 하기", zhHant: "再挑戰")
                         : (coreSolvedCount == 0
                            ? l10n.localized(zh: "开始挑战", en: "Start", ja: "スタート", ko: "시작", zhHant: "開始挑戰")
                            : l10n.localized(zh: "继续第 \(coreSolvedCount + 1) 关", en: "Stage \(coreSolvedCount + 1)", ja: "第\(coreSolvedCount + 1)問へ", ko: "\(coreSolvedCount + 1)단계", zhHant: "繼續第 \(coreSolvedCount + 1) 關")))
                        .font(.system(size: 13.5, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityIdentifier("DailyDojoStartCoreButton")
            }

            HStack(spacing: 10) {
                ForEach(plan.coreSlots) { slot in
                    let solved = appState.profile.dailyDojoDateStamp == todayStamp && appState.profile.dailyDojoCoreSolvedIds.contains(slot.puzzle.id)
                    let firstTry = appState.profile.dailyDojoDateStamp == todayStamp && appState.profile.dailyDojoCoreFirstTryIds.contains(slot.puzzle.id)

                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        appState.navigationPath.append(
                            .puzzlePlay(
                                puzzleId: slot.puzzle.id,
                                isDailyChallenge: true,
                                isStarterBootcamp: false,
                                forceRandomTransform: slot.stage.forceRandomTransform,
                                dailyDojoQueueIds: queueIds
                            )
                        )
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        solved
                                        ? LinearGradient(
                                            colors: firstTry ? [AppTheme.sunTop, AppTheme.sunBottom] : [AppTheme.coralTop, AppTheme.coralBottom],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        : LinearGradient(colors: [AppTheme.canvasBackground, AppTheme.subtleBorder.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                                    )
                                    .frame(width: 44, height: 44)
                                if solved {
                                    Image(systemName: firstTry ? "crown.fill" : "flame.fill")
                                        .font(.system(size: 19, weight: .black))
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(slot.stage.rawValue + 1)")
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                        .foregroundColor(AppTheme.inkPrimary)
                                }
                            }

                            Text(slot.stage.badge(l10n, isRevenge: slot.isRevenge))
                                .font(.system(size: 11.5, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.inkPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(solved
                                 ? (firstTry
                                    ? l10n.localized(zh: "一击必杀", en: "1-Shot", ja: "一撃", ko: "원샷", zhHant: "一擊必殺")
                                    : l10n.localized(zh: "百折不挠", en: "Grit", ja: "不屈", ko: "불굴", zhHant: "百折不撓"))
                                 : slot.puzzle.rankBadge)
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(solved ? (firstTry ? AppTheme.sunBottom : AppTheme.coralBottom) : AppTheme.inkSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(solved ? AppTheme.sunBottom.opacity(0.6) : AppTheme.subtleBorder, lineWidth: 2)
                                )
                        )
                    }
                    .tactileButton(scale: 0.95, sound: false)
                    .accessibilityIdentifier("DailyDojoCoreSlot\(slot.stage.rawValue)")
                }
            }
        }
        .warmCard(cornerRadius: 24, padding: 16)
    }

    // MARK: - Station 3: Interactive Daily Knowledge Card

    private var stationThreeKnowledgeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                stationBadge(number: "3", done: isKnowledgeDone, colors: [AppTheme.grapeTop, AppTheme.grapeBottom])
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.localized(
                        zh: "第三站 · 今日棋道一问（涨知识）",
                        en: "Station 3 · Daily Go Wisdom Quiz",
                        ja: "第3駅・今日の囲碁クイズ",
                        ko: "3단계 · 오늘의 바둑 지식 퀴즈",
                        zhHant: "第三站 · 今日棋道一問（漲知識）"
                    ))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)

                    Text("\(plan.knowledgeEntry.hall.title(l10n)) · \(plan.knowledgeEntry.title(l10n))")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    appState.navigationPath.append(.dailyKnowledge)
                } label: {
                    Text(isKnowledgeDone
                         ? l10n.localized(zh: "再回味", en: "Review", ja: "復習する", ko: "다시 보기", zhHant: "再回味")
                         : l10n.localized(zh: "去猜一猜", en: "Take Quiz", ja: "挑戦する", ko: "퀴즈 풀기", zhHant: "去猜一猜"))
                        .font(.system(size: 13.5, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: isKnowledgeDone ? .sky : .grape, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                .accessibilityIdentifier("DailyDojoKnowledgeButton")
            }
        }
        .warmCard(cornerRadius: 24, padding: 16)
    }

    // MARK: - Monthly Stamp Calendar & Milestone Track

    private var stampCalendarCard: some View {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let firstOfMonth = cal.date(from: comps) ?? now
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let firstWeekday = cal.component(.weekday, from: firstOfMonth) // 1 = Sun
        let leadingBlanks = max(0, firstWeekday - 1)
        let year = comps.year ?? 2026
        let month = comps.month ?? 1
        let todayDay = cal.component(.day, from: now)
        let totalStamps = appState.profile.dailyDojoStampDates.count
        let weekdayHeaders: [String] = {
            switch l10n.language.resolvedCode {
            case "zh-Hans", "zh-Hant": return ["日", "一", "二", "三", "四", "五", "六"]
            case "ja": return ["日", "月", "火", "水", "木", "金", "土"]
            case "ko": return ["일", "월", "화", "수", "목", "금", "토"]
            default: return ["S", "M", "T", "W", "T", "F", "S"]
            }
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(AppTheme.sunBottom)
                Text(l10n.localized(
                    zh: "\(year)年\(month)月 · 道场印章册",
                    en: "\(year)-\(String(format: "%02d", month)) · Stamp Calendar",
                    ja: "\(year)年\(month)月・道場スタンプ帳",
                    ko: "\(year)년 \(month)월 · 도장 달력",
                    zhHant: "\(year)年\(month)月 · 道場印章冊"
                ))
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
                Spacer()
                Text(l10n.localized(
                    zh: "\(totalStamps) 枚",
                    en: "\(totalStamps) stamps",
                    ja: "\(totalStamps) 個",
                    ko: "\(totalStamps)개",
                    zhHant: "\(totalStamps) 枚"
                ))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.sunBottom)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.softGoldBg))
            }

            // Weekday Header Row
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(0..<7, id: \.self) { idx in
                    Text(weekdayHeaders[idx])
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                }

                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 34)
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    let stampKey = String(format: "%04d-%02d-%02d", year, month, day)
                    let isStamped = appState.profile.dailyDojoStampDates.contains(stampKey)
                    let isToday = (day == todayDay)

                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isStamped ? AppTheme.softGoldBg : (isToday ? AppTheme.skyTop.opacity(0.16) : AppTheme.canvasBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        isToday ? AppTheme.skyBottom : (isStamped ? AppTheme.sunBottom.opacity(0.65) : Color.clear),
                                        lineWidth: isToday ? 2 : 1.5
                                    )
                            )
                        if isStamped {
                            Image(systemName: "seal.fill")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(LinearGradient(colors: [AppTheme.coralTop, AppTheme.coralBottom], startPoint: .top, endPoint: .bottom))
                                .scaleEffect(isToday ? stampPopScale : 1.0)
                        } else {
                            Text("\(day)")
                                .font(.system(size: 12, weight: isToday ? .black : .bold, design: .rounded))
                                .foregroundColor(isToday ? AppTheme.skyBottom : AppTheme.inkSecondary)
                        }
                    }
                    .frame(height: 34)
                }
            }

            Divider()

            // Stamp Milestone Chests
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.localized(
                    zh: "累计印章奖励",
                    en: "Stamp Milestone Chests",
                    ja: "累計スタンプ報酬",
                    ko: "누적 도장 보상",
                    zhHant: "累計印章獎勵"
                ))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)

                HStack(spacing: 8) {
                    ForEach(DailyDojoSystem.stampMilestones) { milestone in
                        let reached = totalStamps >= milestone.requiredStamps
                        VStack(spacing: 4) {
                            Image(systemName: reached ? "checkmark.seal.fill" : "gift.fill")
                                .font(.system(size: 17, weight: .black))
                                .foregroundColor(reached ? AppTheme.mintBottom : AppTheme.sunBottom)
                            Text(l10n.localized(
                                zh: "\(milestone.requiredStamps)天",
                                en: "\(milestone.requiredStamps)d",
                                ja: "\(milestone.requiredStamps)日",
                                ko: "\(milestone.requiredStamps)일",
                                zhHant: "\(milestone.requiredStamps)天"
                            ))
                                .font(.system(size: 11.5, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.inkPrimary)
                            Text("+\(milestone.coinReward)")
                                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                .foregroundColor(AppTheme.sunBottom)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(reached ? AppTheme.mintTop.opacity(0.14) : AppTheme.canvasBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(reached ? AppTheme.mintBottom.opacity(0.55) : Color.clear, lineWidth: 1.5)
                                )
                        )
                    }
                }
            }
        }
        .warmCard(cornerRadius: 24, padding: 16)
    }

    // MARK: - Helpers

    private func stationBadge(number: String, done: Bool, colors: [Color]) -> some View {
        ZStack {
            Circle()
                .fill(
                    done
                    ? LinearGradient(colors: [AppTheme.mintTop, AppTheme.mintBottom], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 40, height: 40)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.white)
            } else {
                Text(number)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }

    private var stampCelebrationModal: some View {
        ZStack {
            Color(red: 0.08, green: 0.14, blue: 0.26).opacity(0.48)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showStampCelebration = false }
                }

            VStack(spacing: 14) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [AppTheme.coralTop, AppTheme.coralBottom], startPoint: .top, endPoint: .bottom))

                Text(l10n.localized(
                    zh: "咚！今日印章已盖好！",
                    en: "Stamped! Daily Dojo Complete!",
                    ja: "ポン！今日のスタンプ獲得！",
                    ko: "꾹! 오늘의 도장 완료!",
                    zhHant: "咚！今日印章已蓋好！"
                ))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)

                Text(l10n.localized(
                    zh: "获得 +\(lastClaimedCoins) 星币 · +50 XP！每天坚持思考，棋力天天涨！",
                    en: "Earned +\(lastClaimedCoins) Star Coins · +50 XP! Daily thinking builds real strength!",
                    ja: "+\(lastClaimedCoins) 星コイン・+50 XP獲得！毎日の積み重ねが力になるよ！",
                    ko: "+\(lastClaimedCoins) 별코인 · +50 XP 획득! 매일 생각하는 습관이 실력을 키워요!",
                    zhHant: "獲得 +\(lastClaimedCoins) 星幣 · +50 XP！每天堅持思考，棋力天天漲！"
                ))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)

                if !lastClaimedMilestones.isEmpty {
                    ForEach(lastClaimedMilestones) { m in
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(AppTheme.sunBottom)
                            Text(l10n.localized(
                                zh: "达成里程碑：\(m.title(l10n))（+\(m.coinReward) 星币）",
                                en: "Milestone Unlocked: \(m.title(l10n)) (+\(m.coinReward) Coins)",
                                ja: "マイルストーン達成：\(m.title(l10n))",
                                ko: "마일스톤 달성: \(m.title(l10n))",
                                zhHant: "達成里程碑：\(m.title(l10n))（+\(m.coinReward) 星幣）"
                            ))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.sunBottom)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.softGoldBg))
                    }
                }

                Button {
                    withAnimation { showStampCelebration = false }
                } label: {
                    Text(l10n.localized(zh: "太棒了！", en: "Awesome!", ja: "やったね！", ko: "최고예요!", zhHant: "太棒了！"))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
            }
            .padding(24)
            .frame(maxWidth: 380)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(AppTheme.sunBottom, lineWidth: 3.5))
                    .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
            )
            .padding(20)
        }
    }
}

// MARK: - Station 3: Interactive Daily Go Knowledge Quiz (今日棋道一问)

struct DailyKnowledgeQuizView: View {
    @EnvironmentObject var appState: AppState

    @State private var boardState: GoBoardState = GoBoardState(size: 9)
    @State private var targetPoint: BoardPoint? = nil
    @State private var targetColor: StoneColor = .black
    @State private var targetComment: String = ""
    @State private var attempts: Int = 0
    @State private var solved: Bool = false
    @State private var feedbackMessage: String? = nil
    @State private var showingCounterExample: Bool = false
    @State private var counterStates: [GoBoardState] = []
    @State private var counterComments: [String?] = []
    @State private var counterStep: Int = 0
    @State private var wrongFlashPoint: BoardPoint? = nil
    @State private var wrongFlashID: UUID = UUID()

    private var l10n: L10n { appState.l10n }
    private var plan: DailyDojoPlan { appState.todayDailyDojoPlan() }
    private var entry: AcademyEntry { plan.knowledgeEntry }

    private var activeDisplayState: GoBoardState {
        if showingCounterExample, !counterStates.isEmpty {
            return counterStates[min(max(0, counterStep), counterStates.count - 1)]
        }
        return boardState
    }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            GeometryReader { geo in
                let isCompact = geo.size.width < 720
                let pad: CGFloat = isCompact ? 14 : 22

                VStack(spacing: 12) {
                    HStack {
                        GameBackButton(title: l10n.t("common.back")) {
                            appState.popRoute()
                        }
                        Spacer()
                        GameTitleCrest(
                            title: entry.title(l10n),
                            subtitle: l10n.localized(
                                zh: "今日棋道一问 · \(entry.hall.title(l10n))",
                                en: "Daily Wisdom · \(entry.hall.title(l10n))",
                                ja: "今日の囲碁クイズ · \(entry.hall.title(l10n))",
                                ko: "오늘의 바둑 퀴즈 · \(entry.hall.title(l10n))",
                                zhHant: "今日棋道一問 · \(entry.hall.title(l10n))"
                            )
                        )
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .frame(height: 58)

                    if isCompact {
                        let boardSide = max(240, min(geo.size.width - pad * 2, geo.size.height * 0.45))
                        knowledgeBoard.frame(width: boardSide, height: boardSide)
                        ScrollView(showsIndicators: false) {
                            knowledgeSidePanel
                        }
                    } else {
                        let sideW = min(390, max(324, geo.size.width * 0.34))
                        let boardSide = max(260, min(geo.size.width - sideW - pad * 3, geo.size.height - 90))
                        HStack(spacing: pad) {
                            knowledgeBoard
                                .frame(width: boardSide, height: boardSide)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            ScrollView(showsIndicators: false) {
                                knowledgeSidePanel
                            }
                            .frame(width: sideW)
                        }
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 12)
            }

            if solved {
                ConfettiBurstView()
                    .ignoresSafeArea()
                    .zIndex(15)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            loadKnowledgePosition()
        }
    }

    private var knowledgeBoard: some View {
        GoBoardView(
            boardState: activeDisplayState,
            theme: appState.settings.boardTheme,
            stoneStyle: appState.settings.stoneStyle,
            showCoordinates: appState.settings.showCoordinates,
            showMoveNumbers: false,
            highlightAtari: false,
            expressiveStones: false,
            showTwoEyeGlow: false,
            previewColor: targetColor,
            isInteractive: !solved && !showingCounterExample && targetPoint != nil,
            illegalFlashPoint: wrongFlashPoint,
            illegalEventID: wrongFlashID,
            libertyBadgeFormat: l10n.t("game.libertiesBadge"),
            koBadgeLabel: l10n.t("board.koBadge"),
            onSelectPoint: { pt in
                handleQuizTap(at: pt)
            }
        )
    }

    private var knowledgeSidePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Quiz / Story Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(entry.eraOrTag(l10n))
                        .font(.system(size: 11.5, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(LinearGradient(colors: [AppTheme.grapeTop, AppTheme.grapeBottom], startPoint: .top, endPoint: .bottom)))
                    Spacer()
                    if targetPoint != nil && !solved {
                        Text(l10n.t("puzzle.play.attempts", attempts))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)
                    }
                }

                if let quiz = entry.quizStep, targetPoint != nil {
                    Text(quiz.prompt(l10n))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(entry.hook(l10n))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let feedback = feedbackMessage {
                    Text(feedback)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(solved ? AppTheme.mintBottom : AppTheme.coralBottom)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(solved ? AppTheme.mintTop.opacity(0.14) : AppTheme.coralTop.opacity(0.12))
                        )
                }

                if solved && !targetComment.isEmpty {
                    Text(targetComment)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Counter-Example Good vs Mistake toggle (if available & solved)
                if solved && entry.hasCounterExample && !counterStates.isEmpty {
                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        showingCounterExample.toggle()
                        if showingCounterExample {
                            counterStep = max(0, counterStates.count - 1)
                        }
                    } label: {
                        Label(
                            showingCounterExample
                                ? l10n.localized(zh: "切回大师正着", en: "Back to Master Move", ja: "正解図に戻す", ko: "정수로 돌아가기", zhHant: "切回大師正著")
                                : l10n.localized(zh: "对比「贪心错着」反面教材", en: "Compare vs Greedy Mistake", ja: "失敗図と比較する", ko: "실수 변화도와 비교", zhHant: "對比「貪心錯著」反面教材"),
                            systemImage: showingCounterExample ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                        )
                        .font(.system(size: 12.5, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: showingCounterExample ? .mint : .coral, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2))

                    if showingCounterExample, let c = counterComments[min(counterStep, max(0, counterComments.count - 1))], !c.isEmpty {
                        Text(c)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.coralBottom)
                    }
                }
            }
            .warmCard(cornerRadius: 24, padding: 16)

            // Today's Codex Term Mini-Card (always reinforces today's Go vocabulary!)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: plan.themeCodex.symbolName)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(AppTheme.skyBottom)
                    Text(l10n.localized(
                        zh: "今日招法小百科：\(plan.themeCodex.term(l10n))",
                        en: "Today's Go Term: \(plan.themeCodex.term(l10n))",
                        ja: "今日の囲碁用語：\(plan.themeCodex.term(l10n))",
                        ko: "오늘의 바둑 용어: \(plan.themeCodex.term(l10n))",
                        zhHant: "今日招法小百科：\(plan.themeCodex.term(l10n))"
                    ))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                }

                Text(plan.themeCodex.metaphor(l10n))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.skyBottom)

                Text(plan.themeCodex.explanation(l10n))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .warmCard(cornerRadius: 24, padding: 16)

            if solved || targetPoint == nil {
                Button {
                    appState.recordDailyDojoKnowledgeCompleted(
                        academyEntryId: entry.id,
                        themeCodexId: plan.themeCodex.id
                    )
                    appState.popRoute()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18, weight: .black))
                        Text(l10n.localized(
                            zh: "学会啦！返回每日道场",
                            en: "Got It! Back to Daily Dojo",
                            ja: "覚えた！道場へ戻る",
                            ko: "배웠어요! 도장으로 돌아가기",
                            zhHant: "學會啦！返回每日道場"
                        ))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                .accessibilityIdentifier("DailyKnowledgeCompleteButton")
            }
        }
    }

    private func loadKnowledgePosition() {
        let sgf = entry.sgf(l10n)
        guard let root = SGFParser.parse(sgf) else { return }
        var state = GoBoardState(size: entry.boardSize, komi: entry.komi)
        for pt in root.addedBlackPoints { state.setSetupStone(.black, at: pt) }
        for pt in root.addedWhitePoints { state.setSetupStone(.white, at: pt) }
        state.resetPositionHistoryToCurrent()

        let stopBefore = entry.quizStep?.beforeMoveIndex ?? 999
        var moveIndex = 0
        var node = root.children.first
        while let n = node {
            if let move = n.move {
                if moveIndex == stopBefore, case .place(let pt) = move.action {
                    targetPoint = pt
                    targetColor = move.color
                    targetComment = n.comment ?? entry.hook(l10n)
                    break
                }
                if case .success(let out) = state.applying(action: move.action, color: move.color) {
                    state = out.nextState
                }
                moveIndex += 1
            }
            node = n.children.first
        }
        boardState = state

        // Preload counter-example if present
        if let counterSgf = entry.counterExampleSgf(l10n), let cRoot = SGFParser.parse(counterSgf) {
            var cState = GoBoardState(size: entry.boardSize, komi: entry.komi)
            for pt in cRoot.addedBlackPoints { cState.setSetupStone(.black, at: pt) }
            for pt in cRoot.addedWhitePoints { cState.setSetupStone(.white, at: pt) }
            cState.resetPositionHistoryToCurrent()
            var states: [GoBoardState] = [cState]
            var comments: [String?] = [cRoot.comment]
            var cNode = cRoot.children.first
            while let n = cNode {
                if let move = n.move, case .success(let out) = cState.applying(action: move.action, color: move.color) {
                    cState = out.nextState
                    states.append(cState)
                    comments.append(n.comment)
                }
                cNode = n.children.first
            }
            counterStates = states
            counterComments = comments
        }
    }

    private func handleQuizTap(at point: BoardPoint) {
        guard !solved, let target = targetPoint else { return }
        attempts += 1
        if point == target {
            if case .success(let out) = boardState.applying(action: .place(point), color: targetColor) {
                boardState = out.nextState
            }
            solved = true
            feedbackMessage = l10n.localized(
                zh: attempts == 1 ? "太神了！一猜就中大师正着！" : "试了 \(attempts) 次终于找到大师正着！太棒了！",
                en: attempts == 1 ? "Brilliant! You found the Master move on try #1!" : "Found the Master move in \(attempts) tries! Awesome persistence!",
                ja: attempts == 1 ? "お見事！1回で名人の一手を当てたよ！" : "\(attempts)回目で名人の一手を発見！すごい！",
                ko: attempts == 1 ? "대단해요! 한 번에 고수의 수를 맞혔어요!" : "\(attempts)번 만에 고수의 수를 찾았어요! 멋져요!",
                zhHant: attempts == 1 ? "太神了！一猜就中大師正著！" : "試了 \(attempts) 次終於找到大師正著！太棒了！"
            )
            SoundAndHapticsManager.shared.playSuccess()
            SoundAndHapticsManager.shared.playVoice(.correct, delay: 0.12)
            appState.recordDailyDojoKnowledgeCompleted(
                academyEntryId: entry.id,
                themeCodexId: plan.themeCodex.id
            )
        } else {
            wrongFlashPoint = point
            wrongFlashID = UUID()
            SoundAndHapticsManager.shared.playWrong()
            let dist = abs(point.row - target.row) + abs(point.col - target.col)
            if dist <= 2 {
                feedbackMessage = l10n.localized(
                    zh: "很接近啦！就在刚才那颗子附近，再仔细看看棋形！",
                    en: "So close! Look right around that area and try again!",
                    ja: "惜しい！すぐ近くにあるよ、もう一度よく見てみよう！",
                    ko: "아주 가까워요! 방금 둔 근처를 다시 잘 살펴보세요!",
                    zhHant: "很接近啦！就在剛才那顆子附近，再仔細看看棋形！"
                )
            } else {
                feedbackMessage = l10n.localized(
                    zh: "还不是这里哦！多看看急所和断点，继续大胆尝试！",
                    en: "Not quite there yet! Look for the vital point and try again!",
                    ja: "そこじゃないみたい！急所を探してもう一度試そう！",
                    ko: "여기는 아니에요! 급소와 끊는 점을 찾아 다시 도전해 보세요!",
                    zhHant: "還不是這裡哦！多看看急所和斷點，繼續大膽嘗試！"
                )
            }
        }
    }
}
