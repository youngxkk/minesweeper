//
//  IslandMicroDemoView.swift
//  StarYi Go — Nintendo Mario 1-1 Style "Zero-Word 3-Second Silent Visual Micro-Demo"
//  Kids anywhere in the world immediately grasp each island's core Go tactic visually, zero reading required!
//

import SwiftUI

struct IslandMicroDemoSpec: Sendable {
    let icon: String
    let sgf: String
    let boardSize: Int
    let cropRegion: BoardCropRegion
}

enum IslandMicroDemos {
    static func spec(for islandId: String) -> IslandMicroDemoSpec {
        // Maps every island to a crisp, looping 1-3 move visual demonstration using verified puzzle SGFs
        let puzzleId: String
        let icon: String
        switch islandId {
        case "s1-reef":       (puzzleId, icon) = ("pk-cap-01", "💥")
        case "s1-shell":      (puzzleId, icon) = ("cap-03", "🌊")
        case "s1-lagoon":     (puzzleId, icon) = ("dojo-cap-02", "🚪")
        case "s1-harbor":     (puzzleId, icon) = ("cap-04", "⚡️")
        case "s1-lighthouse": (puzzleId, icon) = ("pk-lad-01", "👀")
        case "s2-wind":       (puzzleId, icon) = ("tac-03", "🪜")
        case "s2-canyon":     (puzzleId, icon) = ("tac-01", "🪃")
        case "s2-lake":       (puzzleId, icon) = ("lad-02", "🌙")
        case "s2-temple":     (puzzleId, icon) = ("end-02", "⏳")
        case "s2-summit":     (puzzleId, icon) = ("tac-05", "🦢")
        case "s3-pine":       (puzzleId, icon) = ("end-03", "🌉")
        case "s3-forge":      (puzzleId, icon) = ("end-05", "🔥")
        case "s3-river":      (puzzleId, icon) = ("dojo-race-02", "💧")
        case "s3-pagoda":     (puzzleId, icon) = ("pk-open-07", "⛩️")
        case "s3-sanctum":    (puzzleId, icon) = ("dojo-end-02", "🐒")
        case "s4-mist":       (puzzleId, icon) = ("dojo-lad-10", "♨️")
        case "s4-flame":      (puzzleId, icon) = ("dojo-end-04", "❄️")
        case "s4-azure":      (puzzleId, icon) = ("dojo-lad-11", "🧊")
        case "s4-citadel":    (puzzleId, icon) = ("pk-dan-18", "🏔️")
        case "s4-zenith":     (puzzleId, icon) = ("pk-dan-20", "🌨️")
        case "s5-forge":      (puzzleId, icon) = ("pk-dan-11", "⚒️")
        case "s5-bridge":     (puzzleId, icon) = ("pk-dan-17", "🔥")
        case "s5-altar":      (puzzleId, icon) = ("pk-dan-19", "🐉")
        case "s5-citadel":    (puzzleId, icon) = ("pk-dan-22", "🦅")
        case "s5-caldera":    (puzzleId, icon) = ("pk-dan-23", "🌋")
        default:              (puzzleId, icon) = ("pk-dan-21", "🦄")
        }

        if let p = DojoPuzzleBank.findPuzzle(withId: puzzleId) {
            return IslandMicroDemoSpec(icon: icon, sgf: p.sgf, boardSize: p.boardSize, cropRegion: p.cropRegion)
        }
        let fallback = BuiltInPuzzleLibrary.allPuzzles[0]
        return IslandMicroDemoSpec(icon: "✨", sgf: fallback.sgf, boardSize: fallback.boardSize, cropRegion: fallback.cropRegion)
    }
}

/// Looping 3-second silent animated Go mini-board showing how the island's signature move works without words.
struct IslandMicroDemoSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let island: CampaignIsland

    @State private var boardState: GoBoardState = GoBoardState(size: 9)
    @State private var stepIndex: Int = 0
    @State private var totalSteps: Int = 1
    @State private var capturedFlash: [BoardPoint] = []
    @State private var captureEventID: UUID = UUID()
    @State private var loopTask: Task<Void, Never>?

    private var l10n: L10n { appState.l10n }
    private var spec: IslandMicroDemoSpec { IslandMicroDemos.spec(for: island.id) }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(spec.icon).font(AppFont.rounded(size: 28, weight: .regular))
                VStack(alignment: .leading, spacing: 2) {
                    Text(island.localizedName(l10n))
                        .font(AppFont.rounded(size: 19, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text(l10n.localized(
                        zh: "3秒无字动画 · 看懂本岛核心招式",
                        en: "3-Sec Silent Visual Demo · Watch the Key Tactic",
                        ja: "3秒ビジュアル手本・文字なしで直感理解",
                        ko: "3초 무음 시범 · 눈으로 바로 배우는 핵심 맥점",
                        zhHant: "3秒無字動畫 · 看懂本島核心招式"
                    ))
                    .font(AppFont.rounded(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.inkSecondary)
                }
                Spacer()
                GameCircleButton(icon: "xmark", palette: .snow, tint: AppTheme.inkSecondary, size: 36) {
                    dismiss()
                }
            }

            GoBoardView(
                boardState: boardState,
                theme: appState.settings.boardTheme,
                stoneStyle: appState.settings.stoneStyle,
                cropRegion: spec.cropRegion,
                showCoordinates: false,
                showMoveNumbers: false,
                highlightAtari: true,
                expressiveStones: true,
                showLiveLiberties: true,
                showTwoEyeGlow: true,
                isInteractive: false,
                capturedFlashPoints: capturedFlash,
                captureEventID: captureEventID
            )
            .frame(maxWidth: 340, maxHeight: 340)
            .aspectRatio(1, contentMode: .fit)

            // Silent step indicator dots
            HStack(spacing: 8) {
                ForEach(0...max(1, totalSteps), id: \.self) { idx in
                    Circle()
                        .fill(idx <= stepIndex ? AppTheme.mintBottom : AppTheme.subtleBorder)
                        .frame(width: idx == stepIndex ? 12 : 8, height: idx == stepIndex ? 12 : 8)
                }
            }

            Button {
                dismiss()
            } label: {
                Text(l10n.localized(zh: "看懂了，去闯关！", en: "Got it — Let's Play!", ja: "わかった！挑戦する", ko: "이해했어요! 도전하기", zhHant: "看懂了，去闖關！"))
                    .font(AppFont.rounded(size: 16, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
        }
        .padding(22)
        .background(AppTheme.brightArenaBackground)
        .onAppear { startSilentLoop() }
        .onDisappear { loopTask?.cancel() }
    }

    private func startSilentLoop() {
        loopTask?.cancel()
        guard let root = SGFParser.parse(spec.sgf) else { return }
        let line = GoPuzzle.solutionLine(from: root)
        totalSteps = max(1, line.count)

        var initial = GoBoardState(size: spec.boardSize, komi: 0)
        for pt in root.addedBlackPoints { initial.setSetupStone(.black, at: pt) }
        for pt in root.addedWhitePoints { initial.setSetupStone(.white, at: pt) }
        initial.resetPositionHistoryToCurrent()

        loopTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    boardState = initial
                    stepIndex = 0
                    capturedFlash = []
                }
                try? await Task.sleep(nanoseconds: 900_000_000)
                var cur = initial
                for (i, mv) in line.enumerated() {
                    guard !Task.isCancelled else { return }
                    if case .success(let out) = cur.applying(action: .place(mv.point), color: mv.color) {
                        cur = out.nextState
                        await MainActor.run {
                            boardState = cur
                            stepIndex = i + 1
                            if !out.capturedPoints.isEmpty {
                                capturedFlash = out.capturedPoints
                                captureEventID = UUID()
                            }
                        }
                    }
                    try? await Task.sleep(nanoseconds: 780_000_000)
                }
                try? await Task.sleep(nanoseconds: 1_100_000_000)
            }
        }
    }
}
