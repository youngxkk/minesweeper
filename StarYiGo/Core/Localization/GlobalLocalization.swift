//
//  GlobalLocalization.swift
//  StarYi Go — Native 5-Language Global Go Terminology (zh-Hans, zh-Hant, en, ja, ko)
//  Uses authentic regional Go vocabulary: 围棋 / 圍棋 / Go / 囲碁 / 바둑!
//

import Foundation

extension PuzzleCategory {
    func localizedTitle(_ l10n: L10n) -> String {
        switch self {
        case .capture:
            return l10n.localized(zh: "吃子启蒙", en: "Capture", ja: "石取り入門", ko: "따내기 기초", zhHant: "吃子啟蒙")
        case .tactics:
            return l10n.localized(zh: "经典手筋", en: "Tesuji", ja: "手筋・ワザ", ko: "맥점·수근", zhHant: "經典手筋")
        case .lifeAndDeath:
            return l10n.localized(zh: "死活天地", en: "Life & Death", ja: "詰碁・死活", ko: "사활", zhHant: "死活天地")
        case .capturingRace:
            return l10n.localized(zh: "对杀紧气", en: "Capturing Race", ja: "攻め合い", ko: "수상전", zhHant: "對殺緊氣")
        case .opening:
            return l10n.localized(zh: "布局大场", en: "Opening", ja: "布石・大場", ko: "포석·큰자리", zhHant: "布局大場")
        case .endgame:
            return l10n.localized(zh: "实战收官", en: "Endgame", ja: "ヨセ・終盤", ko: "끝내기", zhHant: "實戰收官")
        }
    }
}

extension CampaignSea {
    func localizedName(_ l10n: L10n) -> String {
        switch id {
        case "sea-1":
            return l10n.localized(zh: nameZh, en: nameEn, ja: "碧の海島・入門の浅瀬", ko: "푸른 해섬 · 입문 여울", zhHant: "碧藍海島 · 啟蒙淺灘")
        case "sea-2":
            return l10n.localized(zh: nameZh, en: nameEn, ja: "翡翠の森・竹林秘境", ko: "비취 숲 · 죽림 비경", zhHant: "翡翠森林 · 竹林秘境")
        case "sea-3":
            return l10n.localized(zh: nameZh, en: nameEn, ja: "黄金砂漠・遺跡の砂海", ko: "황금 사막 · 유적 사해", zhHant: "金色沙漠 · 古跡沙海")
        case "sea-4":
            return l10n.localized(zh: nameZh, en: nameEn, ja: "白銀雪山・氷峰道場", ko: "백은 설산 · 빙봉 도장", zhHant: "凜冬雪山 · 冰峰道場")
        case "sea-5":
            return l10n.localized(zh: nameZh, en: nameEn, ja: "紅蓮火山・龍炎の頂", ko: "용암 화산 · 용염 정상", zhHant: "熔岩火山 · 龍焰巔峰")
        default:
            return name(isChinese: l10n.language.isChinese)
        }
    }
}

extension CampaignIsland {
    func localizedName(_ l10n: L10n) -> String {
        switch id {
        case "s1-reef":       return l10n.localized(zh: nameZh, en: nameEn, ja: "わかば珊瑚礁", ko: "새싹 산호초", zhHant: "青芽珊瑚礁")
        case "s1-shell":      return l10n.localized(zh: nameZh, en: nameEn, ja: "貝殻のアタリ湾", ko: "조개 단수만", zhHant: "貝殼抱吃灣")
        case "s1-lagoon":     return l10n.localized(zh: nameZh, en: nameEn, ja: "ゲタ門の入江", ko: "장문 라군", zhHant: "關門瀉湖")
        case "s1-harbor":     return l10n.localized(zh: nameZh, en: nameEn, ja: "両アタリ風車港", ko: "양단수 풍차항", zhHant: "雙吃風車港")
        case "s1-lighthouse": return l10n.localized(zh: nameZh, en: nameEn, ja: "二眼の灯台島", ko: "두집 등대섬", zhHant: "雙瞳燈塔島")
        case "s2-wind":       return l10n.localized(zh: nameZh, en: nameEn, ja: "青竹シチョウ林", ko: "청죽 축 숲", zhHant: "青竹征子林")
        case "s2-canyon":     return l10n.localized(zh: nameZh, en: nameEn, ja: "紅葉ウッテガエシ谷", ko: "단풍 환격 계곡", zhHant: "楓葉倒撲谷")
        case "s2-lake":       return l10n.localized(zh: nameZh, en: nameEn, ja: "双月の霊泉湖", ko: "쌍월 영천호", zhHant: "雙月靈泉湖")
        case "s2-temple":     return l10n.localized(zh: nameZh, en: nameEn, ja: "大樹の水車小屋", ko: "거목 물레방아", zhHant: "巨樹風車坊")
        case "s2-summit":     return l10n.localized(zh: nameZh, en: nameEn, ja: "白鶴の古寺峰", ko: "백학 고사봉", zhHant: "白鶴古寺峰")
        case "s3-pine":       return l10n.localized(zh: nameZh, en: nameEn, ja: "オアシスの井戸", ko: "오아시스 우물", zhHant: "綠洲渡沙井")
        case "s3-forge":      return l10n.localized(zh: nameZh, en: nameEn, ja: "日時計の石碑陣", ko: "해시계 석비진", zhHant: "日晷石碑陣")
        case "s3-river":      return l10n.localized(zh: nameZh, en: nameEn, ja: "流砂の双子塔", ko: "유사 쌍둥이탑", zhHant: "流沙雙子塔")
        case "s3-pagoda":     return l10n.localized(zh: nameZh, en: nameEn, ja: "黄金のピラミッド", ko: "황금 피라미드", zhHant: "黃金金字塔")
        case "s3-sanctum":    return l10n.localized(zh: nameZh, en: nameEn, ja: "星砂の神殿頂", ko: "별모래 신전", zhHant: "星砂神殿頂")
        case "s4-mist":       return l10n.localized(zh: nameZh, en: nameEn, ja: "雪松の温泉村", ko: "설송 온천마을", zhHant: "雪松溫泉村")
        case "s4-flame":      return l10n.localized(zh: nameZh, en: nameEn, ja: "氷晶の吊り橋谷", ko: "빙정 출렁다리", zhHant: "寒冰雙橋谷")
        case "s4-azure":      return l10n.localized(zh: nameZh, en: nameEn, ja: "氷晶の五重塔", ko: "빙정 오층탑", zhHant: "冰晶五重塔")
        case "s4-citadel":    return l10n.localized(zh: nameZh, en: nameEn, ja: "オーロラ剣台城", ko: "오로라 검대성", zhHant: "極光劍台城")
        case "s4-zenith":     return l10n.localized(zh: nameZh, en: nameEn, ja: "霜龍の雪嶺殿", ko: "상룡 설령전", zhHant: "霜龍雪巔殿")
        case "s5-forge":      return l10n.localized(zh: nameZh, en: nameEn, ja: "黒曜石の溶鉱炉", ko: "흑요석 용광로", zhHant: "黑曜石熔爐")
        case "s5-bridge":     return l10n.localized(zh: nameZh, en: nameEn, ja: "烈焔の断魂橋", ko: "열염 단혼교", zhHant: "烈焰斷魂橋")
        case "s5-altar":      return l10n.localized(zh: nameZh, en: nameEn, ja: "赤龍の試練壇", ko: "적룡 시련단", zhHant: "赤龍試煉壇")
        case "s5-citadel":    return l10n.localized(zh: nameZh, en: nameEn, ja: "朱雀の焚天城", ko: "주작 분천성", zhHant: "朱雀焚天城")
        case "s5-caldera":    return l10n.localized(zh: nameZh, en: nameEn, ja: "天元カルデラ頂", ko: "천원 칼데라 정상", zhHant: "天元火山口")
        default:              return name(isChinese: l10n.language.isChinese)
        }
    }
}

extension MiniDrillKind {
    func localizedTitle(_ l10n: L10n) -> String {
        switch self {
        case .speedLiberties:
            return l10n.localized(zh: "闪电数气 · 找断点", en: "Speed Liberties & Cuts", ja: "早押し呼吸点・キリ探し", ko: "스피드 활로·끊음 찾기", zhHant: "閃電數氣 · 找斷點")
        case .ladderReading:
            return l10n.localized(zh: "征子盲算 · 成不成？", en: "Ladder Blind Reading", ja: "シチョウ暗算", ko: "축 암산 퀴즈", zhHant: "征子盲算 · 成不成？")
        case .countingQuiz:
            return l10n.localized(zh: "目数与形势判断", en: "Counting & Territory Quiz", ja: "形勢判断・地合い計算", ko: "형세판단·집 계산", zhHant: "目數與形勢判斷")
        case .openingPicker:
            return l10n.localized(zh: "布局选大场 A/B/C", en: "Opening Big-Point Picker", ja: "布石の大場クイズ", ko: "포석 큰자리 3지선다", zhHant: "布局選大場 A/B/C")
        case .blunderSpotter:
            return l10n.localized(zh: "棋谱捉虫 · 改恶手", en: "Blunder Spotter & Fix", ja: "悪手ハンター", ko: "악수 찾기·교정", zhHant: "棋譜捉蟲 · 改惡手")
        }
    }
}
