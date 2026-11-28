//
//  PhotoBoardJudgeView.swift
//  StarYi Go — 100% Offline Photo Go Board Recognition & Win/Loss Judge
//

import AVFoundation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit

struct PhotoBoardJudgeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

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
    /// Once the player manually marks/unmarks a dead stone we stop auto-applying AI suggestions
    /// so their edits are never overwritten.
    @State private var deadStonesUserEdited = false

    /// The photo judge keeps its pre-AGA rule set: Chinese area or Japanese/Korean territory.
    /// AGA was introduced for the global game settings and must not appear here.
    private static let photoScoringRules: [ScoringRule] = [.chinese, .japanese]

    @State private var komi: Double = 7.5

    @State private var sourceImage: UIImage? = nil
    @State private var corners: BoardCornerQuad = .defaultCentered
    @State private var gridInsetFraction: CGFloat = 0.0
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
    @State private var showCameraDeniedAlert: Bool = false
    @State private var showCameraSettingsParentalGate: Bool = false
    @State private var showClearHistoryAlert: Bool = false
    @State private var showDeleteRecordAlert: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var evaluationTask: Task<Void, Never>? = nil
    @State private var liveGridDetectTask: Task<Void, Never>? = nil
    @State private var activeVisionTask: Task<Void, Never>? = nil
    @State private var activeVisionTaskID: UUID = UUID()

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
            SceneBackdrop.bambooPond

            VStack(spacing: 12) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Group {
                    switch stage {
                    case .capture:
                        captureStageView
                            .padding(.bottom, 14)
                    case .calibrate:
                        calibrateStageView
                            .padding(.bottom, 14)
                    case .judge:
                        judgeStageView
                            .padding(.bottom, 14)
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
            }

            if isProcessing {
                processingOverlay
            }

            if showCameraSettingsParentalGate {
                ParentalGateOverlay(
                    l10n: l10n,
                    onCancel: {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            showCameraSettingsParentalGate = false
                        }
                    },
                    onSuccess: {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            showCameraSettingsParentalGate = false
                        }
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                )
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: showCameraSettingsParentalGate)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            // Photo judging keeps its own default (Chinese area scoring). The global scoring
            // preference is intentionally not applied here: on regions that map to Japanese /
            // AGA it silently changed the result for every photo. Users can still switch
            // in-page below.
            scoringRule = .chinese
            let savedRaw = UserDefaults.standard.integer(forKey: "photoJudgePreferredBoardSize")
            selectedSize = BoardSize(rawValue: savedRaw) ?? .nineteen
            autoDetectBoardSize = UserDefaults.standard.bool(forKey: "photoJudgeAutoDetectBoardSize")
            komi = scoringRule.defaultKomi(for: selectedSize)
        }
        .onDisappear {
            evaluationTask?.cancel()
            liveGridDetectTask?.cancel()
            activeVisionTask?.cancel()
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
                   let image = Self.downsampledPickedImage(from: data, maxDimension: 1400) ?? UIImage(data: data) {
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
            isPresented: $showCameraDeniedAlert,
            title: l10n.localized(
                zh: "未开启相机权限",
                en: "Camera Access Needed",
                ja: "カメラへのアクセスが必要です",
                ko: "카메라 권한이 필요합니다",
                zhHant: "未開啟相機權限"
            ),
            message: l10n.localized(
                zh: "请在系统设置中允许星弈围棋访问相机，以便离线拍摄棋盘；你也可以直接从相册选择照片。",
                en: "Please allow camera access in Settings to photograph your Go board offline, or choose a photo from your library.",
                ja: "設定でカメラへのアクセスを許可すると碁盤を撮影できます。写真ライブラリから選ぶこともできます。",
                ko: "설정에서 카메라 접근을 허용하면 바둑판을 촬영할 수 있으며, 앨범에서 사진을 선택할 수도 있습니다.",
                zhHant: "請在系統設定中允許星弈圍棋存取相機，以便離線拍攝棋盤；你也可以直接從相簿選擇照片。"
            ),
            icon: "camera.badge.ellipsis",
            accentPalette: .sky,
            actions: [
                .secondary(l10n.localized(zh: "从相册选择", en: "Photo Library", ja: "写真から選択", ko: "앨범에서 선택", zhHant: "從相簿選擇")) {
                    showPhotoPicker = true
                },
                .primary(l10n.localized(zh: "前往设置", en: "Open Settings", ja: "設定を開く", ko: "설정 열기", zhHant: "前往設定"), palette: .sky) {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        showCameraSettingsParentalGate = true
                    }
                }
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
        ZStack {
            topBarTitleCrest

            HStack(spacing: 12) {
                topBarBackButton
                Spacer(minLength: 12)

                if stage == .judge {
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
                            .font(AppFont.rounded(size: 12.5, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: showOriginalPhotoOverlay ? .sun : .sky, cornerRadius: 999, rimHeight: 2, whiteBorderWidth: 2.5))
                        .accessibilityIdentifier("PhotoJudgeComparePhotoButton")
                    }

                    if activeRecordId != nil {
                        Button(role: .destructive) {
                            SoundAndHapticsManager.shared.playUITap()
                            showDeleteRecordAlert = true
                        } label: {
                            Label(
                                l10n.localized(zh: "删除", en: "Delete", ja: "削除", ko: "삭제", zhHant: "刪除"),
                                systemImage: "trash"
                            )
                            .font(AppFont.rounded(size: 13, weight: .black))
                            .foregroundColor(AppTheme.coralBottom)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 2.5, whiteBorderWidth: 2.5))
                        .accessibilityLabel(l10n.localized(zh: "删除此记录", en: "Delete Record", ja: "この履歴を削除", ko: "이 기록 삭제", zhHant: "刪除此記錄"))
                        .accessibilityIdentifier("PhotoJudgeTopDeleteButton")
                    }
                } else if stage == .calibrate {
                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        stage = .history
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 13, weight: .black, design: .rounded))
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
                            .font(AppFont.rounded(size: 12.5, weight: .black))
                        }
                        .foregroundColor(AppTheme.inkPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 2, whiteBorderWidth: 2.5))
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
                        .font(AppFont.rounded(size: 13, weight: .black))
                        .foregroundColor(AppTheme.coralBottom)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 2.5, whiteBorderWidth: 2.5))
                    .accessibilityIdentifier("PhotoJudgeHistoryClearAllButton")
                }
            }
        }
        .frame(maxWidth: .infinity)
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
                )
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

    private func handleTakePhotoTap() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailableAlert = true
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCameraSheet = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        showCameraSheet = true
                    } else {
                        showCameraDeniedAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraDeniedAlert = true
        @unknown default:
            showCameraDeniedAlert = true
        }
    }

    private func takePhotoHeroCard(height: CGFloat, isCompact: Bool) -> some View {
        Button {
            SoundAndHapticsManager.shared.playUITap()
            handleTakePhotoTap()
        } label: {
            VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.24))
                        .frame(width: isCompact ? 46 : 62, height: isCompact ? 46 : 62)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: 2.5))
                    Image(systemName: "camera.fill")
                        .font(.system(size: isCompact ? 22 : 30, weight: .black, design: .rounded))
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
                    .font(AppFont.rounded(size: isCompact ? 22 : 30, weight: .black))
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
                    .font(AppFont.rounded(size: isCompact ? 11.5 : 13.5, weight: .bold))
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
                        .font(.system(size: isCompact ? 21 : 28, weight: .black, design: .rounded))
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
                    .font(AppFont.rounded(size: isCompact ? 22 : 30, weight: .black))
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
                    .font(AppFont.rounded(size: isCompact ? 11.5 : 13.5, weight: .bold))
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
                        .font(.system(size: isCompact ? 22 : 30, weight: .black, design: .rounded))
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
                    .font(AppFont.rounded(size: isCompact ? 20 : 26, weight: .black))
                    .foregroundColor(.white)
                    .shadow(color: AppTheme.grapeRim.opacity(0.55), radius: 2, y: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                    Text("\(appState.photoJudgeHistory.count)/\(PhotoJudgeRecord.maxStoredCount)")
                        .font(AppFont.rounded(size: isCompact ? 11.5 : 13.5, weight: .bold))
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
            Group {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(red: 0.09, green: 0.14, blue: 0.24))
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(red: 0.09, green: 0.14, blue: 0.24).opacity(0.58))
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(colorSchemeContrast == .increased ? 0.78 : 0.35), lineWidth: colorSchemeContrast == .increased ? 2.0 : 1.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 5)
    }

    private func boardSizeRuleGroup(isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 5 : 7) {
            Text(l10n.localized(zh: "棋盘规格", en: "Board", ja: "盤サイズ", ko: "바둑판", zhHant: "棋盤規格"))
                .font(AppFont.rounded(size: isCompact ? 11.5 : 12.5, weight: .black))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize()

            Button {
                SoundAndHapticsManager.shared.playUITap()
                autoDetectBoardSize = true
                UserDefaults.standard.set(true, forKey: "photoJudgeAutoDetectBoardSize")
            } label: {
                Text(l10n.localized(zh: "自动", en: "Auto", ja: "自動", ko: "자동", zhHant: "自動"))
                    .font(AppFont.rounded(size: isCompact ? 11.5 : 12.5, weight: .black))
                    .foregroundColor(autoDetectBoardSize ? .white : AppTheme.inkPrimary)
                    .padding(.horizontal, isCompact ? 9 : 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(
                GlossyCapsuleButtonStyle(
                    palette: autoDetectBoardSize ? .mint : .snow,
                    cornerRadius: 12,
                    rimHeight: 2,
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
                    UserDefaults.standard.set(false, forKey: "photoJudgeAutoDetectBoardSize")
                    UserDefaults.standard.set(size.rawValue, forKey: "photoJudgePreferredBoardSize")
                } label: {
                    Text("\(size.rawValue)×\(size.rawValue)")
                        .font(AppFont.rounded(size: isCompact ? 11.5 : 12.5, weight: .black))
                        .foregroundColor(isSelected ? .white : AppTheme.inkPrimary)
                        .padding(.horizontal, isCompact ? 8 : 11)
                        .padding(.vertical, 6)
                }
                .buttonStyle(
                    GlossyCapsuleButtonStyle(
                        palette: isSelected ? .sky : .snow,
                        cornerRadius: 12,
                        rimHeight: 2,
                        whiteBorderWidth: 2
                    )
                )
            }
        }
    }

    private func scoringRuleGroup(isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 6 : 8) {
            Text(l10n.localized(zh: "计分规则", en: "Rules", ja: "ルール", ko: "규칙", zhHant: "計分規則"))
                .font(AppFont.rounded(size: isCompact ? 11.5 : 12.5, weight: .black))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize()

            ForEach(Self.photoScoringRules) { rule in
                let isSelected = scoringRule == rule
                Button {
                    SoundAndHapticsManager.shared.playUITap()
                    scoringRule = rule
                    komi = rule.defaultKomi(for: selectedSize)
                } label: {
                    Text(ruleLabel(rule))
                        .font(AppFont.rounded(size: isCompact ? 11.5 : 12.5, weight: .black))
                        .foregroundColor(isSelected ? .white : AppTheme.inkPrimary)
                        .padding(.horizontal, isCompact ? 10 : 13)
                        .padding(.vertical, 6)
                }
                .buttonStyle(
                    GlossyCapsuleButtonStyle(
                        palette: isSelected ? .grape : .snow,
                        cornerRadius: 12,
                        rimHeight: 2,
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
                        zh: "拖动 4 个彩色圆环对齐网格四角",
                        en: "Drag the 4 Rings to Grid Corners",
                        ja: "4つの丸を最外周の四隅に合わせてください",
                        ko: "4개의 링을 바둑판 최외곽 네 모서리에 맞추세요",
                        zhHant: "拖動 4 個彩色圓環對齊網格四角"
                    ))
                    .font(AppFont.rounded(size: 16, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)

                    Text(l10n.localized(
                        zh: "把每个圆环的准星直接对准最边角交叉点（1-1、1-19 等），拖动时放大镜会实时放大手指位置与青色网格。",
                        en: "Align each crosshair directly onto the 4 outermost grid intersections. The magnifier zooms right under your fingertip.",
                        ja: "各リングの照準を最外周の四隅の交点に直接合わせてください。ドラッグ中は指先を拡大表示します。",
                        ko: "각 링의 십자선을 바둑판 최외곽 모서리 교차점에 맞추세요. 드래그 시 손가락 위치가 확대됩니다.",
                        zhHant: "把每個圓環的準星直接對準最邊角交叉點（1-1、1-19 等），拖動時放大鏡會即時放大手指位置與青色網格。"
                    ))
                    .font(AppFont.rounded(size: 12.5, weight: .bold))
                    .foregroundColor(AppTheme.inkSecondary)

                    // Board Size quick switcher
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(l10n.localized(zh: "棋盘路数", en: "Board Size", ja: "路数", ko: "바둑판 크기", zhHant: "棋盤路數"))
                                .font(AppFont.rounded(size: 12, weight: .heavy))
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
                                .font(AppFont.rounded(size: 11, weight: .black))
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
                                    UserDefaults.standard.set(false, forKey: "photoJudgeAutoDetectBoardSize")
                                    UserDefaults.standard.set(size.rawValue, forKey: "photoJudgePreferredBoardSize")
                                } label: {
                                    Text("\(size.rawValue)×\(size.rawValue)")
                                        .font(AppFont.rounded(size: 13, weight: .black))
                                        .foregroundColor(isSelected ? .white : AppTheme.inkPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(
                                    GlossyCapsuleButtonStyle(
                                        palette: isSelected ? .sky : .snow,
                                        cornerRadius: 14,
                                        rimHeight: 2,
                                        whiteBorderWidth: 2
                                    )
                                )
                            }
                        }
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
                            .font(AppFont.rounded(size: 12, weight: .heavy))
                            .foregroundColor(AppTheme.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 14, rimHeight: 2.5, whiteBorderWidth: 2))

                        Button {
                            if let img = sourceImage {
                                SoundAndHapticsManager.shared.playUITap()
                                autoDetectBoardSize = true
                                UserDefaults.standard.set(true, forKey: "photoJudgeAutoDetectBoardSize")
                                detectGridForCurrentCorners(in: img)
                            }
                        } label: {
                            Label(
                                l10n.localized(zh: "识别路数", en: "Auto Size", ja: "路数検出", ko: "크기 자동", zhHant: "識別路數"),
                                systemImage: "sparkles"
                            )
                            .font(AppFont.rounded(size: 12, weight: .heavy))
                            .foregroundColor(AppTheme.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 14, rimHeight: 2.5, whiteBorderWidth: 2))
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
                        .font(AppFont.rounded(size: 19, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 22, rimHeight: 4, whiteBorderWidth: 3.5, showStripeSheen: true))
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
                        .accessibilityIgnoresInvertColors()
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
                            .font(AppFont.rounded(size: 13, weight: .black))
                            .foregroundColor(AppTheme.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 16, rimHeight: 2.5, whiteBorderWidth: 2.5))
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
            } else if scoringRule == .aga {
                let m = String(format: "%.1f", result.margin)
                return l10n.localized(
                    zh: "\(m) 点",
                    en: "+\(m)",
                    ja: "\(m)点",
                    ko: "\(m)점",
                    zhHant: "\(m) 點"
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
        let blackPrimaryNum = scoringRule.isAreaScoring ? "\(blackAreaTotal)" : "\(result.blackTerritory)"
        let whitePrimaryNum = scoringRule.isAreaScoring ? "\(whiteAreaTotal)" : "\(result.whiteTerritory)"
        let areaUnit: String = {
            if scoringRule == .aga {
                return l10n.localized(zh: "点", en: "pts", ja: "点", ko: "점", zhHant: "點")
            }
            if scoringRule == .chinese {
                return l10n.localized(zh: "子", en: "pts", ja: "子", ko: "점", zhHant: "子")
            }
            return l10n.localized(zh: "目", en: "pts", ja: "目", ko: "집", zhHant: "目")
        }()

        let detail = scoringRule.isAreaScoring
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
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.sunTop)
                        .offset(y: -22)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(winnerTitle)
                        .font(AppFont.rounded(size: 28, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: palette.rim.opacity(0.55), radius: 2, y: 2)

                    Text(marginDisplay)
                        .font(AppFont.rounded(size: 32, weight: .black))
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
                            .font(AppFont.rounded(size: 12.5, weight: .black))
                            .foregroundColor(.white.opacity(0.92))
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(blackPrimaryNum)
                            .font(AppFont.rounded(size: 30, weight: .black))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                        Text(areaUnit)
                            .font(AppFont.rounded(size: 14, weight: .heavy))
                            .foregroundColor(.white.opacity(0.88))
                    }

                    Text(l10n.localized(
                        zh: "黑子 \(result.blackStones) · 空 \(result.blackTerritory)",
                        en: "Stones \(result.blackStones) · Emp \(result.blackTerritory)",
                        ja: "石 \(result.blackStones) · 空 \(result.blackTerritory)",
                        ko: "돌 \(result.blackStones) · 집 \(result.blackTerritory)",
                        zhHant: "黑子 \(result.blackStones) · 空 \(result.blackTerritory)"
                    ))
                    .font(AppFont.rounded(size: 12, weight: .bold))
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
                            .font(AppFont.rounded(size: 12.5, weight: .black))
                            .foregroundColor(AppTheme.inkPrimary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(whitePrimaryNum)
                            .font(AppFont.rounded(size: 30, weight: .black))
                            .foregroundColor(AppTheme.inkPrimary)
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                        Text(areaUnit)
                            .font(AppFont.rounded(size: 14, weight: .heavy))
                            .foregroundColor(AppTheme.inkSecondary)
                    }

                    Text(l10n.localized(
                        zh: "白子 \(result.whiteStones) · 空 \(result.whiteTerritory)",
                        en: "Stones \(result.whiteStones) · Emp \(result.whiteTerritory)",
                        ja: "石 \(result.whiteStones) · 空 \(result.whiteTerritory)",
                        ko: "돌 \(result.whiteStones) · 집 \(result.whiteTerritory)",
                        zhHant: "白子 \(result.whiteStones) · 空 \(result.whiteTerritory)"
                    ))
                    .font(AppFont.rounded(size: 12, weight: .bold))
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
                .font(AppFont.rounded(size: 12.5, weight: .heavy))
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
                .font(AppFont.rounded(size: 13, weight: .black))
                .foregroundColor(AppTheme.inkSecondary)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Circle()
                        .fill(Color(white: 0.14))
                        .frame(width: 12, height: 12)
                    Text(l10n.localized(zh: "黑", en: "B", ja: "黒", ko: "흑", zhHant: "黑"))
                        .font(AppFont.rounded(size: 14, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text("\(blackPct)%")
                        .font(AppFont.rounded(size: 24, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(whitePct)%")
                        .font(AppFont.rounded(size: 24, weight: .black))
                        .foregroundColor(AppTheme.skyBottom)
                    Text(l10n.localized(zh: "白", en: "W", ja: "白", ko: "백", zhHant: "白"))
                        .font(AppFont.rounded(size: 14, weight: .black))
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
                .font(AppFont.rounded(size: 12, weight: .black))
                .foregroundColor(AppTheme.inkPrimary)

                Spacer()

                Button {
                    applyAutoDeadStones()
                } label: {
                    Label(
                        l10n.localized(zh: "自动标死子", en: "Auto Dead", ja: "死石自動", ko: "사석 자동", zhHant: "自動標死子"),
                        systemImage: "wand.and.stars.inverse"
                    )
                    .font(AppFont.rounded(size: 11, weight: .black))
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
                    .font(.system(size: 12, weight: .black, design: .rounded))
                Text(title)
                    .font(AppFont.rounded(size: 10, weight: .black))
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
                ForEach(Self.photoScoringRules) { rule in
                    let active = scoringRule == rule
                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        scoringRule = rule
                        komi = rule.defaultKomi(for: selectedSize)
                        boardState.komi = komi
                        refreshEvaluation()
                    } label: {
                        Text(ruleLabel(rule))
                            .font(AppFont.rounded(size: 11.5, weight: .black))
                            .foregroundColor(active ? .white : AppTheme.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(active ? AppTheme.grapeBottom : Color.white))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)

            HStack {
                Text(l10n.localized(zh: "贴目 (Komi)", en: "Komi", ja: "コミ", ko: "덤 (Komi)", zhHant: "貼目 (Komi)"))
                    .font(AppFont.rounded(size: 12, weight: .heavy))
                    .foregroundColor(AppTheme.inkSecondary)

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        komi = max(0, komi - 0.5)
                        boardState.komi = komi
                        refreshEvaluation()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 18, design: .rounded))
                            .foregroundColor(AppTheme.skyBottom)
                    }
                    Text(String(format: "%.1f", komi))
                        .font(AppFont.rounded(size: 13, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(minWidth: 34)
                    Button {
                        komi = min(20, komi + 0.5)
                        boardState.komi = komi
                        refreshEvaluation()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, design: .rounded))
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
                .font(AppFont.rounded(size: 12, weight: .heavy))
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
                .font(AppFont.rounded(size: 15, weight: .black))
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
            return l10n.localized(zh: "日韩数目法", en: "JP/KR Territory", ja: "日韓ルール", ko: "한국·일본식", zhHant: "日韓數目法")
        case .aga:
            return l10n.localized(zh: "AGA面积法", en: "AGA Area", ja: "AGA面積", ko: "AGA 면적", zhHant: "AGA面積法")
        }
    }

    private func handlePickedImage(_ image: UIImage) {
        liveGridDetectTask?.cancel()
        activeVisionTask?.cancel()
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

        let taskID = UUID()
        activeVisionTaskID = taskID
        activeVisionTask = Task.detached(priority: .userInitiated) {
            defer {
                Task { @MainActor in
                    if self.activeVisionTaskID == taskID {
                        self.isProcessing = false
                    }
                }
            }
            let upright = GoBoardPhotoRecognizer.normalizedUpImage(image, maxDimension: 1400)
            let candidates: [BoardSize] = shouldAutoSize ? allCandidates : [manualSize]
            let autoResult = GoBoardPhotoRecognizer.autoDetectBoardAndGrid(
                in: upright,
                candidates: candidates
            )
            if Task.isCancelled { return }

            await MainActor.run {
                guard self.activeVisionTaskID == taskID else { return }
                self.sourceImage = upright
                // Place the 4 draggable handles directly onto the 4 outermost grid intersections (1-1, 1-N, N-N, N-1)
                self.corners = autoResult.confidence >= 0.38
                    ? autoResult.corners.insetBy(autoResult.gridInsetFraction)
                    : autoResult.corners
                self.gridInsetFraction = 0.0
                if shouldAutoSize && autoResult.confidence >= 0.38 {
                    self.selectedSize = autoResult.boardSize
                    self.komi = currentRule.defaultKomi(for: autoResult.boardSize)
                }
                self.detectedGridConfidence = autoResult.confidence
                self.isProcessing = false
                self.stage = .calibrate
            }
        }
    }

    private func reDetectCornersAndGrid(in image: UIImage) {
        liveGridDetectTask?.cancel()
        activeVisionTask?.cancel()
        isProcessing = true
        let taskID = UUID()
        activeVisionTaskID = taskID
        let shouldAutoSize = autoDetectBoardSize
        let manualSize = selectedSize
        let currentRule = scoringRule
        let allCandidates = supportedSizes

        activeVisionTask = Task.detached(priority: .userInitiated) {
            defer {
                Task { @MainActor in
                    if self.activeVisionTaskID == taskID {
                        self.isProcessing = false
                    }
                }
            }
            let candidates: [BoardSize] = shouldAutoSize ? allCandidates : [manualSize]
            let autoResult = GoBoardPhotoRecognizer.autoDetectBoardAndGrid(
                in: image,
                candidates: candidates
            )
            if Task.isCancelled { return }
            await MainActor.run {
                guard self.activeVisionTaskID == taskID else { return }
                self.corners = autoResult.confidence >= 0.38
                    ? autoResult.corners.insetBy(autoResult.gridInsetFraction)
                    : autoResult.corners
                self.gridInsetFraction = 0.0
                if shouldAutoSize && autoResult.confidence >= 0.38 {
                    self.selectedSize = autoResult.boardSize
                    self.komi = currentRule.defaultKomi(for: autoResult.boardSize)
                }
                self.detectedGridConfidence = autoResult.confidence
                self.isProcessing = false
            }
        }
    }

    private func detectGridForCurrentCorners(in image: UIImage) {
        liveGridDetectTask?.cancel()
        activeVisionTask?.cancel()
        isProcessing = true
        let taskID = UUID()
        activeVisionTaskID = taskID
        let quad = corners
        let currentRule = scoringRule
        let allCandidates = supportedSizes

        activeVisionTask = Task.detached(priority: .userInitiated) {
            defer {
                Task { @MainActor in
                    if self.activeVisionTaskID == taskID {
                        self.isProcessing = false
                    }
                }
            }
            let gridInfo = GoBoardPhotoRecognizer.detectBoardGridStructure(
                from: image,
                corners: quad,
                candidates: allCandidates,
                snapCorners: true
            )
            if Task.isCancelled { return }
            await MainActor.run {
                guard self.activeVisionTaskID == taskID else { return }
                if let snapped = gridInfo.refinedCorners, gridInfo.confidence >= 0.45 {
                    self.corners = snapped.insetBy(gridInfo.gridInsetFraction)
                }
                self.gridInsetFraction = 0.0
                if gridInfo.confidence >= 0.38 {
                    self.selectedSize = gridInfo.boardSize
                    self.komi = currentRule.defaultKomi(for: gridInfo.boardSize)
                }
                self.detectedGridConfidence = gridInfo.confidence
                self.isProcessing = false
            }
        }
    }

    private func scheduleLiveGridDetectAfterCornerDrag() {
        guard autoDetectBoardSize, let img = sourceImage else { return }
        liveGridDetectTask?.cancel()
        let quad = corners
        let currentRule = scoringRule

        liveGridDetectTask = Task.detached(priority: .userInitiated) {
            let gridInfo = GoBoardPhotoRecognizer.detectBoardGridStructure(
                from: img,
                corners: quad,
                candidates: supportedSizes,
                snapCorners: false
            )
            if Task.isCancelled { return }
            await MainActor.run {
                if gridInfo.confidence >= 0.45 {
                    self.selectedSize = gridInfo.boardSize
                    self.komi = currentRule.defaultKomi(for: gridInfo.boardSize)
                }
                self.detectedGridConfidence = gridInfo.confidence
            }
        }
    }

    /// Decodes a picked photo directly to a bounded pixel size via ImageIO to avoid 50-100 MB full-res memory spikes.
    private static func downsampledPickedImage(from data: Data, maxDimension: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func fitInsetForCurrentSelection() {
        guard let img = sourceImage else { return }
        activeVisionTask?.cancel()
        isProcessing = false
        let taskID = UUID()
        activeVisionTaskID = taskID
        let quad = corners
        let targetSize = selectedSize
        activeVisionTask = Task.detached(priority: .userInitiated) {
            let gridInfo = GoBoardPhotoRecognizer.detectBoardGridStructure(
                from: img,
                corners: quad,
                candidates: [targetSize],
                snapCorners: false
            )
            if Task.isCancelled { return }
            await MainActor.run {
                guard self.activeVisionTaskID == taskID else { return }
                if gridInfo.confidence >= 0.38 {
                    self.gridInsetFraction = gridInfo.gridInsetFraction
                }
            }
        }
    }

    private func runOfflineRecognition() {
        guard let image = sourceImage else { return }
        liveGridDetectTask?.cancel()
        activeVisionTask?.cancel()
        isProcessing = true
        let shouldAutoSize = autoDetectBoardSize
        let chosenSize = selectedSize
        let quad = corners
        let userInset = gridInsetFraction
        let currentRule = scoringRule
        let currentKomi = komi
        let allCandidates = supportedSizes

        let taskID = UUID()
        activeVisionTaskID = taskID
        activeVisionTask = Task.detached(priority: .userInitiated) {
            defer {
                Task { @MainActor in
                    if self.activeVisionTaskID == taskID {
                        self.isProcessing = false
                    }
                }
            }
            var effectiveSize = chosenSize
            let effectiveInset = userInset
            var effectiveKomi = currentKomi

            if shouldAutoSize {
                let gridInfo = GoBoardPhotoRecognizer.detectBoardGridStructure(
                    from: image,
                    corners: quad,
                    candidates: allCandidates,
                    snapCorners: false
                )
                if Task.isCancelled { return }
                if gridInfo.confidence >= 0.45 {
                    effectiveSize = gridInfo.boardSize
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
            if Task.isCancelled { return }
            let autoDead = GoScoring.autoEstimateDeadStones(state: result.boardState)
            let finalSize = effectiveSize
            let finalInset = effectiveInset
            let finalKomi = effectiveKomi
            await MainActor.run {
                self.selectedSize = finalSize
                self.gridInsetFraction = finalInset
                self.komi = finalKomi
                self.recognitionResult = result
                self.loadedWarpedImage = nil
                self.boardState = result.boardState
                self.deadStoneIndices = autoDead
                self.deadStonesUserEdited = false
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

        deadStonesUserEdited = true
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
        deadStonesUserEdited = true
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
                // Auto-apply the (now working) neural dead-stone suggestions on a freshly
                // recognized photo. Manual edits are preserved.
                if !self.deadStonesUserEdited {
                    self.deadStoneIndices = result.suggestedDeadIndices
                }
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
        // Records saved while the global AGA rule leaked into photo judging are treated as
        // Chinese area scoring (identical math) so old photos read the way they used to.
        scoringRule = record.scoringRule == .aga ? .chinese : record.scoringRule
        komi = record.komi
        boardState = record.makeBoardState()
        deadStoneIndices = Set(record.deadStoneIndices)
        deadStonesUserEdited = true
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
        deadStonesUserEdited = false
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

    @State private var activeDragNormalizedPoint: CGPoint? = nil
    @State private var activeDragColor: Color = AppTheme.coralBottom

    var body: some View {
        GeometryReader { geo in
            let imageRect = fittedImageRect(imageSize: image.size, containerSize: geo.size)

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityIgnoresInvertColors()
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)

                // Projected N x N Go grid & quad outline (using exact projective homography to match CIPerspectiveCorrection)
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
                        hLine.move(to: screenPt(corners.projectivePoint(u: inset, v: t)))
                        hLine.addLine(to: screenPt(corners.projectivePoint(u: 1.0 - inset, v: t)))
                        context.stroke(hLine, with: .color(Color.cyan.opacity(i == 0 || i == n - 1 ? 0.95 : 0.55)), lineWidth: i == 0 || i == n - 1 ? 2.0 : 1.0)

                        var vLine = Path()
                        vLine.move(to: screenPt(corners.projectivePoint(u: t, v: inset)))
                        vLine.addLine(to: screenPt(corners.projectivePoint(u: t, v: 1.0 - inset)))
                        context.stroke(vLine, with: .color(Color.cyan.opacity(i == 0 || i == n - 1 ? 0.95 : 0.55)), lineWidth: i == 0 || i == n - 1 ? 2.0 : 1.0)
                    }
                }
                .allowsHitTesting(false)

                // 4 Draggable Glossy Corner Handles
                cornerHandle(point: $corners.topLeft, in: imageRect, color: AppTheme.coralBottom)
                cornerHandle(point: $corners.topRight, in: imageRect, color: AppTheme.skyBottom)
                cornerHandle(point: $corners.bottomRight, in: imageRect, color: AppTheme.mintBottom)
                cornerHandle(point: $corners.bottomLeft, in: imageRect, color: AppTheme.sunBottom)

                // 2.5× Magnifier Loupe while dragging any corner handle so fingertips never obscure the board corner
                if let dragPt = activeDragNormalizedPoint {
                    magnifierLoupe(
                        normalizedPoint: dragPt,
                        imageRect: imageRect,
                        containerSize: geo.size,
                        accentColor: activeDragColor
                    )
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
                }
            }
        }
    }

    private func magnifierLoupe(
        normalizedPoint: CGPoint,
        imageRect: CGRect,
        containerSize: CGSize,
        accentColor: Color
    ) -> some View {
        let loupeDiameter: CGFloat = 136
        let loupeRadius = loupeDiameter * 0.5
        let zoom: CGFloat = 3.0
        let anchorX = imageRect.minX + normalizedPoint.x * imageRect.width
        let anchorY = imageRect.minY + normalizedPoint.y * imageRect.height

        // Position loupe comfortably clear of the user's fingertip (above by default; below when near top edge)
        let preferAboveY = anchorY - (loupeRadius + 46)
        let loupeY: CGFloat = preferAboveY < loupeRadius + 8
            ? min(containerSize.height - loupeRadius - 8, anchorY + (loupeRadius + 46))
            : preferAboveY
        let loupeX = min(
            max(loupeRadius + 8, anchorX),
            max(loupeRadius + 8, containerSize.width - loupeRadius - 8)
        )

        return Canvas { context, size in
            let cx = size.width * 0.5
            let cy = size.height * 0.5

            // Maps any normalized image coordinate directly into the 3x zoomed loupe centered on `normalizedPoint` (the fingertip).
            func loupePt(_ norm: CGPoint) -> CGPoint {
                CGPoint(
                    x: cx + (norm.x - normalizedPoint.x) * imageRect.width * zoom,
                    y: cy + (norm.y - normalizedPoint.y) * imageRect.height * zoom
                )
            }

            // Dark backdrop for out-of-bounds areas when aligning corners right against the photo border
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.black.opacity(0.92)))

            // Draw zoomed photo with exact pixel alignment to the fingertip coordinate
            let photoOrigin = loupePt(CGPoint(x: 0, y: 0))
            let photoRect = CGRect(
                x: photoOrigin.x,
                y: photoOrigin.y,
                width: imageRect.width * zoom,
                height: imageRect.height * zoom
            )
            context.draw(Image(uiImage: image), in: photoRect)

            // Draw the live projected N x N grid lines right inside the magnifier so the corner lines snap visually
            let n = max(2, boardSize)
            let inset = gridInsetFraction
            let span = 1.0 - 2.0 * inset
            for i in 0..<n {
                let t = inset + span * (CGFloat(i) / CGFloat(n - 1))
                let isOuter = (i == 0 || i == n - 1)
                let lineColor = isOuter ? Color.cyan.opacity(0.95) : Color.cyan.opacity(0.55)
                let lineWidth: CGFloat = isOuter ? 2.2 : 1.1

                var hLine = Path()
                hLine.move(to: loupePt(corners.projectivePoint(u: inset, v: t)))
                hLine.addLine(to: loupePt(corners.projectivePoint(u: 1.0 - inset, v: t)))
                context.stroke(hLine, with: .color(lineColor), lineWidth: lineWidth)

                var vLine = Path()
                vLine.move(to: loupePt(corners.projectivePoint(u: t, v: inset)))
                vLine.addLine(to: loupePt(corners.projectivePoint(u: t, v: 1.0 - inset)))
                context.stroke(vLine, with: .color(lineColor), lineWidth: lineWidth)
            }

            // Precision open-center crosshair so the exact 1-1 corner intersection remains unobstructed
            let gap: CGFloat = 5
            let arm: CGFloat = 20
            var cross = Path()
            cross.move(to: CGPoint(x: cx - arm, y: cy))
            cross.addLine(to: CGPoint(x: cx - gap, y: cy))
            cross.move(to: CGPoint(x: cx + gap, y: cy))
            cross.addLine(to: CGPoint(x: cx + arm, y: cy))
            cross.move(to: CGPoint(x: cx, y: cy - arm))
            cross.addLine(to: CGPoint(x: cx, y: cy - gap))
            cross.move(to: CGPoint(x: cx, y: cy + gap))
            cross.addLine(to: CGPoint(x: cx, y: cy + arm))
            context.stroke(cross, with: .color(.white.opacity(0.95)), lineWidth: 3.0)
            context.stroke(cross, with: .color(accentColor), lineWidth: 1.6)

            let centerRing = Path(ellipseIn: CGRect(x: cx - gap, y: cy - gap, width: gap * 2, height: gap * 2))
            context.stroke(centerRing, with: .color(.white.opacity(0.95)), lineWidth: 2.2)
            context.stroke(centerRing, with: .color(accentColor), lineWidth: 1.2)
        }
        .frame(width: loupeDiameter, height: loupeDiameter)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white, lineWidth: 4))
        .overlay(Circle().strokeBorder(accentColor, lineWidth: 2))
        .shadow(color: .black.opacity(0.36), radius: 12, y: 6)
        .position(x: loupeX, y: loupeY)
    }

    private func cornerHandle(point: Binding<CGPoint>, in rect: CGRect, color: Color) -> some View {
        let pos = CGPoint(
            x: rect.minX + point.wrappedValue.x * rect.width,
            y: rect.minY + point.wrappedValue.y * rect.height
        )
        return ZStack {
            // Generous 48pt touch target
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 48, height: 48)
            // Open target ring so the underlying 1-1 grid intersection stays visible even at rest
            Circle()
                .strokeBorder(.white, lineWidth: 4.5)
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1.5)
            Circle()
                .strokeBorder(color, lineWidth: 2.5)
                .frame(width: 24, height: 24)
            Circle()
                .fill(color)
                .frame(width: 4.5, height: 4.5)
        }
        .position(pos)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard rect.width > 1, rect.height > 1 else { return }
                    let nx = min(0.998, max(0.002, (value.location.x - rect.minX) / rect.width))
                    let ny = min(0.998, max(0.002, (value.location.y - rect.minY) / rect.height))
                    let pt = CGPoint(x: nx, y: ny)
                    point.wrappedValue = pt
                    activeDragNormalizedPoint = pt
                    activeDragColor = color
                }
                .onEnded { _ in
                    activeDragNormalizedPoint = nil
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
