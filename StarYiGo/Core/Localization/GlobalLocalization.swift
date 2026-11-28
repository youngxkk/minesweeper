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
            return l10n.localized(zh: nameZh, en: nameEn, ja: "風車の草原・入門の浅瀬", ko: "바람개비 초원 · 입문 여울", zhHant: "風起棋丘 · 啟蒙淺灘")
        case "sea-2":
            return l10n.localized(zh: nameZh, en: nameEn, ja: "翡翠の森・竹林秘境", ko: "비취 숲 · 죽림 비경", zhHant: "翡翠森林 · 竹林秘境")
        case "sea-3":
            return l10n.localized(zh: nameZh, en: nameEn, ja: "双月の鏡湖・月橋の岸辺", ko: "쌍월 거울호수 · 달다리 호숫가", zhHant: "雙月鏡湖 · 月橋水岸")
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
        case "s1-reef":       return l10n.localized(zh: nameZh, en: nameEn, ja: "若芽の草地", ko: "새싹 풀밭", zhHant: "青芽草坪")
        case "s1-shell":      return l10n.localized(zh: nameZh, en: nameEn, ja: "石取りの小川", ko: "돌잡이 시냇가", zhHant: "抱吃溪岸")
        case "s1-lagoon":     return l10n.localized(zh: nameZh, en: nameEn, ja: "花咲く丘", ko: "꽃언덕", zhHant: "關門花坡")
        case "s1-harbor":     return l10n.localized(zh: nameZh, en: nameEn, ja: "両アタリの浅瀬", ko: "양단수 여울", zhHant: "雙吃淺灘")
        case "s1-lighthouse": return l10n.localized(zh: nameZh, en: nameEn, ja: "金星の風車", ko: "금별 풍차", zhHant: "金星風車")
        case "s2-wind":       return l10n.localized(zh: nameZh, en: nameEn, ja: "青竹シチョウ林", ko: "청죽 축 숲", zhHant: "青竹征子林")
        case "s2-canyon":     return l10n.localized(zh: nameZh, en: nameEn, ja: "紅葉ウッテガエシ谷", ko: "단풍 환격 계곡", zhHant: "楓葉倒撲谷")
        case "s2-lake":       return l10n.localized(zh: nameZh, en: nameEn, ja: "双月の霊泉湖", ko: "쌍월 영천호", zhHant: "雙月靈泉湖")
        case "s2-temple":     return l10n.localized(zh: nameZh, en: nameEn, ja: "大樹の水車小屋", ko: "거목 물레방아", zhHant: "巨樹風車坊")
        case "s2-summit":     return l10n.localized(zh: nameZh, en: nameEn, ja: "白鶴の古寺峰", ko: "백학 고사봉", zhHant: "白鶴古寺峰")
        case "s3-pine":       return l10n.localized(zh: nameZh, en: nameEn, ja: "松影の渡し場", ko: "솔그늘 나루", zhHant: "松影渡口")
        case "s3-forge":      return l10n.localized(zh: nameZh, en: nameEn, ja: "桜の湖岸", ko: "벚꽃 호숫가", zhHant: "落櫻湖岸")
        case "s3-river":      return l10n.localized(zh: nameZh, en: nameEn, ja: "双月の棋島", ko: "쌍월 바둑섬", zhHant: "雙月棋洲")
        case "s3-pagoda":     return l10n.localized(zh: nameZh, en: nameEn, ja: "さざ波の石道", ko: "물결 돌길", zhHant: "漣漪石徑")
        case "s3-sanctum":    return l10n.localized(zh: nameZh, en: nameEn, ja: "月橋の灯籠", ko: "달다리 등불", zhHant: "月橋燈岸")
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
