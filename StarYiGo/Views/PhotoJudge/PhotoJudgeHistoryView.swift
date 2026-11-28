//
//  PhotoJudgeHistoryView.swift
//  StarYi Go — Photo Go Judge History Browser (Up to 100 Records, Grouped by Day)
//

import SwiftUI
import UIKit

struct PhotoJudgeHistoryView: View {
    @EnvironmentObject var appState: AppState

    let onSelectRecord: (PhotoJudgeRecord) -> Void
    let onStartNewPhoto: () -> Void

    private var l10n: L10n { appState.l10n }

    private struct DaySection: Identifiable {
        let dayStart: Date
        let records: [PhotoJudgeRecord]
        var id: Date { dayStart }
    }

    private var groupedByDay: [DaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: appState.photoJudgeHistory) { record in
            calendar.startOfDay(for: record.date)
        }
        return grouped.keys.sorted(by: >).map { day in
            let items = (grouped[day] ?? []).sorted { $0.date > $1.date }
            return DaySection(dayStart: day, records: items)
        }
    }

    var body: some View {
        if appState.photoJudgeHistory.isEmpty {
            emptyStateView
                .padding(.bottom, 14)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedByDay) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            dayHeader(section)

                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 420, maximum: 620), spacing: 18)],
                                spacing: 16
                            ) {
                                ForEach(section.records) { record in
                                    historyCard(record)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.skyTop, AppTheme.skyBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text(l10n.localized(
                zh: "还没有拍照判胜负记录",
                en: "No Photo Judge History Yet",
                ja: "写真判定の履歴はまだありません",
                ko: "사진 판정 기록이 아직 없습니다",
                zhHant: "還沒有拍照判勝負記錄"
            ))
            .font(AppFont.rounded(size: 22, weight: .black))
            .foregroundColor(AppTheme.inkPrimary)

            Text(l10n.localized(
                zh: "每次拍照识别并判胜负后会自动保存，最多可保留最近 \(PhotoJudgeRecord.maxStoredCount) 条记录。",
                en: "Every scan is saved automatically here, keeping up to the latest \(PhotoJudgeRecord.maxStoredCount) records.",
                ja: "写真で勝敗判定すると自動保存され、最新 \(PhotoJudgeRecord.maxStoredCount) 件まで閲覧できます。",
                ko: "사진으로 승패를 판정하면 자동 저장되며 최근 \(PhotoJudgeRecord.maxStoredCount)개까지 보관됩니다.",
                zhHant: "每次拍照識別並判勝負後會自動儲存，最多可保留最近 \(PhotoJudgeRecord.maxStoredCount) 條記錄。"
            ))
            .font(AppFont.rounded(size: 14, weight: .bold))
            .foregroundColor(AppTheme.inkSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)

            Button {
                SoundAndHapticsManager.shared.playUITap()
                onStartNewPhoto()
            } label: {
                Label(
                    l10n.localized(
                        zh: "去拍照判胜负",
                        en: "Take a Photo",
                        ja: "撮影して判定する",
                        ko: "사진 촬영하러 가기",
                        zhHant: "去拍照判勝負"
                    ),
                    systemImage: "camera.fill"
                )
                .font(AppFont.rounded(size: 16, weight: .black))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(glossyWhiteCard)
    }

    private func dayHeader(_ section: DaySection) -> some View {
        HStack(spacing: 8) {
            Text(dayTitle(for: section.dayStart))
                .font(AppFont.rounded(size: 14, weight: .black))
                .foregroundColor(AppTheme.inkPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .shadow(color: AppTheme.skyBottom.opacity(0.12), radius: 4, y: 2)
                )
                .overlay(Capsule().strokeBorder(.white, lineWidth: 2))

            Text("\(section.records.count)")
                .font(AppFont.rounded(size: 12, weight: .black))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(AppTheme.skyBottom))

            Spacer()
        }
    }

    private func historyCard(_ record: PhotoJudgeRecord) -> some View {
        let isBlackWin = record.winner == .black
        let verdictPalette: GlossyPalette = isBlackWin ? .sky : .sun
        let blackArea = record.scoringRule.isAreaScoring ? (record.blackStones + record.blackTerritory) : record.blackTerritory
        let whiteArea = record.scoringRule.isAreaScoring ? (record.whiteStones + record.whiteTerritory) : record.whiteTerritory
        let unit: String = {
            if record.scoringRule == .aga {
                return l10n.localized(zh: "点", en: "pts", ja: "点", ko: "점", zhHant: "點")
            }
            if record.scoringRule == .chinese {
                return l10n.localized(zh: "子", en: "pts", ja: "子", ko: "점", zhHant: "子")
            }
            return l10n.localized(zh: "目", en: "pts", ja: "目", ko: "집", zhHant: "目")
        }()

        return Button {
            SoundAndHapticsManager.shared.playUITap()
            onSelectRecord(record)
        } label: {
            HStack(alignment: .center, spacing: 18) {
                recordThumbnail(record)

                VStack(alignment: .leading, spacing: 10) {
                    // Row 1: Primary Headline — Capture / Judge Date & Time
                    Text(recordDateTimeHeadline(record.date))
                        .font(AppFont.rounded(size: 18, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    // Row 2: Winner Verdict
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isBlackWin ? Color(white: 0.14) : Color.white)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                        Text(verdictHeadline(for: record))
                            .font(AppFont.rounded(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [verdictPalette.top, verdictPalette.bottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    )

                    // Row 3: Black vs White Territory / Stones
                    HStack(spacing: 8) {
                        Text(l10n.localized(
                            zh: "黑占 \(blackArea)\(unit)",
                            en: "Black \(blackArea) \(unit)",
                            ja: "黒 \(blackArea)\(unit)",
                            ko: "흑 \(blackArea)\(unit)",
                            zhHant: "黑佔 \(blackArea)\(unit)"
                        ))
                        .font(AppFont.rounded(size: 14.5, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)

                        Text("vs")
                            .font(AppFont.rounded(size: 12.5, weight: .bold))
                            .foregroundColor(AppTheme.inkSecondary)

                        Text(l10n.localized(
                            zh: "白占 \(whiteArea)\(unit)",
                            en: "White \(whiteArea) \(unit)",
                            ja: "白 \(whiteArea)\(unit)",
                            ko: "백 \(whiteArea)\(unit)",
                            zhHant: "白佔 \(whiteArea)\(unit)"
                        ))
                        .font(AppFont.rounded(size: 14.5, weight: .black))
                        .foregroundColor(AppTheme.skyBottom)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                    // Row 4: Board Size & Scoring Rule Tags
                    HStack(spacing: 8) {
                        Text("\(record.boardSize)×\(record.boardSize)")
                            .font(AppFont.rounded(size: 12.5, weight: .black))
                            .foregroundColor(AppTheme.skyBottom)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppTheme.skyBottom.opacity(0.12)))
                            .fixedSize()

                        Text(ruleShortLabel(record.scoringRule))
                            .font(AppFont.rounded(size: 12.5, weight: .bold))
                            .foregroundColor(AppTheme.grapeBottom)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppTheme.grapeBottom.opacity(0.12)))
                            .fixedSize()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("PhotoJudgeHistoryRecordCard")
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white, Color(red: 0.96, green: 0.98, blue: 1.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: AppTheme.skyBottom.opacity(0.16), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white, lineWidth: 3)
        )
    }

    @ViewBuilder
    private func recordThumbnail(_ record: PhotoJudgeRecord) -> some View {
        PhotoJudgeAsyncThumbnail(record: record) {
            appState.loadPhotoJudgeImage(for: record)
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 2.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 5, y: 2)
    }

    // MARK: - Formatting Helpers

    private static let cachedDateFormatters: [String: DateFormatter] = {
        var map: [String: DateFormatter] = [:]
        let cjk = DateFormatter()
        cjk.dateFormat = "yyyy年M月d日 HH:mm"
        map["zh-Hans"] = cjk
        map["zh-Hant"] = cjk
        map["ja"] = cjk

        let ko = DateFormatter()
        ko.dateFormat = "yyyy년 M월 d일 HH:mm"
        map["ko"] = ko

        let en = DateFormatter()
        en.dateStyle = .medium
        en.timeStyle = .short
        map["en"] = en
        return map
    }()

    private func recordDateTimeHeadline(_ date: Date) -> String {
        let code = appState.settings.language.resolvedCode
        let formatter = Self.cachedDateFormatters[code] ?? Self.cachedDateFormatters["en"]!
        return formatter.string(from: date)
    }

    private func dayTitle(for dayStart: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(dayStart) {
            return l10n.localized(zh: "今天", en: "Today", ja: "今日", ko: "오늘", zhHant: "今天")
        }
        if calendar.isDateInYesterday(dayStart) {
            return l10n.localized(zh: "昨天", en: "Yesterday", ja: "昨日", ko: "어제", zhHant: "昨天")
        }
        return dayStart.formatted(date: .abbreviated, time: .omitted)
    }

    private func verdictHeadline(for record: PhotoJudgeRecord) -> String {
        let isBlackWin = record.winner == .black
        if record.scoringRule.isAreaScoring {
            let m = String(format: "%.1f", record.margin)
            if record.scoringRule == .aga {
                return isBlackWin
                    ? l10n.localized(zh: "黑胜 \(m) 点", en: "Black +\(m)", ja: "黒 +\(m)", ko: "흑 +\(m)", zhHant: "黑勝 \(m) 點")
                    : l10n.localized(zh: "白胜 \(m) 点", en: "White +\(m)", ja: "白 +\(m)", ko: "백 +\(m)", zhHant: "白勝 \(m) 點")
            }
            let zi = GameResult.formatChineseZi(record.chineseZiMargin)
            return isBlackWin
                ? l10n.localized(zh: "黑胜 \(zi)", en: "Black +\(m)", ja: "黒 +\(m)", ko: "흑 +\(m)", zhHant: "黑勝 \(zi)")
                : l10n.localized(zh: "白胜 \(zi)", en: "White +\(m)", ja: "白 +\(m)", ko: "백 +\(m)", zhHant: "白勝 \(zi)")
        } else {
            let m = String(format: "%.1f", record.margin)
            return isBlackWin
                ? l10n.localized(zh: "黑胜 \(m) 目", en: "Black +\(m)", ja: "黒 \(m)目", ko: "흑 \(m)집", zhHant: "黑勝 \(m) 目")
                : l10n.localized(zh: "白胜 \(m) 目", en: "White +\(m)", ja: "白 \(m)目", ko: "백 \(m)집", zhHant: "白勝 \(m) 目")
        }
    }

    private func ruleShortLabel(_ rule: ScoringRule) -> String {
        switch rule {
        case .chinese:
            return l10n.localized(zh: "中国数子", en: "Chinese", ja: "中国", ko: "중국식", zhHant: "中國數子")
        case .japanese:
            return l10n.localized(zh: "日韩数目", en: "JP/KR Territory", ja: "日韓数目", ko: "한·일 수목", zhHant: "日韓數目")
        case .aga:
            return l10n.localized(zh: "AGA面积", en: "AGA Area", ja: "AGA面積", ko: "AGA 면적", zhHant: "AGA面積")
        }
    }

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
}

/// Compact static mini-board thumbnail rendered from a saved grid when no warped photo is present.
private struct MiniGoBoardPreview: View {
    let boardSize: Int
    let grid: [Int]

    var body: some View {
        Canvas { ctx, size in
            let bg = Path(CGRect(origin: .zero, size: size))
            ctx.fill(
                bg,
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.95, green: 0.85, blue: 0.66), Color(red: 0.85, green: 0.70, blue: 0.45)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )

            let n = max(2, boardSize)
            let inset: CGFloat = 6
            let span = min(size.width, size.height) - inset * 2
            let step = span / CGFloat(n - 1)

            for i in 0..<n {
                let offset = inset + CGFloat(i) * step
                var h = Path()
                h.move(to: CGPoint(x: inset, y: offset))
                h.addLine(to: CGPoint(x: inset + span, y: offset))
                ctx.stroke(h, with: .color(Color.brown.opacity(0.45)), lineWidth: 0.6)

                var v = Path()
                v.move(to: CGPoint(x: offset, y: inset))
                v.addLine(to: CGPoint(x: offset, y: inset + span))
                ctx.stroke(v, with: .color(Color.brown.opacity(0.45)), lineWidth: 0.6)
            }

            let radius = max(1.2, step * 0.42)
            let limit = min(grid.count, n * n)
            for idx in 0..<limit {
                let stone = grid[idx]
                guard stone == 1 || stone == 2 else { continue }
                let row = idx / n
                let col = idx % n
                let cx = inset + CGFloat(col) * step
                let cy = inset + CGFloat(row) * step
                let rect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .color(stone == 1 ? Color(white: 0.12) : Color(white: 0.97))
                )
            }
        }
    }
}

/// Thread-safe in-memory thumbnail cache for Photo Judge history cards.
private final class PhotoJudgeThumbnailCache: @unchecked Sendable {
    static let shared = PhotoJudgeThumbnailCache()
    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 100
        return c
    }()

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func store(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

/// Asynchronously loads and downsamples a Photo Judge thumbnail off the main thread,
/// falling back to `MiniGoBoardPreview` while loading or when no photo exists.
private struct PhotoJudgeAsyncThumbnail: View {
    let record: PhotoJudgeRecord
    let loadFullImage: () -> UIImage?

    @State private var thumbnail: UIImage? = nil

    private var cacheKey: String? {
        record.imageFilename.map { "\($0)_240" }
    }

    var body: some View {
        Group {
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .accessibilityIgnoresInvertColors()
            } else {
                MiniGoBoardPreview(boardSize: record.boardSize, grid: record.grid)
            }
        }
        .task(id: record.imageFilename) {
            guard let key = cacheKey else {
                thumbnail = nil
                return
            }
            if let cached = PhotoJudgeThumbnailCache.shared.image(for: key) {
                thumbnail = cached
                return
            }
            let loader = loadFullImage
            let decoded: UIImage? = await Task.detached(priority: .utility) {
                guard let full = loader() else { return nil }
                let maxDim: CGFloat = 240
                let size = full.size
                guard max(size.width, size.height) > maxDim else { return full }
                let scale = maxDim / max(size.width, size.height)
                let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                return renderer.image { _ in
                    full.draw(in: CGRect(origin: .zero, size: targetSize))
                }
            }.value
            guard !Task.isCancelled, let decoded else { return }
            PhotoJudgeThumbnailCache.shared.store(decoded, for: key)
            thumbnail = decoded
        }
    }
}
