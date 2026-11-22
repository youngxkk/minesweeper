//
//  JosekiLibrary.swift
//  StarYi Go — Interactive Multi-Branch Joseki Tree Curriculum (P2)
//

import Foundation

struct JosekiCourse: Identifiable, Hashable, Sendable {
    let id: String
    let rankBadge: String
    let titleZh: String
    let titleEn: String
    let subtitleZh: String
    let subtitleEn: String
    let boardSize: Int
    let cropRegion: BoardCropRegion
    let playerColor: StoneColor
    /// Full multi-branch SGF tree with C[...] bilingual explanations and WRONG punishment lines.
    let sgfZh: String
    let sgfEn: String

    func title(_ l10n: L10n) -> String { l10n.bilingual(zh: titleZh, en: titleEn) }
    func subtitle(_ l10n: L10n) -> String { l10n.bilingual(zh: subtitleZh, en: subtitleEn) }
    func sgf(_ l10n: L10n) -> String { l10n.language.isChinese ? sgfZh : sgfEn }
}

enum JosekiLibrary {
    static let allCourses: [JosekiCourse] = [
        // 1. Star-Point 3-3 Invasion (Two main branches: Classic block vs Modern double-hane + Wrong mistake punishment)
        JosekiCourse(
            id: "jos-33-modern",
            rankBadge: "12K–1D",
            titleZh: "星位点三三定式（双分支）",
            titleEn: "Star-Point 3-3 Invasion (Multi-Branch)",
            subtitleZh: "现代 AI 与职业棋手出场率最高的招牌定式，含爬二路与立下两种变化！",
            subtitleEn: "The #1 modern AI Joseki with both classic crawl and modern hane variations!",
            boardSize: 19,
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 9, minCol: 9, maxCol: 18),
            playerColor: .black,
            sgfZh: "(;GM[1]FF[4]SZ[19]PL[B]AB[pd]AW[qc]C[白棋直接「点三三」抢角！黑棋该从哪边挡住？](;B[qd]C[正着！黑棋挡在宽阔一侧，准备取外势。];W[pc]C[白棋向三路长出，扩大角部眼位。];B[od]C[黑棋顺势长出筑墙！](;W[oc]C[分支 A（简明型）：白棋沿三路再爬一步。];B[nc]C[黑棋果断三路扳头封锁，外势铁厚！];W[ob]C[白棋二路退回活角。];B[rc]C[黑棋二路先手扳缩角地。];W[rb]C[白棋挡住两眼活角！黑白实地与外势两分（正解定式）。]C[CORRECT])(;W[pb]C[分支 B（直接二路立）：白棋抢先守角。];B[oc]C[黑棋三路虎口稳健补厚！];W[rc]C[白棋二路立活角，定式两分！]C[CORRECT]))(;B[pc]C[黑棋挡在另一侧也可以，但注意配合全局方向。];W[qd]C[白棋长出。];B[pe]C[黑棋顺势长出取外势。];W[qf]C[白棋小飞安定，同样是常见两分定式！]C[CORRECT])(;B[oc]C[WRONG]C[缓手警告！没有贴身挡住，白棋直接在角上和边上同时舒舒服服活棋，黑棋外势也漏风了。]))",
            sgfEn: "(;GM[1]FF[4]SZ[19]PL[B]AB[pd]AW[qc]C[White invades directly at the 3-3 point! How should Black block?](;B[qd]C[Great! Black blocks on the wide side to build outside thickness.];W[pc]C[White extends along the 3rd line for corner space.];B[od]C[Black extends smoothly to build an outside wall!](;W[oc]C[Branch A (Classic): White pushes once more on the 3rd line.];B[nc]C[Black hanes cleanly on the 3rd line to seal White in!];W[ob]C[White retreats on the 2nd line to secure corner life.];B[rc]C[Black hanes on the 2nd line to squeeze corner territory.];W[rb]C[White blocks and lives! Textbook balanced 3-3 Joseki.]C[CORRECT])(;W[pb]C[Branch B (Direct 2nd-line stand): White settles quickly in the corner.];B[oc]C[Black connects solidly with great thickness!];W[rc]C[White secures corner life — balanced Joseki!]C[CORRECT]))(;B[pc]C[Blocking the other side is also valid depending on the whole board.];W[qd]C[White extends downward.];B[pe]C[Black builds an outside wall facing the right.];W[qf]C[White settles lightly — balanced Joseki!]C[CORRECT])(;B[oc]C[WRONG]C[Too loose! Failing to block directly lets White live effortlessly without giving Black a strong wall.]))"
        ),

        // 2. Star-Point Knight's Move Approach (小飞挂定式)
        JosekiCourse(
            id: "jos-star-knight",
            rankBadge: "15K–5K",
            titleZh: "星位小飞挂定式",
            titleEn: "Star-Point Knight Approach",
            subtitleZh: "学会「小飞应」稳健守角与「一间低夹」积极反击两种下法！",
            subtitleEn: "Master both the calm Knight's defense and the sharp One-Space Low Pincer!",
            boardSize: 19,
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 9, minCol: 8, maxCol: 18),
            playerColor: .black,
            sgfZh: "(;GM[1]FF[4]SZ[19]PL[B]AB[pd]AW[nc]C[白棋对黑星位下出「小飞挂」，黑棋如何回应？](;B[qf]C[分支 A（小飞应）：最稳健大方！牢牢守住右上角与右边。];W[kc]C[白棋上方拆三建立安稳根据地，大局两分！]C[CORRECT])(;B[lc]C[分支 B（一间低夹）：积极反击，不让白棋轻松拆边！];W[qc]C[白棋立刻点三三转换！];B[qd]C[黑棋挡住角部外侧。];W[pc]C[白棋顺势爬出活角。];B[od]C[黑棋厚实长出，双方精彩定型！]C[CORRECT])(;B[qc]C[WRONG]C[过分委屈！角部太早缩在三三，白棋轻松拆边后黑棋发展空间被压缩。]))",
            sgfEn: "(;GM[1]FF[4]SZ[19]PL[B]AB[pd]AW[nc]C[White approaches your 4-4 Star Point with a Knight's Move. How do you answer?](;B[qf]C[Branch A (Knight's Defense): Calm, solid, and secures the corner & right side.];W[kc]C[White extends along the top to make a base — balanced Joseki!]C[CORRECT])(;B[lc]C[Branch B (Low Pincer): Active counterattack denying White an easy side base!];W[qc]C[White counters with a 3-3 invasion!];B[qd]C[Black blocks on the right.];W[pc]C[White extends to live in the corner.];B[od]C[Black builds an imposing outside wall — sharp modern Joseki!]C[CORRECT])(;B[qc]C[WRONG]C[Too passive! Hunkering down at 3-3 immediately lets White expand freely along the top.]))"
        ),

        // 3. Komoku (3-4) Knight Approach & Defense (小目小飞挂与托退定式)
        JosekiCourse(
            id: "jos-komoku-knight",
            rankBadge: "12K–2K",
            titleZh: "小目小飞挂 · 经典托退定式",
            titleEn: "Komoku (3-4) Attach & Extend Joseki",
            subtitleZh: "最经典的小目攻防：一间高挂 / 小飞挂后的托退定型！",
            subtitleEn: "Classic 3-4 corner joseki: calm knight's enclosure or solid attach-and-extend!",
            boardSize: 19,
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 9, minCol: 8, maxCol: 18),
            playerColor: .black,
            sgfZh: "(;GM[1]FF[4]SZ[19]PL[B]AB[qd]AW[oc]C[面对小目（3-4），白棋下出经典「小飞挂」，黑棋怎么应对？](;B[pe]C[分支 A（一间高跳 / 尖顶准备）：黑棋稳健保角并向中央出头。];W[kc]C[白棋上方拆边，双方步调轻快！]C[CORRECT])(;B[od]C[分支 B（托退定式）：黑棋直接贴身「托」，主动挑起定型！];W[nd]C[白棋扳起反击。];B[oe]C[黑棋稳稳退回，棋形厚实无比！];W[nc]C[白棋虎口补强。];B[qf]C[黑棋顺势守住右边，经典「托退定式」完成！]C[CORRECT])(;B[pc]C[WRONG]C[俗手！白棋一扳或一尖顶，黑棋撞厚白棋且角部不实。]))",
            sgfEn: "(;GM[1]FF[4]SZ[19]PL[B]AB[qd]AW[oc]C[White approaches your 3-4 Komoku corner with a Knight's Move. Choose your response!](;B[pe]C[Branch A (Solid Jump): Guards the corner while staying light toward the center.];W[kc]C[White settles along the top — peaceful balanced opening!]C[CORRECT])(;B[od]C[Branch B (Attach & Extend): Black attaches directly to settle shape immediately!];W[nd]C[White hanes on top.];B[oe]C[Black pulls back solidly with thick shape!];W[nc]C[White protects the cut.];B[qf]C[Black claims the right side — textbook Attach & Extend Joseki!]C[CORRECT])(;B[pc]C[WRONG]C[Heavy contact move that helps White strengthen on the top side unnecessarily.]))"
        ),

        // 4. Komoku One-Space High Approach (小目一间高挂简明定式)
        JosekiCourse(
            id: "jos-komoku-high",
            rankBadge: "10K–1D",
            titleZh: "小目一间高挂 · 简明托退",
            titleEn: "Komoku High Approach Joseki",
            subtitleZh: "四路高挂重外势，黑棋三路托进角地，简明好学又实用！",
            subtitleEn: "When White approaches high on the 4th line, slide underneath for solid corner cash!",
            boardSize: 19,
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 9, minCol: 8, maxCol: 18),
            playerColor: .black,
            sgfZh: "(;GM[1]FF[4]SZ[19]PL[B]AB[qd]AW[od]C[白棋对小目「一间高挂」，瞄准外势，黑棋最简明的应对是什么？](;B[oc]C[正着！黑棋三路托入，直接抢占角部实地！];W[nc]C[白棋扳住压迫。];B[pc]C[黑棋稳稳退回连片，角地扎实！];W[nd]C[白棋粘上成铁厚外势。];B[qf]C[黑棋拆回右边，简明两分定式完成！]C[CORRECT])(;B[qc]C[WRONG]C[太软弱啦！直接退守角部，白棋外势无损又抢得先手。]))",
            sgfEn: "(;GM[1]FF[4]SZ[19]PL[B]AB[qd]AW[od]C[White plays the High Approach on the 4th line against your 3-4 stone. What is the clean answer?](;B[oc]C[Spot on! Attach underneath on the 3rd line to claim solid corner territory!];W[nc]C[White hanes outside.];B[pc]C[Black pulls back cleanly to connect and take the corner!];W[nd]C[White connects into a thick outside wall.];B[qf]C[Black finishes with a calm right-side extension — balanced Joseki!]C[CORRECT])(;B[qc]C[WRONG]C[Too submissive! Backing off right away gives White free outside influence and sente.]))"
        ),

        // 5. Star-Point Double-Approach Defense (星位双挂应对)
        JosekiCourse(
            id: "jos-double-approach",
            rankBadge: "8K–2D",
            titleZh: "星位被双挂 · 稳健活角",
            titleEn: "Defending a Double-Approached Star Point",
            subtitleZh: "左右都被对手挂角夹攻？冷静点三三稳稳活角不慌乱！",
            subtitleEn: "Approached from BOTH sides? Drop calmly to the 3-3 point to live in the corner!",
            boardSize: 19,
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 9, minCol: 8, maxCol: 18),
            playerColor: .black,
            sgfZh: "(;GM[1]FF[4]SZ[19]PL[B]AB[pd]AW[nc][qf]C[黑星位被白棋左右「双挂」！此时千万别乱冲，黑棋该怎么稳稳活角？](;B[qc]C[绝佳冷静的一手！直接守在「三三」，角部稳稳做活！];W[nd]C[白棋加固上方外势。];B[pf]C[黑棋反击或脱先都十分灵活，完美化解双挂！]C[CORRECT])(;B[oc]C[WRONG]C[急躁了！先去碰一边容易被白棋左右联动反击，直接三三守角最稳妥。]))",
            sgfEn: "(;GM[1]FF[4]SZ[19]PL[B]AB[pd]AW[nc][qf]C[Your Star Point is double-approached from both sides! Stay calm — how do you settle safely?](;B[qc]C[Brilliant calm move! Drop straight to the 3-3 point to live solidly in the corner!];W[nd]C[White reinforces the top side.];B[pf]C[Black stays completely flexible and alive — textbook defense!]C[CORRECT])(;B[oc]C[WRONG]C[Too impatient! Pushing out lets White coordinate both sides against you. Claim 3-3 first!]))"
        )
    ]

    static func course(withId id: String) -> JosekiCourse? {
        allCourses.first { $0.id == id }
    }
}
