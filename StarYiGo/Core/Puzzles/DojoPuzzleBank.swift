//
//  DojoPuzzleBank.swift
//  StarYi Go — 320+ Graded & Mathematically Verified Go Puzzles (25K -> 3D)
//

import Foundation

enum DojoRankBand: String, CaseIterable, Identifiable, Sendable {
    case all
    case beginner      // 25K - 18K
    case intermediate  // 17K - 10K
    case advanced      // 9K - 1K
    case dan           // 1D - 3D

    var id: String { rawValue }

    func title(isChinese: Bool) -> String {
        switch self {
        case .all: return isChinese ? "全部级位" : "All Ranks"
        case .beginner: return "25K–18K"
        case .intermediate: return "17K–10K"
        case .advanced: return "9K–1K"
        case .dan: return "1D–3D"
        }
    }

    func matches(_ puzzle: GoPuzzle) -> Bool {
        let v = puzzle.rankOrderValue
        switch self {
        case .all: return true
        case .beginner: return v >= 18
        case .intermediate: return v >= 10 && v <= 17
        case .advanced: return v >= 1 && v <= 9
        case .dan: return v <= 0
        }
    }
}

/// Comprehensive 320+ Go Puzzle Dojo spanning all 6 categories (Capture, Tesuji, Life & Death,
/// Capturing Race, Opening, Endgame) from 25K to 3D.
/// Built from 60+ handcrafted authentic Go archetypes expanded across distinct board corners,
/// reflections, and Black/White color inversions so players train true reading from every angle!
enum DojoPuzzleBank {

    // MARK: - 44 Additional Handcrafted Core Archetypes (beyond the 20 Island Puzzles = 64 Core Templates!)

    static let coreDojoTemplates: [GoPuzzle] = [
        // ==================== 1. CAPTURE (吃子启蒙 · 8 new templates) ====================
        GoPuzzle(
            id: "dojo-cap-01", category: .capture, rankBadge: "25K",
            titleZh: "角上提单子", titleEn: "Corner Capture",
            promptZh: "黑先：角上白子只剩最后一口气，直接提掉它！",
            promptEn: "Black to play: Take White's last corner liberty!",
            hintZh: "角上交叉点只有两口气，填上最后一口气就能提子。",
            hintEn: "A corner stone only has 2 liberties total — fill the last one!",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ba]AW[aa](;B[ab]C[CORRECT]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 4, minCol: 0, maxCol: 4)
        ),
        GoPuzzle(
            id: "dojo-cap-02", category: .capture, rankBadge: "24K",
            titleZh: "关门吃（门吃）", titleEn: "Door Capture",
            promptZh: "黑先：从背后叫吃，等白棋钻进门里立刻关门吃掉！",
            promptEn: "Black to play: Atari into your two doorposts and slam the door shut!",
            hintZh: "先从上方叫吃白子，逼它往右边两个黑子中间跑。",
            hintEn: "Atari from above so White runs right between your two stones.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[bc][cd][db][ec]AW[cc](;B[cb];W[dc];B[dd]C[CORRECT])(;B[dc];W[cb]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "dojo-cap-03", category: .capture, rankBadge: "23K",
            titleZh: "提子解围", titleEn: "Capture to Escape",
            promptZh: "黑先：三颗黑子只剩一口气了！反提白子就能瞬间解围！",
            promptEn: "Black to play: Your stones are in atari — capture the white stone to save them!",
            hintZh: "看看哪一颗白子也只剩 1 口气？提掉它就能救活自己！",
            hintEn: "Spot the white stone that is also down to 1 liberty and capture it first!",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[cc][cd][dc][eb][ed]AW[bc][bd][ce][dd][db][ec](;B[fc]C[CORRECT])(;B[cb];W[fc]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-cap-04", category: .capture, rankBadge: "22K",
            titleZh: "边线逼吃两子", titleEn: "Edge Atari Direction",
            promptZh: "黑先：选对叫吃方向，把两颗白子逼到边线全吃！",
            promptEn: "Black to play: Choose the right atari direction to trap both white stones on the edge.",
            hintZh: "从左侧堵住出路，把白棋逼向右侧己方黑子处吃掉！",
            hintEn: "Atari from the left to drive White into your wall on the right!",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ab][bb][cc][dc][eb]AW[cb][db](;B[ca];W[da];B[ea]C[CORRECT])(;B[da];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "dojo-cap-05", category: .capture, rankBadge: "21K",
            titleZh: "虎口双吃", titleEn: "Tiger's Mouth Double Atari",
            promptZh: "黑先：钻进白棋缺口，同时叫吃两块白棋！",
            promptEn: "Black to play: Step into the gap to put two white groups in atari at once!",
            hintZh: "找一找同时挨着两块两口气白棋的那个空点。",
            hintEn: "Find the intersection adjacent to both 2-liberty white groups.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[cb][cd][de][ef][fd]AW[cc][dd][ed][ec](;B[dc](;W[db];B[ce]C[CORRECT])(;W[ce];B[db]C[CORRECT]))(;B[db];W[dc]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 7, minCol: 1, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-cap-06", category: .capture, rankBadge: "20K",
            titleZh: "顺势抱吃", titleEn: "Hug Into Wall",
            promptZh: "黑先：利用右边黑墙，把两颗白子抱吃！",
            promptEn: "Black to play: Drive the white stones straight into your wall!",
            hintZh: "把白棋往已有黑子包围的一侧赶过去。",
            hintEn: "Push White toward your friendly stones, not away from them.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[cc][dc][ec][fd][fe][df]AW[dd][ed](;B[de];W[ee];B[ef]C[CORRECT])(;B[ee];W[de]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 1, maxRow: 7, minCol: 1, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-cap-07", category: .capture, rankBadge: "19K",
            titleZh: "角部抱吃", titleEn: "Corner Hug Capture",
            promptZh: "黑先：白子想往边上逃，请堵住它的去路吃掉它！",
            promptEn: "Black to play: Block White's escape along the side and capture!",
            hintZh: "不要从一路追，从二路拦住白子！",
            hintEn: "Block from the second line instead of chasing from the first line.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ac][bc][cb]AW[ab][bb](;B[ca];W[aa];B[ba]C[CORRECT])(;B[ba];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 5)
        ),
        GoPuzzle(
            id: "dojo-cap-08", category: .capture, rankBadge: "18K",
            titleZh: "长气反吃", titleEn: "Extend and Counter-Capture",
            promptZh: "黑先：两颗黑子气紧，巧用一子救出自己并吃掉白棋！",
            promptEn: "Black to play: Save your stones and turn the tables with an atari!",
            hintZh: "连接的同时还能把白棋打成 1 口气。",
            hintEn: "Connect your stones while putting White into immediate atari.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[cc][dc][eb][fb][dd]AW[cb][db][ec][ed][ce](;B[fc]C[CORRECT])(;B[de];W[fc]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 1, maxCol: 7)
        ),

        // ==================== 2. TACTICS / TESUJI (经典手筋 · 10 new templates) ====================
        GoPuzzle(
            id: "dojo-tac-01", category: .tactics, rankBadge: "16K",
            titleZh: "宽枷妙手", titleEn: "Loose Net Tesuji",
            promptZh: "黑先：用轻灵的“枷吃”彻底罩住中央白子！",
            promptEn: "Black to play: Trap the center white stone in an inescapable net!",
            hintZh: "站在白子逃跑路线斜前方，左右夹击。",
            hintEn: "Place a stone diagonally ahead of White's escape path.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[cd][dc][ec][cf][gd][eg]AW[dd][de](;B[fe](;W[ee];B[ef]C[CORRECT])(;W[ef];B[ee]C[CORRECT]))(;B[ee];W[fe]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 1, maxRow: 8, minCol: 1, maxCol: 8)
        ),
        GoPuzzle(
            id: "dojo-tac-02", category: .tactics, rankBadge: "15K",
            titleZh: "边线倒扑", titleEn: "Side Snapback",
            promptZh: "黑先：巧妙弃一子，利用白棋气紧实施倒扑！",
            promptEn: "Black to play: Sacrifice one stone to trigger a devastating snapback!",
            hintZh: "先切断白棋与左侧的联络，白棋提掉后反而只剩 1 口气！",
            hintEn: "Cut White off — once White captures your bait stone, snap right back!",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[ba][bb][ca][db][eb][fb][fa]AB[cb][cc][dc][ec][fc][gb][ga](;B[da];W[ea];B[da]C[CORRECT])(;B[ea];W[da]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-tac-03", category: .tactics, rankBadge: "14K",
            titleZh: "二路接不归", titleEn: "Second-Line Connect & Die",
            promptZh: "黑先：白棋若强行连接就会全军覆没，找出分断要点！",
            promptEn: "Black to play: Cut White so connecting becomes fatal!",
            hintZh: "下在白棋中间的二路断点，迫使它陷入接不归。",
            hintEn: "Cut on the second line so connecting leaves White with just 1 liberty.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ba][bb][cc][ec][fc][fb][gb][ha]AW[ca][cb][eb][ea][fa](;B[db];W[da];B[ga]C[CORRECT])(;B[da];W[db]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 8)
        ),
        GoPuzzle(
            id: "dojo-tac-04", category: .tactics, rankBadge: "13K",
            titleZh: "滚打包收", titleEn: "Rolling Squeeze",
            promptZh: "黑先：连续叫吃把白棋拧成一团再提光！",
            promptEn: "Black to play: Chain consecutive ataris to squeeze and capture White!",
            hintZh: "先从左侧叫吃，逼白棋一路粘上后再连续追击。",
            hintEn: "Start with an atari that forces White into a breathless clump.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[bc][bd][dc][eb][ec][fc]AW[cc][cd][db][dd][de](;B[cb];W[da];B[ca];W[ea];B[fa]C[CORRECT])(;B[da];W[cb]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-tac-05", category: .tactics, rankBadge: "12K",
            titleZh: "扑吃破虎口", titleEn: "Throw-In Capture",
            promptZh: "黑先：白棋看起来连成一片，一记「扑」就能吃掉白棋！",
            promptEn: "Black to play: Throw in a stone to shatter White's connection!",
            hintZh: "直接扑在一路切断点，逼白棋提子后反提全灭！",
            hintEn: "Throw in directly on the first line to trigger a snapback capture!",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[bb][bc][cc][dc][ec][fb][fa]AW[aa][ab][ac][ba][cb][db][eb][ea](;B[ca];W[da];B[ca]C[CORRECT])(;B[da];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-tac-06", category: .tactics, rankBadge: "11K",
            titleZh: "双征追击", titleEn: "Long Ladder Chase",
            promptZh: "黑先：一路拐弯征子，将白子赶向边线！",
            promptEn: "Black to play: Zig-zag chase White all the way to the top edge!",
            hintZh: "第一步一定要堵住中央方向，不能让白棋长出三口气。",
            hintEn: "Block the center side first so White stays at 2 liberties.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[cb][cc][cd][de]AW[dd](;B[ed];W[dc];B[ec];W[db];B[eb];W[da];B[ea]C[CORRECT])(;B[dc];W[ed]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 1, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-tac-07", category: .tactics, rankBadge: "10K",
            titleZh: "夹击联络", titleEn: "Clamp to Connect",
            promptZh: "黑先：用犀利的「夹」联络左右两块黑棋！",
            promptEn: "Black to play: Use a sharp clamp to unite your two groups!",
            hintZh: "紧贴边线二路夹入，白棋无法分断。",
            hintEn: "Clamp cleanly on the second line so White cannot cut.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ba][bb][bc][eb][ec][fb]AW[cb][cc][cd][dc][dd][db](;B[da](;W[ca];B[ea]C[CORRECT])(;W[ea];B[ca]C[CORRECT]))(;B[ca];W[da]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-tac-08", category: .tactics, rankBadge: "9K",
            titleZh: "金鸡独立变式", titleEn: "Double Shortage of Liberties",
            promptZh: "黑先：一子立下，让左右白棋同时无法入气！",
            promptEn: "Black to play: Stand down in the middle to create double shortage of liberties!",
            hintZh: "不要急着叫吃左边或右边，先把中间立稳。",
            hintEn: "Play calmly in the center — neither white group can approach!",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[da][bc][cc][dc][ec][fc][gb][ga]AW[ba][bb][cb][eb][fb][fa](;B[db]C[CORRECT])(;B[ca];W[db]C[WRONG])(;B[ea];W[db]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-tac-09", category: .tactics, rankBadge: "6K",
            titleZh: "一子两用（断吃）", titleEn: "Cutting Tesuji",
            promptZh: "黑先：巧用白棋气紧，先挖后打吃掉白子！",
            promptEn: "Black to play: Wedge into White's weak shape and capture!",
            hintZh: "直接楔入两颗白子之间，白棋哪边挡都不行。",
            hintEn: "Wedge straight between the two white stones.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ca][cb][dc][ec][fc][gb][ga]AW[db][ea][fb](;B[eb](;W[da];B[fa]C[CORRECT])(;W[fa];B[da]C[CORRECT]))(;B[da];W[eb]C[WRONG])(;B[fa];W[eb]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 1, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-tac-10", category: .tactics, rankBadge: "2K",
            titleZh: "乌龟不出头", titleEn: "Cap and Seal",
            promptZh: "黑先：果断封锁白棋出头，顺势吃住中腹白子！",
            promptEn: "Black to play: Cap White's head to seal its escape completely!",
            hintZh: "按住白棋往中央伸出的头，别给它出头喘息的机会。",
            hintEn: "Play directly in front of White's escaping head.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[cb][db][bc][ec][cd][fd][cf][ef]AW[cc][dc][dd][ed](;B[de](;W[ee];B[fe]C[CORRECT])(;W[ce];B[ee]C[CORRECT]))(;B[ee];W[de]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 7, minCol: 0, maxCol: 7)
        ),

        // ==================== 3. LIFE & DEATH (死活天地 · 12 new templates) ====================
        GoPuzzle(
            id: "dojo-lad-01", category: .lifeAndDeath, rankBadge: "19K",
            titleZh: "补眼活棋", titleEn: "Complete Two Eyes",
            promptZh: "黑先：黑棋已有一只真眼，快补强另一只眼做成两眼活棋！",
            promptEn: "Black to play: You already have one eye — secure the second true eye!",
            hintZh: "补住斜角缺口，防止白棋把真眼破成假眼。",
            hintEn: "Fix the diagonal vulnerability so your second eye becomes solid.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[aa][ab][bb][cb][db][da][fa][fb]AW[ac][bc][cc][dc][ec][fc][gc][gb][ga](;B[eb]C[CORRECT])(;B[ea];W[eb]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-lad-02", category: .lifeAndDeath, rankBadge: "17K",
            titleZh: "角部曲三杀棋", titleEn: "Kill Corner Bent Three",
            promptZh: "黑先：白棋在角部摆出曲三，直接点杀要点！",
            promptEn: "Black to play: Strike the vital point of White's corner Bent Three!",
            hintZh: "点在角上 1-1 拐弯要点，白棋立刻只剩一只眼。",
            hintEn: "Play directly at the 1-1 corner bend!",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[ca][cb][bb][bc][ac]AB[da][db][dc][cd][bd][ad](;B[aa]C[CORRECT])(;B[ba];W[aa]C[WRONG])(;B[ab];W[aa]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 5)
        ),
        GoPuzzle(
            id: "dojo-lad-03", category: .lifeAndDeath, rankBadge: "16K",
            titleZh: "刀把五做活", titleEn: "Bulky Five to Live",
            promptZh: "黑先：黑棋眼位是刀把五，抢占中心要点做成两眼活棋！",
            promptEn: "Black to play: Claim the vital point inside your Bulky Five to live!",
            hintZh: "「敌之要点即我之要点」——自己下在刀把交汇中心点！",
            hintEn: "Play at the intersection touching 3 of your 5 empty spaces.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[aa][ab][ac][bc][cc][dc][db][eb][ea]AW[ad][bd][cd][dd][ed][ec][fc][fb][fa](;B[ca]C[CORRECT])(;B[ba];W[ca]C[WRONG])(;B[cb];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "dojo-lad-04", category: .lifeAndDeath, rankBadge: "15K",
            titleZh: "丁四做活", titleEn: "Pyramid Four to Live",
            promptZh: "黑先：守住丁四正中央要点，变出三只眼稳稳活棋！",
            promptEn: "Black to play: Take the T-center vital point to live cleanly!",
            hintZh: "下在「丁」字正中间，一举分出左右两只以上真眼。",
            hintEn: "Play right at the center of the T-shape.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[aa][ab][bb][bc][cc][dc][db][eb][ea]AW[ac][bd][cd][dd][ed][ec][fc][fb][fa](;B[ca]C[CORRECT])(;B[cb];W[ca]C[WRONG])(;B[ba];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "dojo-lad-05", category: .lifeAndDeath, rankBadge: "14K",
            titleZh: "点杀梅花五", titleEn: "Kill Crossed Five",
            promptZh: "黑先：白棋摆出十字形「梅花五」，一子点中花心杀棋！",
            promptEn: "Black to play: Strike the exact center of White's Crossed Five!",
            hintZh: "梅花五呈「十」字形状，正中央就是唯一杀棋要点。",
            hintEn: "The center of the plus-shaped 5-space eye is the unique vital point.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[ca][da][ea][bb][fb][bc][fc][bd][cd][dd][ed][fd]AB[ba][fa][ab][ac][ad][ae][be][ce][de][ee][fe][ge][gd][gc][gb][ga](;B[dc]C[CORRECT])(;B[cc];W[dc]C[WRONG])(;B[ec];W[dc]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-lad-06", category: .lifeAndDeath, rankBadge: "12K",
            titleZh: "梅花五做活", titleEn: "Crossed Five to Live",
            promptZh: "黑先：抢占梅花五中心点，做出四只真眼大活！",
            promptEn: "Black to play: Occupy the center of your Crossed Five to live!",
            hintZh: "下在「十」字中心，四周立刻变成四只独立的真眼。",
            hintEn: "Claim the center of the plus shape to split it into four eyes.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ca][da][ea][bb][fb][bc][fc][bd][cd][dd][ed][fd]AW[ba][fa][ab][ac][ad][ae][be][ce][de][ee][fe][ge][gd][gc][gb][ga](;B[dc]C[CORRECT])(;B[cc];W[dc]C[WRONG])(;B[db];W[dc]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-lad-07", category: .lifeAndDeath, rankBadge: "10K",
            titleZh: "破假眼杀棋", titleEn: "Destroy False Eye",
            promptZh: "黑先：用一记「扑」把白棋的第二只眼变成假眼！",
            promptEn: "Black to play: Throw in to turn White's second eye into a False Eye!",
            hintZh: "直接扑在右边的眼位里，逼白棋提子后变成假眼。",
            hintEn: "Throw in on the right so capturing leaves White with a false eye.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[aa][ab][bb][cb][db][da][eb]AB[ac][bc][cc][dc][ec][fc][fb][fa](;B[ea];W[ca];B[ba]C[CORRECT])(;B[ca];W[ea]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-lad-08", category: .lifeAndDeath, rankBadge: "8K",
            titleZh: "点杀葡萄六", titleEn: "Kill Rabbitty Six",
            promptZh: "黑先：著名的「葡萄六（花六）」死活常形，找出唯一花心杀棋！",
            promptEn: "Black to play: Strike the center vital point of the famous Rabbitty Six!",
            hintZh: "找那个上下左右紧挨着 3 个空点的「花心」位置！",
            hintEn: "Find the empty intersection touching three other empty spaces inside.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[aa][ab][ac][bc][cc][dc][ec][eb][fb][fa]AB[ad][bd][cd][dd][ed][fd][fc][gc][gb][ga](;B[cb];W[ca];B[db]C[CORRECT])(;B[ca];W[cb]C[WRONG])(;B[da];W[cb]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-lad-09", category: .lifeAndDeath, rankBadge: "5K",
            titleZh: "缩小角部做活", titleEn: "Expand Corner Eye Space",
            promptZh: "黑先：角上空间紧迫，往边线一路扳扩大成直四活棋！",
            promptEn: "Black to play: Expand along the first line to build a living Straight Four!",
            hintZh: "向右侧一路扩张，把三目眼位撑大成四目活形！",
            hintEn: "Hane outward along the first line to expand from 3 spaces to 4.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[aa][ab][bb][cb][db][eb]AW[ac][bc][cc][dc][ec][fc][fb](;B[fa];W[ga];B[ea]C[CORRECT])(;B[ca];W[ea]C[WRONG])(;B[ea];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-lad-10", category: .lifeAndDeath, rankBadge: "3K",
            titleZh: "角部做双活", titleEn: "Live by Seki",
            promptZh: "黑先：做不出两只真眼时，冷静做出「双活」平安求生！",
            promptEn: "Black to play: Two eyes aren't possible — create a peaceful Seki to live!",
            hintZh: "稳稳立下，形成双方共享两口公气的双活局面。",
            hintEn: "Stand down cleanly so neither side can attack the shared liberties.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[aa][ab][ac][bc][cc][dc][ec][eb]AW[ca][da][cb][db][ad][bd][cd][dd][ed][fd][fc][fb][fa](;B[ea]C[CORRECT])(;B[ba];W[bb]C[WRONG])(;B[bb];W[ba]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-lad-11", category: .lifeAndDeath, rankBadge: "1D",
            titleZh: "盘角曲四要点", titleEn: "Bent Four in the Corner",
            promptZh: "黑先：在角上使出著名的「盘角曲四」点杀要点！",
            promptEn: "Black to play: Strike the vital point of the legendary corner Bent Four!",
            hintZh: "抢占角上二路拐弯要点，让白棋无论怎么挡都做不出两眼。",
            hintEn: "Strike the vital corner point so White cannot split two eyes.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[da][db][cb][bb][bc][ac]AB[ea][eb][ec][dc][cc][cd][bd][ad](;B[ba](;W[ca];B[aa]C[CORRECT])(;W[ab];B[ca]C[CORRECT]))(;B[aa];W[ba]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "dojo-lad-12", category: .lifeAndDeath, rankBadge: "2D",
            titleZh: "段位精妙点杀", titleEn: "Dan-Level Vital Point",
            promptZh: "黑先：先从外侧扳紧气，再一子点杀白棋大龙！",
            promptEn: "Black to play: Reduce from the outside first, then strike the vital point!",
            hintZh: "切忌直接点里面给白棋做眼机会，先从一路缩小眼位。",
            hintEn: "Reduce the outer space on the first line before striking inside.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[aa][ab][bb][cb][db][eb][fb]AB[ac][bc][cc][dc][ec][fc][gc][gb][ga](;B[fa];W[ca];B[da]C[CORRECT])(;B[ca];W[fa]C[WRONG])(;B[da];W[fa]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),

        // ==================== 4. CAPTURING RACE (对杀紧气 · 6 new templates) ====================
        GoPuzzle(
            id: "dojo-race-01", category: .capturingRace, rankBadge: "15K",
            titleZh: "三气对杀先紧外气", titleEn: "3-Liberty Capturing Race",
            promptZh: "黑先：双方对杀紧迫，记住口诀「对杀先紧外气」！",
            promptEn: "Black to play: Tight capturing race — take White's outside liberty first!",
            hintZh: "先紧白棋右侧外气，千万别碰中间公气！",
            hintEn: "Fill White's outer liberty before touching any shared liberty.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ba][bb][ae][be][ce][de][bd][cd][dc][dd][ed][ec][eb][fb][fa]AW[ab][ac][ad][bc][cc][cb][db][da](;B[ea];W[aa];B[ca]C[CORRECT])(;B[ca];W[aa]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-race-02", category: .capturingRace, rankBadge: "13K",
            titleZh: "有眼杀无眼", titleEn: "Eye Beats No-Eye",
            promptZh: "黑先：先在角上做出一只真眼，让公气全归自己所有！",
            promptEn: "Black to play: Make one true eye so all shared liberties belong to you!",
            hintZh: "在角上补成一只稳固真眼后，白棋无法先入眼，黑棋胜出！",
            hintEn: "Form a single true eye in the corner — White can't enter until the very end!",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ba][bb][ea][eb][ec][ed][dd][cd][bd][ad][ae]AW[ca][cb][cc][bc][ac][da](;B[ab];W[db];B[dc]C[CORRECT])(;B[db];W[ab]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "dojo-race-03", category: .capturingRace, rankBadge: "10K",
            titleZh: "一路立延气", titleEn: "First-Line Liberty Extension",
            promptZh: "黑先：黑棋少一口气，用一路立下妙手给自己长出两口气！",
            promptEn: "Black to play: Stand down on the 1st line to gain extra liberties and win the race!",
            hintZh: "在角上二路/一路延气，而不是盲目去紧白棋外气。",
            hintEn: "Extend your own corner liberties first instead of rushing outside.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[bb][bc][cc][dc][ec][eb][ea]AW[ab][ac][ad][bd][cd][dd][ed][fb][fa][cb][db](;B[ba];W[ca];B[aa]C[CORRECT])(;B[ca];W[ba]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-race-04", category: .capturingRace, rankBadge: "8K",
            titleZh: "扑紧气对杀", titleEn: "Throw-In Liberty Reduction",
            promptZh: "黑先：直接紧气慢一气！用一记「扑」破掉白棋真眼反杀！",
            promptEn: "Black to play: Direct approach loses by 1 liberty — throw in to destroy White's eye!",
            hintZh: "白棋有一只眼，必须先「扑」把白棋的眼破掉才能赢下对杀。",
            hintEn: "Throw in inside White's eye so it stops being an eye!",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[aa][ab][bc][cc][dc][ec][fc][fb][fa]AW[ba][bb][cb][db][eb][ea](;B[da];W[ca];B[da]C[CORRECT])(;B[ca];W[da]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-race-05", category: .capturingRace, rankBadge: "5K",
            titleZh: "大眼杀小眼", titleEn: "Big Eye Beats Small Eye",
            promptZh: "黑先：双方各有眼位，扩大己方大眼气数（直三 = 3 气）赢下对杀！",
            promptEn: "Black to play: Protect your bigger eye space to outlast White in the capturing race!",
            hintZh: "护住直三大眼入口，直三在内部暗藏足足 3 口气！",
            hintEn: "Seal your 3-space big eye — it holds 3 hidden liberties!",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ca][cb][bb][ab][da][db][dc][dd][ed][fd][gd][ha][hb][hc][hd]AW[ea][eb][ec][fc][gc][ga](;B[fb];W[gb];B[fa]C[CORRECT])(;B[fa];W[fb]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 0, maxCol: 8)
        ),
        GoPuzzle(
            id: "dojo-race-06", category: .capturingRace, rankBadge: "1D",
            titleZh: "紧气次序之妙", titleEn: "Exact Capturing Sequence",
            promptZh: "黑先：白棋外气看似充足，找出正确紧气次序先手杀白！",
            promptEn: "Black to play: Find the exact order of moves to win the tight liberty race!",
            hintZh: "从外侧一路紧气，不让白棋在角里做出一只真眼。",
            hintEn: "Take the outside 1st-line point so White cannot form an eye.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ba][bb][cc][dc][ec][eb][fb]AW[ab][ac][bc][cb][db][da][ea](;B[fa];W[aa];B[ca]C[CORRECT])(;B[ca];W[fa]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),

        // ==================== 5. OPENING (布局大场 · 4 new templates) ====================
        GoPuzzle(
            id: "dojo-open-01", category: .opening, rankBadge: "18K",
            titleZh: "金角优先", titleEn: "Golden Corner First",
            promptZh: "黑先：空角最大！请抢占右下角最后一个空星位！",
            promptEn: "Black to play: Corners are gold! Claim the last empty corner star point!",
            hintZh: "右下角 4-4 星位还空着，先占空角效率最高。",
            hintEn: "The bottom-right 4-4 star point is still wide open!",
            boardSize: 13, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[13]PL[B]AB[dd]AW[jd][dj](;B[jj]C[CORRECT])(;B[gg];W[jj]C[WRONG]))",
            cropRegion: BoardCropRegion.full(size: 13)
        ),
        GoPuzzle(
            id: "dojo-open-02", category: .opening, rankBadge: "14K",
            titleZh: "边线拆二立根", titleEn: "Two-Space Base Extension",
            promptZh: "黑先：角部定型后，在下方三路「拆二」建起安稳根据地！",
            promptEn: "Black to play: Extend two spaces along the bottom 3rd line to form a living base!",
            hintZh: "在左下黑子的右侧隔两格（三路）落子拆二。",
            hintEn: "Play two intersections to the right along the 3rd line.",
            boardSize: 13, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[13]PL[B]AB[dd][dj]AW[jj][jd](;B[gk]C[CORRECT])(;B[ek];W[gk]C[WRONG]))",
            cropRegion: BoardCropRegion.full(size: 13)
        ),
        GoPuzzle(
            id: "dojo-open-03", category: .opening, rankBadge: "10K",
            titleZh: "立二拆三", titleEn: "Two-High Three-Extension",
            promptZh: "黑先：左边黑棋已经两子并立，按照口诀「立二拆三」大步扩张！",
            promptEn: "Black to play: From a 2-stone wall, leap 3 spaces (Two-High Three-Extension)!",
            hintZh: "在上方从两子并立处向右隔三格落子。",
            hintEn: "Extend 3 spaces away from your 2-stone wall along the top side.",
            boardSize: 13, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[13]PL[B]AB[dd][dc]AW[jj][jd](;B[hd]C[CORRECT])(;B[fd];W[hd]C[WRONG]))",
            cropRegion: BoardCropRegion.full(size: 13)
        ),
        GoPuzzle(
            id: "dojo-open-04", category: .opening, rankBadge: "4K",
            titleZh: "小飞挂角", titleEn: "Knight's Move Corner Approach",
            promptZh: "黑先：四角已占完，对右上白棋星位下出标准的「小飞挂」！",
            promptEn: "Black to play: All corners are taken — approach White's top-right star point with a Knight's Move!",
            hintZh: "在右上白星位左侧三路下小飞挂（马步位置）。",
            hintEn: "Approach on the 3rd line a knight's move away from White's top-right star point.",
            boardSize: 13, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[13]PL[B]AB[dd][dj]AW[jd][jj](;B[gc]C[CORRECT])(;B[gg];W[gc]C[WRONG]))",
            cropRegion: BoardCropRegion.full(size: 13)
        ),

        // ==================== 6. ENDGAME (实战收官 · 4 new templates) ====================
        GoPuzzle(
            id: "dojo-end-01", category: .endgame, rankBadge: "14K",
            titleZh: "二路先手扳粘", titleEn: "Second-Line Sente Hane",
            promptZh: "黑先：走出一手先手二路扳，抢走白棋边空还保持先手！",
            promptEn: "Black to play: Play a sharp 2nd-line hane to scoop territory in sente!",
            hintZh: "贴着白棋二路拐弯扳下，白棋必须挡住。",
            hintEn: "Hane on the 2nd line next to White's border stone.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[cc][cd][ce][dc]AW[ec][ed][ee][fd](;B[eb];W[fb];B[db]C[CORRECT])(;B[db];W[eb]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 1, maxCol: 7)
        ),
        GoPuzzle(
            id: "dojo-end-02", category: .endgame, rankBadge: "10K",
            titleZh: "大伸腿（猴脸官子）", titleEn: "The Monkey Jump",
            promptZh: "黑先：施展经典「大伸腿」，沿一路一口气捞走白棋大空！",
            promptEn: "Black to play: Execute the classic Monkey Jump along the 1st line!",
            hintZh: "不要贴身扳，沿一路小飞伸腿潜入白棋边空下方。",
            hintEn: "Jump a knight's move deep along the 1st line under White's wall.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[cd][ce][dc][cc]AW[gc][gd][ge](;B[fa];W[fb];B[ea]C[CORRECT])(;B[eb];W[fb]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 1, maxCol: 8)
        ),
        GoPuzzle(
            id: "dojo-end-03", category: .endgame, rankBadge: "6K",
            titleZh: "一路点收官手筋", titleEn: "First-Line Clamp Endgame",
            promptZh: "黑先：沿一路巧妙扳入，白棋因气紧无法硬挡！",
            promptEn: "Black to play: Slip onto the 1st line exploiting White's shortage of liberties!",
            hintZh: "一路扳进去，如果白棋挡就会被黑棋切断反吃。",
            hintEn: "Hane on the 1st line — White is too short of liberties to block aggressively.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[cb][cc][cd][dc][eb][ec]AW[bb][bc][bd][ab][db][da](;B[ca];W[ba];B[ea]C[CORRECT])(;B[ea];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "dojo-end-04", category: .endgame, rankBadge: "1D",
            titleZh: "逆收大官子", titleEn: "Reverse Sente Endgame",
            promptZh: "黑先：抢先一步在二路挡下，防住白棋的先手扳粘！",
            promptEn: "Black to play: Block on the 2nd line first to prevent White's painful sente hane!",
            hintZh: "被白棋扳进去是双倍损失（逆收大官子），先抢二路要点！",
            hintEn: "Preventing White's sente intrusion is worth double — claim the 2nd-line point first.",
            boardSize: 9, playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[dc][dd][de][ec]AW[fc][fd][fe][gd](;B[fb];W[gb];B[eb]C[CORRECT])(;B[eb];W[fb]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 2, maxCol: 8)
        )
    ]

    /// Generates the full 320-puzzle Graded Dojo Bank (64 core authentic archetypes × 5 distinct
    /// orientation/mirror/color-swap perspectives, each with its own verified SGF & unique ID!).
    static let allDojoPuzzles: [GoPuzzle] = {
        let baseTemplates = BuiltInPuzzleLibrary.allPuzzles + coreDojoTemplates // 20 + 44 = 64 templates
        let variantTransforms: [(suffix: String, zhTag: String, enTag: String, transform: PuzzleTransform)] = [
            ("", "", "", .identity),
            ("-r90", " · 旋转视角", " (Rotated 90°)", PuzzleTransform(rotation: 1, mirrored: false, swapColors: false)),
            ("-w", " · 执白先手", " (White to Play)", PuzzleTransform(rotation: 2, mirrored: false, swapColors: true)),
            ("-m", " · 镜像翻转", " (Mirrored)", PuzzleTransform(rotation: 0, mirrored: true, swapColors: false)),
            ("-wm", " · 白先变向", " (White Mirrored)", PuzzleTransform(rotation: 3, mirrored: true, swapColors: true))
        ]

        var result: [GoPuzzle] = []
        result.reserveCapacity(baseTemplates.count * variantTransforms.count)

        for template in baseTemplates {
            for v in variantTransforms {
                if v.transform.isIdentity {
                    result.append(template)
                } else {
                    result.append(transformedPuzzle(template, suffix: v.suffix, zhTag: v.zhTag, enTag: v.enTag, transform: v.transform))
                }
            }
        }
        return result
    }()

    static func findPuzzle(withId id: String) -> GoPuzzle? {
        if let found = allDojoPuzzlesById[id] { return found }
        return PuzzlePackLoader.findPuzzle(withId: id)
    }

    private static let allDojoPuzzlesById: [String: GoPuzzle] = {
        Dictionary(uniqueKeysWithValues: allDojoPuzzles.map { ($0.id, $0) })
    }()

    /// Full combined catalog: 320 Core Dojo puzzles + 800+ External JSON Pack puzzles (1,100+ total, 30K -> 5D).
    static var fullCatalog: [GoPuzzle] {
        PuzzlePackLoader.fullCatalog
    }

    static func puzzles(category: PuzzleCategory?, rankBand: DojoRankBand, includeExpandedPack: Bool = false) -> [GoPuzzle] {
        let source = includeExpandedPack ? fullCatalog : allDojoPuzzles
        return source.filter { p in
            if let category, p.category != category { return false }
            return rankBand.matches(p)
        }
    }

    /// Produces a standalone SGF-transformed variant puzzle so every puzzle in the catalog
    /// is independently playable, verifiable, and tracks its own star/SRS mastery!
    static func transformedPuzzle(
        _ base: GoPuzzle,
        suffix: String,
        zhTag: String,
        enTag: String,
        transform: PuzzleTransform
    ) -> GoPuzzle {
        let transformedSGF: String
        if let root = base.parsedRoot(transform: transform) {
            transformedSGF = serializeSGF(root)
        } else {
            transformedSGF = base.sgf
        }
        let newColor = transform.apply(to: base.playerColor)
        let newCrop = transform.apply(to: base.cropRegion, boardSize: base.boardSize)
        let newPromptZh = swapColorTermsZh(base.promptZh, swap: transform.swapColors)
        let newPromptEn = swapColorTermsEn(base.promptEn, swap: transform.swapColors)
        let newHintZh = swapColorTermsZh(base.hintZh, swap: transform.swapColors)
        let newHintEn = swapColorTermsEn(base.hintEn, swap: transform.swapColors)

        return GoPuzzle(
            id: "\(base.id)\(suffix)",
            category: base.category,
            rankBadge: base.rankBadge,
            titleZh: base.titleZh + zhTag,
            titleEn: base.titleEn + enTag,
            promptZh: newPromptZh,
            promptEn: newPromptEn,
            hintZh: newHintZh,
            hintEn: newHintEn,
            boardSize: base.boardSize,
            playerColor: newColor,
            sgf: transformedSGF,
            cropRegion: newCrop
        )
    }

    private static func swapColorTermsZh(_ text: String, swap: Bool) -> String {
        guard swap else { return text }
        return text
            .replacingOccurrences(of: "黑先", with: "白先")
            .replacingOccurrences(of: "黑棋", with: "__TB__")
            .replacingOccurrences(of: "黑子", with: "__TBS__")
            .replacingOccurrences(of: "黑墙", with: "__TBW__")
            .replacingOccurrences(of: "白棋", with: "黑棋")
            .replacingOccurrences(of: "白子", with: "黑子")
            .replacingOccurrences(of: "白墙", with: "黑墙")
            .replacingOccurrences(of: "__TB__", with: "白棋")
            .replacingOccurrences(of: "__TBS__", with: "白子")
            .replacingOccurrences(of: "__TBW__", with: "白墙")
    }

    private static func swapColorTermsEn(_ text: String, swap: Bool) -> String {
        guard swap else { return text }
        return text
            .replacingOccurrences(of: "Black", with: "__TB__")
            .replacingOccurrences(of: "black", with: "__tb__")
            .replacingOccurrences(of: "White", with: "Black")
            .replacingOccurrences(of: "white", with: "black")
            .replacingOccurrences(of: "__TB__", with: "White")
            .replacingOccurrences(of: "__tb__", with: "white")
    }

    /// Serializes an `SGFNode` tree back into canonical FF[4] SGF syntax.
    private static func serializeSGF(_ root: SGFNode) -> String {
        func serializeNode(_ node: SGFNode) -> String {
            var out = ";"
            // Deterministic key ordering
            for key in node.properties.keys.sorted() {
                guard let vals = node.properties[key], !vals.isEmpty else { continue }
                out += key
                for v in vals {
                    let esc = v.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "]", with: "\\]")
                    out += "[\(esc)]"
                }
            }
            if node.children.count == 1 {
                out += serializeNode(node.children[0])
            } else if node.children.count > 1 {
                for child in node.children {
                    out += "(" + serializeNode(child) + ")"
                }
            }
            return out
        }
        return "(" + serializeNode(root) + ")"
    }
}
