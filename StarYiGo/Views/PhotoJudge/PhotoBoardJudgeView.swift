//
//  PhotoBoardJudgeView.swift
//  StarYi Go — 100% Offline Photo Go Board Recognition & Win/Loss Judge
//

import PhotosUI
import SwiftUI
import UIKit

struct PhotoBoardJudgeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    enum Stage {
        case capture
        case calibrate
        case judge
        case history
    }

    enum EditTool: String, CaseIterable, Identifiable {
        case cycle
        case black
        case white
        case erase
        case markDead

        var id: String { rawValue }
    }

    @State private var stage: Stage = .capture
    @State private var selectedSize: BoardSize = .nineteen
    @State private var autoDetectBoardSize: Bool = false
    @State private var detectedGridConfidence: Double? = nil
    @State private var hasInitialized: Bool = false
    @State private var scoringRule: ScoringRule = .chinese
    @State private var komi: Double = 7.5

    @State private var sourceImage: UIImage? = nil
    @State private var corners: BoardCornerQuad = .defaultCentered
    @State private var gridInsetFraction: CGFloat = 0.045
    @State private var isProcessing: Bool = false

    @State private var recognitionResult: BoardRecognitionResult? = nil
    @State private var boardState: GoBoardState = GoBoardState(size: 19, komi: 7.5)
    @State private var deadStoneIndices: Set<Int> = []
    @State private var evaluation: CoreMLGoAIEngine.PhotoJudgeEvaluation? = nil
    @State private var isEvaluating: Bool = false

    @State private var editTool: EditTool = .cycle
    @State private var showTerritoryOverlay: Bool = true
    @State private var showOriginalPhotoOverlay: Bool = false

    @State private var showCameraSheet: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var showCameraUnavailableAlert: Bool = false
    @State private var showClearHistoryAlert: Bool = false
    @State private var showDeleteRecordAlert: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var evaluationTask: Task<Void, Never>? = nil
    @State private var liveGridDetectTask: Task<Void, Never>? = nil

    @State private var activeRecordId: UUID? = nil
    @State private var activeRecordDate: Date? = nil
    @State private var loadedWarpedImage: UIImage? = nil
    @State private var openedFromHistory: Bool = false

    private var activeWarpedImage: UIImage? {
        recognitionResult?.warpedBoardImage ?? loadedWarpedImage
    }

    private var l10n: L10n { appState.l10n }

    private let supportedSizes: [BoardSize] = [.nineteen, .thirteen, .nine, .seven]

    var body: some View {
        ZStack {
            // Dedicated full-bleed sunlit Go veranda & bamboo courtyard backdrop
            PhotoJudgeBackdropView()

            VStack(spacing: 12) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Group {
                    switch stage {
                    case .capture:
                        captureStageView
                    case .calibrate:
                        calibrateStageView
                    case .judge:
                        judgeStageView
                    case .history:
                        PhotoJudgeHistoryView(
                            onSelectRecord: { record in
                                openHistoryRecord(record)
                            },
                            onStartNewPhoto: {
                                startNewPhotoSession()
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
            }

            if isProcessing {
                processingOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            scoringRule = .chinese
            selectedSize = .nineteen
            autoDetectBoardSize = false
            komi = scoringRule.defaultKomi(for: selectedSize)
        }
        .onDisappear {
            evaluationTask?.cancel()
            liveGridDetectTask?.cancel()
        }
        .fullScreenCover(isPresented: $showCameraSheet) {
            CameraCaptureView { image in
                showCameraSheet = false
                if let image {
                    handlePickedImage(image)
                }
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        handlePickedImage(image)
                    }
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
        .gameDialog(
            isPresented: $showCameraUnavailableAlert,
            title: l10n.localized(
                zh: "当前设备无可用相机",
                en: "Camera Unavailable",
                ja: "カメラが利用できません",
                ko: "카메라를 사용할 수 없음",
                zhHant: "目前裝置無可用相機"
            ),
            message: l10n.localized(
                zh: "请使用「从相册选择」导入围棋棋盘照片进行离线胜负识别。",
                en: "Please use Photo Library to import a Go board photo for offline judging.",
                ja: "「写真から選択」を使って囲碁盤の写真を読み込んでください。",
                ko: "'앨범에서 선택'을 사용해 바둑판 사진을 불러오세요.",
                zhHant: "請使用「從相簿選擇」匯入圍棋棋盤照片進行離線勝負識別。"
            ),
            icon: "camera.fill",
            accentPalette: .sky,
            actions: [
                .primary(l10n.localized(zh: "好的", en: "OK", ja: "OK", ko: "확인", zhHant: "好的"), palette: .sky)
            ]
        )
        .gameDialog(
            isPresented: $showClearHistoryAlert,
            title: l10n.localized(
                zh: "清空全部拍照历史？",
                en: "Clear All Photo Judge History?",
                ja: "判定履歴をすべて削除しますか？",
                ko: "사진 판정 기록을 모두 삭제할까요?",
                zhHant: "清空全部拍照歷史？"
            ),
            message: l10n.localized(
                zh: "此操作将删除所有已保存的拍照判胜负记录，且无法恢复。",
                en: "This will permanently delete all saved photo judge records.",
                ja: "保存されているすべての写真判定履歴が完全に削除されます。",
                ko: "저장된 모든 사진 판정 기록이 영구적으로 삭제됩니다.",
                zhHant: "此操作將刪除所有已儲存的拍照判勝負記錄，且無法恢復。"
            ),
            icon: "trash.fill",
            accentPalette: .coral,
            actions: [
                .secondary(l10n.localized(zh: "取消", en: "Cancel", ja: "キャンセル", ko: "취소", zhHant: "取消")),
                .destructive(l10n.localized(zh: "清空", en: "Clear All", ja: "すべて削除", ko: "모두 삭제", zhHant: "清空")) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.clearPhotoJudgeHistory()
                    }
                }
            ]
        )
        .gameDialog(
            isPresented: $showDeleteRecordAlert,
            title: l10n.localized(
                zh: "删除这条记录？",
                en: "Delete This Record?",
                ja: "この履歴を削除しますか？",
                ko: "이 기록을 삭제할까요?",
                zhHant: "刪除這條記錄？"
            ),
            message: l10n.localized(
                zh: "删除后将无法恢复这条拍照判胜负记录。",
                en: "This photo judge record will be permanently deleted.",
                ja: "削除するとこの写真判定履歴は元に戻せません。",
                ko: "삭제하면 이 사진 판정 기록은 복구할 수 없습니다.",
                zhHant: "刪除後將無法恢復這條拍照判勝負記錄。"
            ),
            icon: "trash.fill",
            accentPalette: .coral,
            actions: [
                .secondary(l10n.localized(zh: "取消", en: "Cancel", ja: "キャンセル", ko: "취소", zhHant: "取消")),
                .destructive(l10n.localized(zh: "删除", en: "Delete", ja: "削除", ko: "삭제", zhHant: "刪除")) {
                    guard let recordId = activeRecordId else { return }
                    evaluationTask?.cancel()
                    appState.deletePhotoJudgeRecord(id: recordId)
                    activeRecordId = nil
                    activeRecordDate = nil
                    if openedFromHistory {
                        stage = .history
                    } else {
                        startNewPhotoSession()
                    }
                }
            ]
        )
    }

    // MARK: - Top Bar

    private var topBar: some View {
        Group {
            if stage == .judge {
                HStack(spacing: 16) {
                    HStack(spacing: 12) {
                        topBarBackButton
                        topBarTitleCrest
                        Spacer(minLength: 8)
                        if activeWarpedImage != nil {
                            Button {
                                SoundAndHapticsManager.shared.playUITap()
                                showOriginalPhotoOverlay.toggle()
                            } label: {
                                Label(
                                    showOriginalPhotoOverlay
                                        ? l10n.localized(zh: "看棋盘", en: "Board", ja: "盤面", ko: "바둑판", zhHant: "看棋盤")
                                        : l10n.localized(zh: "看原图", en: "Photo", ja: "元写真", ko: "원본", zhHant: "看原圖"),
                                    systemImage: showOriginalPhotoOverlay ? "square.grid.3x3" : "photo"
                                )
                                .font(.system(size: 12.5, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                            }
                            .buttonStyle(GlossyCapsuleButtonStyle(palette: showOriginalPhotoOverlay ? .sun : .sky, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2.5))
                            .accessibilityIdentifier("PhotoJudgeComparePhotoButton")
                        }
                    }
                    .frame(maxWidth: .infinity)

                    HStack {
                        Spacer()
                        if activeRecordId != nil {
                            Button(role: .destructive) {
                                SoundAndHapticsManager.shared.playUITap()
                                showDeleteRecordAlert = true
                            } label: {
                                Label(
                                    l10n.localized(zh: "删除", en: "Delete", ja: "削除", ko: "삭제", zhHant: "刪除"),
                                    systemImage: "trash"
                                )
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.coralBottom)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                            .accessibilityLabel(l10n.localized(zh: "删除此记录", en: "Delete Record", ja: "この履歴を削除", ko: "이 기록 삭제", zhHant: "刪除此記錄"))
                            .accessibilityIdentifier("PhotoJudgeTopDeleteButton")
                        }
                    }
                    .frame(width: 372)
                }
            } else {
                HStack(spacing: 12) {
                    topBarBackButton
                    topBarTitleCrest
                    Spacer()

                    if stage == .calibrate {
                        Button {
                            SoundAndHapticsManager.shared.playUITap()
                            stage = .history
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 13, weight: .black))
                                Text(
                                    appState.photoJudgeHistory.isEmpty
                                        ? l10n.localized(zh: "历史", en: "History", ja: "履歴", ko: "기록", zhHant: "歷史")
                                        : l10n.localized(
                                            zh: "历史 (\(appState.photoJudgeHistory.count))",
                                            en: "History (\(appState.photoJudgeHistory.count))",
                                            ja: "履歴 (\(appState.photoJudgeHistory.count))",
                                            ko: "기록 (\(appState.photoJudgeHistory.count))",
                                            zhHant: "歷史 (\(appState.photoJudgeHistory.count))"
                                        )
                                )
                                .font(.system(size: 12.5, weight: .black, design: .rounded))
                            }
                            .foregroundColor(AppTheme.inkPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2.5))
                        .accessibilityIdentifier("PhotoJudgeTopHistoryButton")
                    } else if stage == .history, !appState.photoJudgeHistory.isEmpty {
                        Button {
                            SoundAndHapticsManager.shared.playUITap()
                            showClearHistoryAlert = true
                        } label: {
                            Label(
                                l10n.localized(zh: "清空", en: "Clear All", ja: "全削除", ko: "전체 삭제", zhHant: "清空"),
                                systemImage: "trash"
                            )
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.coralBottom)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                        .accessibilityIdentifier("PhotoJudgeHistoryClearAllButton")
                    }
                }
            }
        }
    }

    private var topBarBackButton: some View {
        GameCircleButton(
            icon: stage == .capture ? "chevron.left" : "arrow.uturn.backward",
            palette: .snow,
            tint: AppTheme.inkPrimary,
            size: 42
        ) {
            switch stage {
            case .capture:
                dismiss()
            case .calibrate:
                stage = .capture
            case .judge:
                if openedFromHistory {
                    stage = .history
                } else {
                    stage = .calibrate
                }
            case .history:
                stage = .capture
            }
        }
        .accessibilityLabel(l10n.localized(zh: "返回", en: "Back", ja: "戻る", ko: "뒤로", zhHant: "返回"))
    }

    private var topBarTitleCrest: some View {
        GameTitleCrest(
            title: stage == .history
                ? l10n.localized(
                    zh: "拍照判胜负 · 历史",
                    en: "Photo Judge History",
                    ja: "写真判定 · 履歴",
                    ko: "사진 판정 · 기록",
                    zhHant: "拍照判勝負 · 歷史"
                )
                : l10n.localized(
                    zh: "拍照判胜负",
                    en: "Photo Go Judge",
                    ja: "写真で勝敗判定",
                    ko: "사진 승패 판정",
                    zhHant: "拍照判勝負"
                ),
            minHeight: AppTheme.buttonFaceHeight
        )
    }

    // MARK: - Stage 1: Capture / Import Photo (HomeView-Style Hero Portals + Bottom Rules Dock)

    private var captureStageView: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 700
            let heroHeight = isCompact
                ? min(156, max(124, geo.size.height * 0.44))
                : min(230, max(164, geo.size.height * 0.50))
            let historyWidth: CGFloat = isCompact ? 120 : min(200, max(164, geo.size.width * 0.21))

            VStack(spacing: isCompact ? 12 : 20) {
                Spacer(minLength: 4)

                // Top Hero Entry Row: [ Big Take Photo ] [ Big Photo Library ] [ Compact History ]
                HStack(spacing: isCompact ? 10 : 18) {
                    takePhotoHeroCard(height: heroHeight, isCompact: isCompact)
                    photoLibraryHeroCard(height: heroHeight, isCompact: isCompact)
                    historyCompactHeroCard(height: heroHeight, width: historyWidth, isCompact: isCompact)
                }
                .frame(maxWidth: 1080)

                Spacer(minLength: 4)

                // Bottom Translucent Rules & Compact Shooting Tips Dock
                bottomRulesAndTipsDock(isCompact: isCompact)
                    .frame(maxWidth: 1080)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func takePhotoHeroCard(height: CGFloat, isCompact: Bool) -> some View {
        Button {
            SoundAndHapticsManager.shared.playUITap()
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                showCameraSheet = true
            } else {
                showCameraUnavailableAlert = true
            }
        } label: {
            VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.24))
                        .frame(width: isCompact ? 46 : 62, height: isCompact ? 46 : 62)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: 2.5))
                    Image(systemName: "camera.fill")
                        .font(.system(size: isCompact ? 22 : 30, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: AppTheme.skyRim.opacity(0.55), radius: 2, y: 2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.localized(
                        zh: "立即拍照",
                        en: "Take Photo",
                        ja: "カメラで撮影",
                        ko: "사진 촬영",
                        zhHant: "立即拍照"
                    ))
                    .font(.system(size: isCompact ? 22 : 30, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: AppTheme.skyRim.opacity(0.55), radius: 2, y: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                    Text(l10n.localized(
                        zh: "对准实体棋盘俯拍，秒判黑白胜负",
                        en: "Point at a real Go board to judge instantly",
                        ja: "実際の碁盤を撮影してすぐ勝敗判定",
                        ko: "실제 바둑판을 촬영해 즉시 승패 판정",
                        zhHant: "對準實體棋盤俯拍，秒判黑白勝負"
                    ))
                    .font(.system(size: isCompact ? 11.5 : 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.94))
                    .lineLimit(2)
                }
            }
            .padding(isCompact ? 16 : 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
        }
        .buttonStyle(
            GlossyCapsuleButtonStyle(
                palette: .sky,
                cornerRadius: isCompact ? 26 : 34,
                rimHeight: 8,
                whiteBorderWidth: 4,
                showStripeSheen: true,
                playTapSound: false,
                pressStyle: .homeEntrance
            )
        )
        .accessibilityIdentifier("PhotoJudgeTakePhotoButton")
    }

    private func photoLibraryHeroCard(height: CGFloat, isCompact: Bool) -> some View {
        Button {
            SoundAndHapticsManager.shared.playUITap()
            showPhotoPicker = true
        } label: {
            VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.24))
                        .frame(width: isCompact ? 46 : 62, height: isCompact ? 46 : 62)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: 2.5))
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: isCompact ? 21 : 28, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: AppTheme.sunRim.opacity(0.55), radius: 2, y: 2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.localized(
                        zh: "从相册选择",
                        en: "Photo Library",
                        ja: "写真から選択",
                        ko: "앨범에서 선택",
                        zhHant: "從相簿選擇"
                    ))
                    .font(.system(size: isCompact ? 22 : 30, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: AppTheme.sunRim.opacity(0.55), radius: 2, y: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                    Text(l10n.localized(
                        zh: "导入已拍好的对局照片离线算胜负",
                        en: "Import an existing board photo offline",
                        ja: "撮影済みの対局写真をオフライン判定",
                        ko: "촬영해 둔 대국 사진을 오프라인 판정",
                        zhHant: "匯入已拍好的對局照片離線算勝負"
                    ))
                    .font(.system(size: isCompact ? 11.5 : 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.94))
                    .lineLimit(2)
                }
            }
            .padding(isCompact ? 16 : 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
        }
        .buttonStyle(
            GlossyCapsuleButtonStyle(
                palette: .sun,
                cornerRadius: isCompact ? 26 : 34,
                rimHeight: 8,
                whiteBorderWidth: 4,
                showStripeSheen: true,
                playTapSound: false,
                pressStyle: .homeEntrance
            )
        )
        .accessibilityIdentifier("PhotoJudgeLibraryButton")
    }

    private func historyCompactHeroCard(height: CGFloat, width: CGFloat, isCompact: Bool) -> some View {
        Button {
            SoundAndHapticsManager.shared.playUITap()
            stage = .history
        } label: {
            VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.24))
                        .frame(width: isCompact ? 46 : 62, height: isCompact ? 46 : 62)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: 2.5))
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: isCompact ? 22 : 30, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: AppTheme.grapeRim.opacity(0.55), radius: 2, y: 2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.localized(
                        zh: "查看历史",
                        en: "History",
                        ja: "履歴",
                        ko: "기록",
                        zhHant: "查看歷史"
                    ))
                    .font(.system(size: isCompact ? 20 : 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: AppTheme.grapeRim.opacity(0.55), radius: 2, y: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                    Text("\(appState.photoJudgeHistory.count)/\(PhotoJudgeRecord.maxStoredCount)")
                        .font(.system(size: isCompact ? 11.5 : 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.94))
                        .lineLimit(1)
                }
            }
            .padding(isCompact ? 16 : 24)
            .frame(width: width, height: height, alignment: .leading)
        }
        .buttonStyle(
            GlossyCapsuleButtonStyle(
                palette: .grape,
                cornerRadius: isCompact ? 26 : 34,
                rimHeight: 8,
                whiteBorderWidth: 4,
                showStripeSheen: true,
                playTapSound: false,
                pressStyle: .homeEntrance
            )
        )
        .accessibilityIdentifier("PhotoJudgeCaptureHistoryButton")
    }

    private func bottomRulesAndTipsDock(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 8 : 10) {
            if isCompact {
                VStack(spacing: 8) {
                    boardSizeRuleGroup(isCompact: true)
                    scoringRuleGroup(isCompact: true)
                }
            } else {
                HStack(spacing: 16) {
                    boardSizeRuleGroup(isCompact: false)

                    Rectangle()
                        .fill(Color.white.opacity(0.32))
                        .frame(width: 1.5, height: 26)

                    scoringRuleGroup(isCompact: false)
                }
            }
        }
        .padding(.horizontal, isCompact ? 14 : 20)
        .padding(.vertical, isCompact ? 10 : 13)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.09, green: 0.14, blue: 0.24).opacity(0.58))
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 5)
    }

    private func boardSizeRuleGroup(isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 5 : 7) {
            Text(l10n.localized(zh: "棋盘规格", en: "Board", ja: "盤サイズ", ko: "바둑판", zhHant: "棋盤規格"))
                .font(.system(size: isCompact ? 11.5 : 12.5, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize()

            Button {
                SoundAndHapticsManager.shared.playUITap()
                autoDetectBoardSize = true
            } label: {
                Text(l10n.localized(zh: "自动", en: "Auto", ja: "自動", ko: "자동", zhHant: "自動"))
                    .font(.system(size: isCompact ? 11.5 : 12.5, weight: .black, design: .rounded))
                    .foregroundColor(autoDetectBoardSize ? .white : AppTheme.inkPrimary)
                    .padding(.horizontal, isCompact ? 9 : 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(
                GlossyCapsuleButtonStyle(
                    palette: autoDetectBoardSize ? .mint : .snow,
                    cornerRadius: 12,
                    rimHeight: 3,
                    whiteBorderWidth: 2
                )
            )

            ForEach(supportedSizes) { size in
                let isSelected = !autoDetectBoardSize && selectedSize == size
                Button {
                    SoundAndHapticsManager.shared.playUITap()
                    autoDetectBoardSize = false
                    selectedSize = size
                    komi = scoringRule.defaultKomi(for: size)
                } label: {
                    Text("\(size.rawValue)×\(size.rawValue)")
                        .font(.system(size: isCompact ? 11.5 : 12.5, weight: .black, design: .rounded))
                        .foregroundColor(isSelected ? .white : AppTheme.inkPrimary)
                        .padding(.horizontal, isCompact ? 8 : 11)
                        .padding(.vertical, 6)
                }
                .buttonStyle(
                    GlossyCapsuleButtonStyle(
                        palette: isSelected ? .sky : .snow,
                        cornerRadius: 12,
                        rimHeight: 3,
                        whiteBorderWidth: 2
                    )
                )
            }
        }
    }

    private func scoringRuleGroup(isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 6 : 8) {
            Text(l10n.localized(zh: "计分规则", en: "Rules", ja: "ルール", ko: "규칙", zhHant: "計分規則"))
                .font(.system(size: isCompact ? 11.5 : 12.5, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize()

            ForEach(ScoringRule.allCases) { rule in
                let isSelected = scoringRule == rule
                Button {
                    SoundAndHapticsManager.shared.playUITap()
                    scoringRule = rule
                    komi = rule.defaultKomi(for: selectedSize)
                } label: {
                    Text(ruleLabel(rule))
                        .font(.system(size: isCompact ? 11.5 : 12.5, weight: .black, design: .rounded))
                        .foregroundColor(isSelected ? .white : AppTheme.inkPrimary)
                        .padding(.horizontal, isCompact ? 10 : 13)
                        .padding(.vertical, 6)
                }
                .buttonStyle(
                    GlossyCapsuleButtonStyle(
                        palette: isSelected ? .grape : .snow,
                        cornerRadius: 12,
                        rimHeight: 3,
                        whiteBorderWidth: 2
                    )
                )
            }
        }
    }

    // MARK: - Stage 2: Calibrate 4 Corners & Grid Margin

    private var calibrateStageView: some View {
        HStack(spacing: 18) {
            // Left: Interactive Photo + 4 Corner Handles + Live Grid Preview
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.84))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(.white, lineWidth: 3.5)
                    )

                if let image = sourceImage {
                    BoardCornerCalibrationOverlay(
                        image: image,
                        corners: $corners,
                        boardSize: selectedSize.rawValue,
                        gridInsetFraction: gridInsetFraction,
                        onDragEnded: {
                            scheduleLiveGridDetectAfterCornerDrag()
                        }
                    )
                    .padding(10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 6)

            // Right: Alignment Controls
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(l10n.localized(
                        zh: "拖动 4 个彩色圆点对齐棋盘四角",
                        en: "Drag the 4 Handles to Board Corners",
                        ja: "4つの丸を盤の四隅に合わせてください",
                        ko: "4개의 핸들을 바둑판 네 모서리에 맞추세요",
                        zhHant: "拖動 4 個彩色圓點對齊棋盤四角"
                    ))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)

                    Text(l10n.localized(
                        zh: "让青色参考网格线尽量与实体棋盘的纵横线重合，识别会非常准确。",
                        en: "Align the cyan grid preview with the physical board lines for best accuracy.",
                        ja: "青いグリッド線が実際の碁盤の線に重なるように調整すると高精度になります。",
                        ko: "파란 격자선이 실제 바둑판 선과 겹치도록 맞추면 정확도가 높아집니다.",
                        zhHant: "讓青色參考網格線盡量與實體棋盤的縱橫線重合，識別會非常準確。"
                    ))
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)

                    // Board Size quick switcher
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(l10n.localized(zh: "棋盘路数", en: "Board Size", ja: "路数", ko: "바둑판 크기", zhHant: "棋盤路數"))
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(AppTheme.inkSecondary)
                            Spacer()
                            if autoDetectBoardSize, let conf = detectedGridConfidence, conf >= 0.38 {
                                Text(l10n.localized(
                                    zh: "✓ 自动识别 \(selectedSize.rawValue)×\(selectedSize.rawValue)",
                                    en: "✓ Auto \(selectedSize.rawValue)×\(selectedSize.rawValue)",
                                    ja: "✓ 自動検出 \(selectedSize.rawValue)×\(selectedSize.rawValue)",
                                    ko: "✓ 자동 인식 \(selectedSize.rawValue)×\(selectedSize.rawValue)",
                                    zhHant: "✓ 自動識別 \(selectedSize.rawValue)×\(selectedSize.rawValue)"
                                ))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.mintBottom)
                            }
                        }

                        HStack(spacing: 6) {
                            ForEach(supportedSizes) { size in
                                let isSelected = selectedSize == size
                                Button {
                                    SoundAndHapticsManager.shared.playUITap()
                                    autoDetectBoardSize = false
                                    selectedSize = size
                                    komi = scoringRule.defaultKomi(for: size)
                                    fitInsetForCurrentSelection()
                                } label: {
                                    Text("\(size.rawValue)×\(size.rawValue)")
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                        .foregroundColor(isSelected ? .white : AppTheme.inkPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(
                                    GlossyCapsuleButtonStyle(
                                        palette: isSelected ? .sky : .snow,
                                        cornerRadius: 14,
                                        rimHeight: 3,
                                        whiteBorderWidth: 2
                                    )
                                )
                            }
                        }
                    }

                    // Border inset slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(l10n.localized(
                                zh: "木框留白微调",
                                en: "Board Border Inset",
                                ja: "盤の外枠余白",
                                ko: "테두리 여백 미세조정",
                                zhHant: "木框留白微調"
                            ))
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)
                            Spacer()
                            Text("\(Int((gridInsetFraction * 100).rounded()))%")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.skyBottom)
                        }
                        Slider(value: $gridInsetFraction, in: 0.0...0.12, step: 0.005)
                            .tint(AppTheme.skyBottom)
                    }

                    HStack(spacing: 8) {
                        Button {
                            if let img = sourceImage {
                                SoundAndHapticsManager.shared.playUITap()
                                reDetectCornersAndGrid(in: img)
                            }
                        } label: {
                            Label(
                                l10n.localized(zh: "重测四角", en: "Re-corners", ja: "四隅再検出", ko: "모서리 재탐지", zhHant: "重測四角"),
                                systemImage: "crop"
                            )
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 14, rimHeight: 4, whiteBorderWidth: 2))

                        Button {
                            if let img = sourceImage {
                                SoundAndHapticsManager.shared.playUITap()
                                autoDetectBoardSize = true
                                detectGridForCurrentCorners(in: img)
                            }
                        } label: {
                            Label(
                                l10n.localized(zh: "识别路数", en: "Auto Size", ja: "路数検出", ko: "크기 자동", zhHant: "識別路數"),
                                systemImage: "sparkles"
                            )
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 14, rimHeight: 4, whiteBorderWidth: 2))
                    }

                    Button {
                        runOfflineRecognition()
                    } label: {
                        Label(
                            l10n.localized(
                                zh: "判胜负",
                                en: "Judge Now",
                                ja: "勝敗判定",
                                ko: "승패 판정",
                                zhHant: "判勝負"
                            ),
                            systemImage: "wand.and.stars"
                        )
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 22, rimHeight: 6, whiteBorderWidth: 3.5, showStripeSheen: true))
                    .accessibilityIdentifier("PhotoJudgeRunRecognizeButton")
                    .padding(.top, 12)
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .frame(width: 310)
            .frame(maxHeight: .infinity)
            .background(glossyWhiteCard)
        }
    }

    // MARK: - Stage 3: Verify Board & Judge Win/Loss

    private var judgeStageView: some View {
        HStack(spacing: 16) {
            // Left: Interactive Digital Board (with optional original photo peek)
            ZStack {
                GoBoardView(
                    boardState: boardState,
                    theme: appState.settings.boardTheme,
                    stoneStyle: appState.settings.stoneStyle,
                    showCoordinates: true,
                    highlightAtari: false,
                    expressiveStones: false,
                    showLiveLiberties: false,
                    showTwoEyeGlow: false,
                    markedDeadIndices: deadStoneIndices,
                    isDeadStoneReviewMode: editTool == .markDead,
                    territoryEstimate: showTerritoryOverlay ? evaluation?.territoryEstimate : nil,
                    isChoosingRegion: editTool != .markDead,
                    isInteractive: true,
                    onSelectPoint: { point in
                        handleBoardTap(point)
                    }
                )
                .aspectRatio(1, contentMode: .fit)
                .frame(maxHeight: .infinity)

                if showOriginalPhotoOverlay, let warped = activeWarpedImage {
                    Image(uiImage: warped)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(AppTheme.sunTop, lineWidth: 4)
                        )
                        .opacity(0.88)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Right: Result Verdict & Quick Edit Panel
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    verdictBannerCard

                    // KataGo Offline Winrate Bar
                    if let eval = evaluation {
                        winrateCard(eval)
                    }

                    // Quick Stone Fix & Dead-Stone Toolbar
                    editToolbarCard

                    // Scoring Rules & Komi Card
                    rulesAndOverlayCard

                    // Bottom Action Buttons
                    if sourceImage != nil {
                        Button {
                            stage = .calibrate
                        } label: {
                            Label(
                                l10n.localized(zh: "调四角", en: "Re-align", ja: "再調整", ko: "재보정", zhHant: "調四角"),
                                systemImage: "crop"
                            )
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 16, rimHeight: 4, whiteBorderWidth: 2.5))
                    }
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .frame(width: 372)
            .frame(maxHeight: .infinity)
            .background(glossyWhiteCard)
        }
    }

    // MARK: - Verdict & Stats Cards

    private var verdictBannerCard: some View {
        let result = evaluation?.gameResult ?? GoScoring.score(state: boardState, rule: scoringRule, deadStoneIndices: deadStoneIndices)
        let isBlackWin = result.winner == .black
        let palette: GlossyPalette = isBlackWin ? .sky : .sun

        let winnerTitle: String = isBlackWin
            ? l10n.localized(zh: "黑胜", en: "Black Wins", ja: "黒勝ち", ko: "흑 승", zhHant: "黑勝")
            : l10n.localized(zh: "白胜", en: "White Wins", ja: "白勝ち", ko: "백 승", zhHant: "白勝")

        let marginDisplay: String = {
            if scoringRule == .chinese {
                let zi = GameResult.formatChineseZi(result.chineseZiMargin)
                return l10n.localized(
                    zh: zi,
                    en: "+\(String(format: "%.1f", result.margin))",
                    ja: "+\(String(format: "%.1f", result.margin))",
                    ko: "+\(String(format: "%.1f", result.margin))",
                    zhHant: zi
                )
            } else {
                let m = String(format: "%.1f", result.margin)
                return l10n.localized(
                    zh: "\(m) 目",
                    en: "+\(m)",
                    ja: "\(m)目",
                    ko: "\(m)집",
                    zhHant: "\(m) 目"
                )
            }
        }()

        let blackAreaTotal = result.blackStones + result.blackTerritory
        let whiteAreaTotal = result.whiteStones + result.whiteTerritory
        let blackPrimaryNum = scoringRule == .chinese ? "\(blackAreaTotal)" : "\(result.blackTerritory)"
        let whitePrimaryNum = scoringRule == .chinese ? "\(whiteAreaTotal)" : "\(result.whiteTerritory)"
        let areaUnit = scoringRule == .chinese
            ? l10n.localized(zh: "子", en: "pts", ja: "子", ko: "점", zhHant: "子")
            : l10n.localized(zh: "目", en: "pts", ja: "目", ko: "집", zhHant: "目")

        let detail = scoringRule == .chinese
            ? result.chineseRuleSummary(isChinese: l10n.language.isChinese)
            : result.japaneseRuleSummary(isChinese: l10n.language.isChinese)

        return VStack(alignment: .leading, spacing: 12) {
            // Giant Winner & Margin Header
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isBlackWin ? Color(white: 0.12) : Color.white)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                        .shadow(color: Color.black.opacity(0.28), radius: 4, y: 2)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(AppTheme.sunTop)
                        .offset(y: -22)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(winnerTitle)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: palette.rim.opacity(0.55), radius: 2, y: 2)

                    Text(marginDisplay)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.98, blue: 0.80))
                        .shadow(color: palette.rim.opacity(0.65), radius: 3, y: 2)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)

                Spacer(minLength: 4)

                if isEvaluating {
                    ProgressView()
                        .tint(.white)
                }
            }

            // Bold Dual Territory Scoreboard: Black Territory vs White Territory
            HStack(spacing: 10) {
                // Black Territory Tile
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(white: 0.14))
                            .frame(width: 13, height: 13)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5))
                        Text(l10n.localized(zh: "黑占地盘", en: "Black Area", ja: "黒の陣地", ko: "흑 영토", zhHant: "黑佔地盤"))
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(blackPrimaryNum)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                        Text(areaUnit)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.88))
                    }

                    Text(l10n.localized(
                        zh: "黑子 \(result.blackStones) · 空 \(result.blackTerritory)",
                        en: "Stones \(result.blackStones) · Emp \(result.blackTerritory)",
                        ja: "石 \(result.blackStones) · 空 \(result.blackTerritory)",
                        ko: "돌 \(result.blackStones) · 집 \(result.blackTerritory)",
                        zhHant: "黑子 \(result.blackStones) · 空 \(result.blackTerritory)"
                    ))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.10, green: 0.13, blue: 0.20).opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isBlackWin ? Color(red: 1.0, green: 0.94, blue: 0.55) : Color.white.opacity(0.35), lineWidth: isBlackWin ? 2.5 : 1.5)
                )

                // White Territory Tile
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 13, height: 13)
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.28), lineWidth: 1.2))
                        Text(l10n.localized(zh: "白占地盘", en: "White Area", ja: "白の陣地", ko: "백 영토", zhHant: "白佔地盤"))
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(whitePrimaryNum)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                        Text(areaUnit)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)
                    }

                    Text(l10n.localized(
                        zh: "白子 \(result.whiteStones) · 空 \(result.whiteTerritory)",
                        en: "Stones \(result.whiteStones) · Emp \(result.whiteTerritory)",
                        ja: "石 \(result.whiteStones) · 空 \(result.whiteTerritory)",
                        ko: "돌 \(result.whiteStones) · 집 \(result.whiteTerritory)",
                        zhHant: "白子 \(result.whiteStones) · 空 \(result.whiteTerritory)"
                    ))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.96))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(!isBlackWin ? Color(red: 1.0, green: 0.92, blue: 0.45) : Color.white.opacity(0.6), lineWidth: !isBlackWin ? 2.5 : 1.5)
                )
            }

            Text(detail)
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                .foregroundColor(Color.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [palette.top, palette.bottom], startPoint: .top, endPoint: .bottom))
                .shadow(color: palette.rim.opacity(0.35), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white, lineWidth: 3)
        )
    }

    private func winrateCard(_ eval: CoreMLGoAIEngine.PhotoJudgeEvaluation) -> some View {
        let blackPct = Int((eval.blackWinrate * 100).rounded())
        let whitePct = 100 - blackPct

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(
                    eval.usedKataGoNeuralModel
                        ? l10n.localized(zh: "🧠 KataGo 离线胜率", en: "🧠 KataGo Offline Winrate", ja: "🧠 KataGo オフライン勝率", ko: "🧠 KataGo 오프라인 승률", zhHant: "🧠 KataGo 離線勝率")
                        : l10n.localized(zh: "⚖️ 离线形势胜率", en: "⚖️ Offline Winrate", ja: "⚖️ オフライン勝率", ko: "⚖️ 오프라인 승률", zhHant: "⚖️ 離線形勢勝率")
                )
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Circle()
                        .fill(Color(white: 0.14))
                        .frame(width: 12, height: 12)
                    Text(l10n.localized(zh: "黑", en: "B", ja: "黒", ko: "흑", zhHant: "黑"))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text("\(blackPct)%")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(whitePct)%")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.skyBottom)
                    Text(l10n.localized(zh: "白", en: "W", ja: "白", ko: "백", zhHant: "白"))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.3), lineWidth: 1.2))
                }
            }

            GeometryReader { barGeo in
                HStack(spacing: 0) {
                    Color(white: 0.14)
                        .frame(width: max(10, barGeo.size.width * eval.blackWinrate))
                    Color(red: 0.94, green: 0.96, blue: 1.0)
                }
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(AppTheme.inkSecondary.opacity(0.28), lineWidth: 2))
            }
            .frame(height: 16)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.95, green: 0.98, blue: 1.0))
        )
    }

    private var editToolbarCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(l10n.localized(
                    zh: "点棋盘快速修正",
                    en: "Tap Board to Fix",
                    ja: "盤面タップで修正",
                    ko: "바둑판 탭하여 수정",
                    zhHant: "點棋盤快速修正"
                ))
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)

                Spacer()

                Button {
                    applyAutoDeadStones()
                } label: {
                    Label(
                        l10n.localized(zh: "自动标死子", en: "Auto Dead", ja: "死石自動", ko: "사석 자동", zhHant: "自動標死子"),
                        systemImage: "wand.and.stars.inverse"
                    )
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.grapeBottom)
                }
            }

            HStack(spacing: 5) {
                toolChip(.cycle, title: l10n.localized(zh: "切换", en: "Cycle", ja: "切替", ko: "전환", zhHant: "切換"), icon: "arrow.triangle.2.circlepath")
                toolChip(.black, title: l10n.localized(zh: "黑", en: "B", ja: "黒", ko: "흑", zhHant: "黑"), icon: "circle.fill")
                toolChip(.white, title: l10n.localized(zh: "白", en: "W", ja: "白", ko: "백", zhHant: "白"), icon: "circle")
                toolChip(.erase, title: l10n.localized(zh: "擦", en: "Del", ja: "消", ko: "지움", zhHant: "擦"), icon: "eraser.fill")
                toolChip(.markDead, title: l10n.localized(zh: "死子", en: "Dead", ja: "死石", ko: "사석", zhHant: "死子"), icon: "xmark.circle.fill")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.96, green: 0.97, blue: 0.99))
        )
    }

    private func toolChip(_ tool: EditTool, title: String, icon: String) -> some View {
        let active = editTool == tool
        return Button {
            SoundAndHapticsManager.shared.playUITap()
            editTool = tool
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
            }
            .foregroundColor(active ? .white : AppTheme.inkPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(active ? (tool == .markDead ? AppTheme.coralBottom : AppTheme.skyBottom) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(active ? Color.white : Color.gray.opacity(0.2), lineWidth: 1.5)
            )
        }
    }

    private var rulesAndOverlayCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(ScoringRule.allCases) { rule in
                    let active = scoringRule == rule
                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        scoringRule = rule
                        komi = rule.defaultKomi(for: selectedSize)
                        boardState.komi = komi
                        refreshEvaluation()
                    } label: {
                        Text(ruleLabel(rule))
                            .font(.system(size: 11.5, weight: .black, design: .rounded))
                            .foregroundColor(active ? .white : AppTheme.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(active ? AppTheme.grapeBottom : Color.white))
                    }
                }
            }

            HStack {
                Text(l10n.localized(zh: "贴目 (Komi)", en: "Komi", ja: "コミ", ko: "덤 (Komi)", zhHant: "貼目 (Komi)"))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        komi = max(0, komi - 0.5)
                        boardState.komi = komi
                        refreshEvaluation()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.skyBottom)
                    }
                    Text(String(format: "%.1f", komi))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(minWidth: 34)
                    Button {
                        komi = min(20, komi + 0.5)
                        boardState.komi = komi
                        refreshEvaluation()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.skyBottom)
                    }
                }
            }

            Toggle(isOn: $showTerritoryOverlay) {
                Text(l10n.localized(
                    zh: "显示黑白领地涂色",
                    en: "Show Territory Overlay",
                    ja: "陣地カラーを表示",
                    ko: "영토 색상 표시",
                    zhHant: "顯示黑白領地塗色"
                ))
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
            }
            .tint(AppTheme.mintBottom)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.96, green: 0.97, blue: 0.99))
        )
    }

    // MARK: - Helpers & Actions

    private var glossyWhiteCard: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.white, Color(red: 0.95, green: 0.98, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: AppTheme.skyBottom.opacity(0.18), radius: 14, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(.white, lineWidth: 3.5)
            )
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(AppTheme.skyBottom)
                Text(l10n.localized(
                    zh: "正在本地离线识别棋盘...",
                    en: "Recognizing Go board offline...",
                    ja: "オフラインで碁盤を認識中...",
                    ko: "오프라인으로 바둑판 인식 중...",
                    zhHant: "正在本地離線識別棋盤..."
                ))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 20)
            .background(glossyWhiteCard)
        }
    }

    private func ruleLabel(_ rule: ScoringRule) -> String {
        switch rule {
        case .chinese:
            return l10n.localized(zh: "中国数子法", en: "Chinese Area", ja: "中国ルール", ko: "중국식", zhHant: "中國數子法")
        case .japanese:
            return l10n.localized(zh: "日韩数目法", en: "Japanese", ja: "日本ルール", ko: "한국·일본식", zhHant: "日韓數目法")
        }
    }

    private func handlePickedImage(_ image: UIImage) {
        liveGridDetectTask?.cancel()
        isProcessing = true
        activeRecordId = nil
        activeRecordDate = nil
        loadedWarpedImage = nil
        openedFromHistory = false
        showOriginalPhotoOverlay = false
        let shouldAutoSize = autoDetectBoardSize
        let manualSize = selectedSize
        let currentRule = scoringRule
        let allCandidates = supportedSizes

        Task.detached(priority: .userInitiated) {
            let upright = GoBoardPhotoRecognizer.normalizedUpImage(image, maxDimension: 1400)
            let candidates: [BoardSize] = shouldAutoSize ? allCandidates : [manualSize]
            let autoResult = GoBoardPhotoRecognizer.autoDetectBoardAndGrid(
                in: upright,
                candidates: candidates
            )

            await MainActor.run {
                self.sourceImage = upright
                self.corners = autoResult.corners
                if shouldAutoSize && autoResult.confidence >= 0.38 {
                    self.selectedSize = autoResult.boardSize
                    self.komi = currentRule.defaultKomi(for: autoResult.boardSize)
                }
                if autoResult.confidence >= 0.38 {
                    self.gridInsetFraction = autoResult.gridInsetFraction
                }
                self.detectedGridConfidence = autoResult.confidence
                self.isProcessing = false
                self.stage = .calibrate
            }
        }
    }

    private func reDetectCornersAndGrid(in image: UIImage) {
        liveGridDetectTask?.cancel()
        isProcessing = true
        let shouldAutoSize = autoDetectBoardSize
        let manualSize = selectedSize
        let currentRule = scoringRule
        let allCandidates = supportedSizes

        Task.detached(priority: .userInitiated) {
            let candidates: [BoardSize] = shouldAutoSize ? allCandidates : [manualSize]
            let autoResult = GoBoardPhotoRecognizer.autoDetectBoardAndGrid(
                in: image,
                candidates: candidates
            )
            await MainActor.run {
                self.corners = autoResult.corners
                if shouldAutoSize && autoResult.confidence >= 0.38 {
                    self.selectedSize = autoResult.boardSize
                    self.komi = currentRule.defaultKomi(for: autoResult.boardSize)
                }
                if autoResult.confidence >= 0.38 {
                    self.gridInsetFraction = autoResult.gridInsetFraction
                }
                self.detectedGridConfidence = autoResult.confidence
                self.isProcessing = false
            }
        }
    }

    private func detectGridForCurrentCorners(in image: UIImage) {
        liveGridDetectTask?.cancel()
        isProcessing = true
        let quad = corners
        let currentRule = scoringRule
        let allCandidates = supportedSizes

        Task.detached(priority: .userInitiated) {
            let gridInfo = GoBoardPhotoRecognizer.detectBoardGridStructure(
                from: image,
                corners: quad,
                candidates: allCandidates,
                snapCorners: true
            )
            await MainActor.run {
                if let snapped = gridInfo.refinedCorners, gridInfo.confidence >= 0.45 {
                    self.corners = snapped
                }
                if gridInfo.confidence >= 0.38 {
                    self.selectedSize = gridInfo.boardSize
                    self.komi = currentRule.defaultKomi(for: gridInfo.boardSize)
                    self.gridInsetFraction = gridInfo.gridInsetFraction
                }
                self.detectedGridConfidence = gridInfo.confidence
                self.isProcessing = false
            }
        }
    }

    private func scheduleLiveGridDetectAfterCornerDrag() {
        guard let img = sourceImage else { return }
        liveGridDetectTask?.cancel()
        let shouldAutoSize = autoDetectBoardSize
        let quad = corners
        let currentRule = scoringRule
        let candidates: [BoardSize] = shouldAutoSize ? supportedSizes : [selectedSize]

        liveGridDetectTask = Task.detached(priority: .userInitiated) {
            let gridInfo = GoBoardPhotoRecognizer.detectBoardGridStructure(
                from: img,
                corners: quad,
                candidates: candidates,
                snapCorners: false
            )
            if Task.isCancelled { return }
            await MainActor.run {
                if shouldAutoSize && gridInfo.confidence >= 0.40 {
                    self.selectedSize = gridInfo.boardSize
                    self.komi = currentRule.defaultKomi(for: gridInfo.boardSize)
                }
                if gridInfo.confidence >= 0.40 {
                    self.gridInsetFraction = gridInfo.gridInsetFraction
                }
                self.detectedGridConfidence = gridInfo.confidence
            }
        }
    }

    private func fitInsetForCurrentSelection() {
        guard let img = sourceImage else { return }
        let quad = corners
        let targetSize = selectedSize
        Task.detached(priority: .userInitiated) {
            let gridInfo = GoBoardPhotoRecognizer.detectBoardGridStructure(
                from: img,
                corners: quad,
                candidates: [targetSize],
                snapCorners: false
            )
            await MainActor.run {
                if gridInfo.confidence >= 0.38 {
                    self.gridInsetFraction = gridInfo.gridInsetFraction
                }
            }
        }
    }

    private func runOfflineRecognition() {
        guard let image = sourceImage else { return }
        liveGridDetectTask?.cancel()
        isProcessing = true
        let shouldAutoSize = autoDetectBoardSize
        let chosenSize = selectedSize
        let quad = corners
        let userInset = gridInsetFraction
        let currentRule = scoringRule
        let currentKomi = komi
        let allCandidates = supportedSizes

        Task.detached(priority: .userInitiated) {
            var effectiveSize = chosenSize
            var effectiveInset = userInset
            var effectiveKomi = currentKomi

            if shouldAutoSize {
                let gridInfo = GoBoardPhotoRecognizer.detectBoardGridStructure(
                    from: image,
                    corners: quad,
                    candidates: allCandidates,
                    snapCorners: false
                )
                if gridInfo.confidence >= 0.40 {
                    effectiveSize = gridInfo.boardSize
                    effectiveInset = gridInfo.gridInsetFraction
                    effectiveKomi = currentRule.defaultKomi(for: gridInfo.boardSize)
                }
            }

            let result = GoBoardPhotoRecognizer.recognizeBoard(
                from: image,
                corners: quad,
                boardSize: effectiveSize,
                gridInsetFraction: effectiveInset,
                komi: effectiveKomi
            )
            let autoDead = GoScoring.autoEstimateDeadStones(state: result.boardState)
            let finalSize = effectiveSize
            let finalInset = effectiveInset
            let finalKomi = effectiveKomi
            await MainActor.run {
                self.selectedSize = finalSize
                self.gridInsetFraction = finalInset
                self.komi = finalKomi
                self.recognitionResult = result
                self.loadedWarpedImage = result.warpedBoardImage
                self.boardState = result.boardState
                self.deadStoneIndices = autoDead
                self.openedFromHistory = false
                if self.activeRecordId == nil {
                    self.activeRecordId = UUID()
                    self.activeRecordDate = Date()
                }
                self.persistActiveHistoryRecord(warpedImage: result.warpedBoardImage, eval: nil)
                self.isProcessing = false
                self.stage = .judge
                SoundAndHapticsManager.shared.playSuccess()
                SoundAndHapticsManager.shared.playVoice(.photoDone, delay: 0.16)
                self.refreshEvaluation()
            }
        }
    }

    private func handleBoardTap(_ point: BoardPoint) {
        let idx = boardState.index(row: point.row, col: point.col)
        guard idx >= 0, idx < boardState.grid.count else { return }

        SoundAndHapticsManager.shared.playUITap()
        switch editTool {
        case .cycle:
            switch boardState.grid[idx] {
            case nil: boardState.grid[idx] = .black
            case .black: boardState.grid[idx] = .white
            case .white: boardState.grid[idx] = nil
            }
            deadStoneIndices.remove(idx)
        case .black:
            boardState.grid[idx] = .black
            deadStoneIndices.remove(idx)
        case .white:
            boardState.grid[idx] = .white
            deadStoneIndices.remove(idx)
        case .erase:
            boardState.grid[idx] = nil
            deadStoneIndices.remove(idx)
        case .markDead:
            if let group = boardState.groupAndLiberties(at: idx) {
                let allMarked = group.stones.isSubset(of: deadStoneIndices)
                if allMarked {
                    deadStoneIndices.subtract(group.stones)
                } else {
                    deadStoneIndices.formUnion(group.stones)
                }
            }
        }
        refreshEvaluation()
    }

    private func applyAutoDeadStones() {
        SoundAndHapticsManager.shared.playUITap()
        if let suggested = evaluation?.suggestedDeadIndices {
            deadStoneIndices = suggested
        } else {
            deadStoneIndices = GoScoring.autoEstimateDeadStones(state: boardState)
        }
        refreshEvaluation()
    }

    private func refreshEvaluation() {
        evaluationTask?.cancel()
        let snapshot = boardState
        let rule = scoringRule
        let dead = deadStoneIndices
        isEvaluating = true

        evaluationTask = Task {
            let result = await CoreMLGoAIEngine.shared.evaluateForPhotoJudge(
                state: snapshot,
                rule: rule,
                deadStoneIndices: dead
            )
            if Task.isCancelled { return }
            await MainActor.run {
                self.evaluation = result
                self.isEvaluating = false
                self.persistActiveHistoryRecord(warpedImage: nil, eval: result)
            }
        }
    }

    private func persistActiveHistoryRecord(
        warpedImage: UIImage?,
        eval: CoreMLGoAIEngine.PhotoJudgeEvaluation?
    ) {
        guard let recordId = activeRecordId else { return }
        let recordDate = activeRecordDate ?? Date()
        let gameResult = eval?.gameResult ?? GoScoring.score(
            state: boardState,
            rule: scoringRule,
            deadStoneIndices: deadStoneIndices
        )
        let record = PhotoJudgeRecord.from(
            id: recordId,
            date: recordDate,
            boardState: boardState,
            scoringRule: scoringRule,
            deadStoneIndices: deadStoneIndices,
            result: gameResult,
            blackWinrate: eval?.blackWinrate
        )
        appState.upsertPhotoJudgeRecord(record, warpedImage: warpedImage)
    }

    private func openHistoryRecord(_ record: PhotoJudgeRecord) {
        evaluationTask?.cancel()
        activeRecordId = record.id
        activeRecordDate = record.date
        selectedSize = BoardSize(rawValue: record.boardSize) ?? .nineteen
        scoringRule = record.scoringRule
        komi = record.komi
        boardState = record.makeBoardState()
        deadStoneIndices = Set(record.deadStoneIndices)
        sourceImage = nil
        recognitionResult = nil
        loadedWarpedImage = appState.loadPhotoJudgeImage(for: record)
        showOriginalPhotoOverlay = false
        openedFromHistory = true
        evaluation = nil
        stage = .judge
        refreshEvaluation()
    }

    private func startNewPhotoSession() {
        evaluationTask?.cancel()
        activeRecordId = nil
        activeRecordDate = nil
        sourceImage = nil
        recognitionResult = nil
        loadedWarpedImage = nil
        showOriginalPhotoOverlay = false
        openedFromHistory = false
        evaluation = nil
        stage = .capture
    }
}

// MARK: - Interactive 4-Corner Calibration Overlay

private struct BoardCornerCalibrationOverlay: View {
    let image: UIImage
    @Binding var corners: BoardCornerQuad
    let boardSize: Int
    let gridInsetFraction: CGFloat
    var onDragEnded: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let imageRect = fittedImageRect(imageSize: image.size, containerSize: geo.size)

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)

                // Projected N x N Go grid & quad outline
                Canvas { context, _ in
                    func screenPt(_ norm: CGPoint) -> CGPoint {
                        CGPoint(
                            x: imageRect.minX + norm.x * imageRect.width,
                            y: imageRect.minY + norm.y * imageRect.height
                        )
                    }

                    // Outer quad border
                    var quadPath = Path()
                    quadPath.move(to: screenPt(corners.topLeft))
                    quadPath.addLine(to: screenPt(corners.topRight))
                    quadPath.addLine(to: screenPt(corners.bottomRight))
                    quadPath.addLine(to: screenPt(corners.bottomLeft))
                    quadPath.closeSubpath()
                    context.stroke(quadPath, with: .color(AppTheme.sunTop), lineWidth: 3)

                    // Inner projected grid lines
                    let n = max(2, boardSize)
                    let inset = gridInsetFraction
                    let span = 1.0 - 2.0 * inset
                    for i in 0..<n {
                        let t = inset + span * (CGFloat(i) / CGFloat(n - 1))
                        var hLine = Path()
                        hLine.move(to: screenPt(corners.point(u: inset, v: t)))
                        hLine.addLine(to: screenPt(corners.point(u: 1.0 - inset, v: t)))
                        context.stroke(hLine, with: .color(Color.cyan.opacity(i == 0 || i == n - 1 ? 0.95 : 0.55)), lineWidth: i == 0 || i == n - 1 ? 2.0 : 1.0)

                        var vLine = Path()
                        vLine.move(to: screenPt(corners.point(u: t, v: inset)))
                        vLine.addLine(to: screenPt(corners.point(u: t, v: 1.0 - inset)))
                        context.stroke(vLine, with: .color(Color.cyan.opacity(i == 0 || i == n - 1 ? 0.95 : 0.55)), lineWidth: i == 0 || i == n - 1 ? 2.0 : 1.0)
                    }
                }
                .allowsHitTesting(false)

                // 4 Draggable Glossy Corner Handles
                cornerHandle(point: $corners.topLeft, in: imageRect, color: AppTheme.coralBottom)
                cornerHandle(point: $corners.topRight, in: imageRect, color: AppTheme.skyBottom)
                cornerHandle(point: $corners.bottomRight, in: imageRect, color: AppTheme.mintBottom)
                cornerHandle(point: $corners.bottomLeft, in: imageRect, color: AppTheme.sunBottom)
            }
        }
    }

    private func cornerHandle(point: Binding<CGPoint>, in rect: CGRect, color: Color) -> some View {
        let pos = CGPoint(
            x: rect.minX + point.wrappedValue.x * rect.width,
            y: rect.minY + point.wrappedValue.y * rect.height
        )
        return ZStack {
            Circle()
                .fill(color.opacity(0.28))
                .frame(width: 44, height: 44)
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        }
        .position(pos)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard rect.width > 1, rect.height > 1 else { return }
                    let nx = min(0.99, max(0.01, (value.location.x - rect.minX) / rect.width))
                    let ny = min(0.99, max(0.01, (value.location.y - rect.minY) / rect.height))
                    point.wrappedValue = CGPoint(x: nx, y: ny)
                }
                .onEnded { _ in
                    onDragEnded?()
                }
        )
    }

    private func fittedImageRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(
            x: (containerSize.width - w) / 2,
            y: (containerSize.height - h) / 2,
            width: w,
            height: h
        )
    }
}

// MARK: - Native UIKit Camera Wrapper

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onFinish(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
