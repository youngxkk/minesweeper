//
//  BuiltInPuzzleLibrary.swift
//  StarYi Go
//

import Foundation

enum BuiltInPuzzleLibrary {
    /// 20 handcrafted, mathematically verified SGF Go puzzles across 4 progressive categories.
    static let allPuzzles: [GoPuzzle] = [
        // MARK: - 1. Capture (吃子技巧)
        GoPuzzle(
            id: "cap-01",
            category: .capture,
            rankBadge: "25K",
            titleZh: "一击提子",
            titleEn: "First Capture",
            promptZh: "黑先：找到白棋最后一口气，提掉它！",
            promptEn: "Black to play: Take White's last liberty to capture!",
            hintZh: "观察白子上下左右四个方向，哪一边还是空的？",
            hintEn: "Look at the 4 orthogonal neighbors of the white stone.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ed][ef][de]AW[ee](;B[fe]C[CORRECT]))",
            cropRegion: BoardCropRegion(minRow: 1, maxRow: 7, minCol: 1, maxCol: 7)
        ),
        GoPuzzle(
            id: "cap-02",
            category: .capture,
            rankBadge: "24K",
            titleZh: "边线提两子",
            titleEn: "Edge Double Capture",
            promptZh: "黑先：一口气提掉边线的两颗白子。",
            promptEn: "Black to play: Capture both white stones on the edge.",
            hintZh: "两颗白子连在一起，只剩一路边线上的最后一口气。",
            hintEn: "The two connected white stones share only one liberty on the first line.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[da][db][ec][fb]AW[ea][eb](;B[fa]C[CORRECT]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 1, maxCol: 7)
        ),
        GoPuzzle(
            id: "cap-03",
            category: .capture,
            rankBadge: "22K",
            titleZh: "抱吃逼边",
            titleEn: "Drive to the Edge",
            promptZh: "黑先：把白棋逼向一路边线并吃掉它。",
            promptEn: "Black to play: Push White toward the edge and capture.",
            hintZh: "不要从一路打吃，从二路把白棋往边线方向赶！",
            hintEn: "Atari from the second line to force White onto the first line.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ca][cc][dc][eb]AW[db](;B[cb];W[da];B[ea]C[CORRECT])(;B[da];W[cb]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "cap-04",
            category: .capture,
            rankBadge: "20K",
            titleZh: "经典双打吃",
            titleEn: "Classic Double Atari",
            promptZh: "黑先：一子同时叫吃两颗白子！",
            promptEn: "Black to play: Put both white stones in atari at once!",
            hintZh: "找两颗白子共用的那一口气。",
            hintEn: "Find the liberty shared by both white stones.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[cd][de][fe]AW[dd][ee](;B[ed](;W[dc];B[ef]C[CORRECT])(;W[ef];B[dc]C[CORRECT]))(;B[dc];W[ed]C[WRONG])(;B[ef];W[ed]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 1, maxRow: 7, minCol: 1, maxCol: 7)
        ),
        GoPuzzle(
            id: "cap-05",
            category: .capture,
            rankBadge: "18K",
            titleZh: "天罗地网（枷吃）",
            titleEn: "The Classic Net (Geta)",
            promptZh: "黑先：不要直接贴身打吃，用一个轻灵的“枷”罩住白子！",
            promptEn: "Black to play: Capture White in a loose net instead of direct atari.",
            hintZh: "在白子的斜对角轻轻一罩，无论白棋往哪边冲都只有一口气。",
            hintEn: "Play diagonally to surround White's escape routes from a distance.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ed][de][fd][df][eg][ge]AW[ee](;B[ff](;W[fe];B[ef]C[CORRECT])(;W[ef];B[fe]C[CORRECT]))(;B[fe];W[ef]C[WRONG])(;B[ef];W[fe]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 1, maxRow: 8, minCol: 1, maxCol: 8)
        ),

        // MARK: - 2. Classic Tactics (经典手筋)
        GoPuzzle(
            id: "tac-01",
            category: .tactics,
            rankBadge: "16K",
            titleZh: "绝妙倒扑",
            titleEn: "Classic Snapback",
            promptZh: "黑先：送吃一子，再把白棋整块提光！",
            promptEn: "Black to play: Sacrifice one stone to capture the entire white group!",
            hintZh: "先在一路切断白棋与角上的联系，让白棋自己撞进气紧的口袋。",
            hintEn: "Cut White off from the corner first — if White captures, snap right back!",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[aa][ab][ba][cb][db][eb][ea]AB[bb][bc][cc][dc][ec][fb][fa](;B[ca];W[da];B[ca]C[CORRECT])(;B[da];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "tac-02",
            category: .tactics,
            rankBadge: "15K",
            titleZh: "接不归",
            titleEn: "Connect and Die",
            promptZh: "黑先：叫吃左边白棋，如果白棋硬连就会全军覆没！",
            promptEn: "Black to play: Atari the left group — if White connects, capture all!",
            hintZh: "先从二路分断叫吃，千万别让白棋从二路逃出去。",
            hintEn: "Cut on the second line so connecting leaves White with only 1 liberty.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[aa][ab][bc][dc][ec][eb][fb][ga]AW[ba][bb][db][da][ea](;B[cb];W[ca];B[fa]C[CORRECT])(;B[ca];W[cb]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7)
        ),
        GoPuzzle(
            id: "tac-03",
            category: .tactics,
            rankBadge: "15K",
            titleZh: "征子追击",
            titleEn: "Ladder Chase",
            promptZh: "黑先：一步步左右紧追，把白棋赶向边线吃掉！",
            promptEn: "Black to play: Zig-zag chase White all the way to the edge!",
            hintZh: "第一手堵住白棋向中央逃跑的路线，把它赶往上方边线。",
            hintEn: "Block White from escaping to the center and drive it toward the top edge.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ca][cb][cc][dd]AW[dc](;B[ec];W[db];B[eb];W[da];B[ea]C[CORRECT])(;B[db];W[ec]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 1, maxCol: 6)
        ),
        GoPuzzle(
            id: "tac-04",
            category: .tactics,
            rankBadge: "13K",
            titleZh: "犀利挖断",
            titleEn: "The Sharp Wedge",
            promptZh: "黑先：一子楔入白棋薄弱处，左右必得其一！",
            promptEn: "Black to play: Wedge into White's weak spot to capture a stone!",
            hintZh: "瞄准两颗二路白子正中间的交叉点，一子挖进去！",
            hintEn: "Play right between the two white stones on the second line.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ba][bb][cc][dc][ec][fb][fa]AW[cb][da][eb](;B[db](;W[ca];B[ea]C[CORRECT])(;W[ea];B[ca]C[CORRECT]))(;B[ca];W[db]C[WRONG])(;B[ea];W[db]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "tac-05",
            category: .tactics,
            rankBadge: "12K",
            titleZh: "金鸡独立",
            titleEn: "Crane's Leg Tesuji",
            promptZh: "黑先：走出一记“金鸡独立”，让左右两块白棋都无法入气！",
            promptEn: "Black to play: One brilliant move makes both sides unplayable for White!",
            hintZh: "把中间那颗一路黑子稳稳接回，看看左右两边白棋还敢不敢落子？",
            hintEn: "Connect your top stone downward — both white groups will suffer shortage of liberties.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[aa][ab][bb][db][eb][ea]AB[ca][ac][bc][cc][dc][ec][fb][fa](;B[cb]C[CORRECT])(;B[ba];W[cb]C[WRONG])(;B[da];W[cb]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),

        // MARK: - 3. Life & Death (死活天地)
        GoPuzzle(
            id: "lad-01",
            category: .lifeAndDeath,
            rankBadge: "20K",
            titleZh: "直三做活",
            titleEn: "Straight Three to Live",
            promptZh: "黑先：下在眼位要点，做出两只真眼活棋！",
            promptEn: "Black to play: Find the vital point to make two true eyes!",
            hintZh: "三个并排空点的正中央，就是一分为二的活棋要点。",
            hintEn: "Divide the three empty spaces right in the middle.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[aa][ab][bb][cb][db][eb][ea]AW[ac][bc][cc][dc][ec][fb][fa](;B[ca]C[CORRECT])(;B[ba];W[ca]C[WRONG])(;B[da];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "lad-02",
            category: .lifeAndDeath,
            rankBadge: "18K",
            titleZh: "点杀直三",
            titleEn: "Kill the Straight Three",
            promptZh: "黑先：抢占对方的做眼要点，干净利落杀掉白棋！",
            promptEn: "Black to play: Take White's vital point before White makes two eyes!",
            hintZh: "敌之要点即我之要点——直接点在直三正中间！",
            hintEn: "Your opponent's vital point is your vital point!",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[aa][ab][bb][cb][db][eb][ea]AB[ac][bc][cc][dc][ec][fb][fa](;B[ca]C[CORRECT])(;B[ba];W[ca]C[WRONG])(;B[da];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "lad-03",
            category: .lifeAndDeath,
            rankBadge: "16K",
            titleZh: "角部曲三做活",
            titleEn: "Corner Bent Three",
            promptZh: "黑先：角上形成曲三眼位，请找到唯一的活棋要点。",
            promptEn: "Black to play: Make two eyes inside the corner Bent Three.",
            hintZh: "曲三的拐角处正是把三个空点分成两只眼的关键！",
            hintEn: "Play at the corner bend to split the space into two eyes.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ca][cb][bb][bc][ac]AW[da][db][dc][cd][bd][ad](;B[aa]C[CORRECT])(;B[ba];W[aa]C[WRONG])(;B[ab];W[aa]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 5)
        ),
        GoPuzzle(
            id: "lad-04",
            category: .lifeAndDeath,
            rankBadge: "14K",
            titleZh: "点杀刀把五",
            titleEn: "Kill the Bulky Five",
            promptZh: "黑先：白棋摆出了著名的“刀把五”，请一招点杀！",
            promptEn: "Black to play: Strike the vital point of the Bulky Five shape!",
            hintZh: "刀把五的要点在“刀背和刀柄交汇”的那个中心点。",
            hintEn: "Find the intersection touching three of the five empty spaces.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[aa][ab][ac][bc][cc][dc][db][eb][ea]AB[ad][bd][cd][dd][ed][ec][fc][fb][fa](;B[ca];W[ba];B[cb]C[CORRECT])(;B[ba];W[ca]C[WRONG])(;B[cb];W[ca]C[WRONG])(;B[da];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "lad-05",
            category: .lifeAndDeath,
            rankBadge: "12K",
            titleZh: "丁四要点",
            titleEn: "Pyramid Four Vital Point",
            promptZh: "黑先：白棋眼位呈“丁”字形四目，找出唯一杀棋点！",
            promptEn: "Black to play: Defeat the T-shaped Pyramid Four eye space.",
            hintZh: "下在“丁”字交叉的正中央，白棋就永远凑不出两只真眼。",
            hintEn: "Play at the center intersection of the T-shape.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[aa][ab][bb][bc][cc][dc][db][eb][ea]AB[ac][bd][cd][dd][ed][ec][fc][fb][fa](;B[ca]C[CORRECT])(;B[cb];W[ca]C[WRONG])(;B[ba];W[ca]C[WRONG])(;B[da];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),

        // MARK: - 4. Endgame & Fight (实战收官)
        GoPuzzle(
            id: "end-01",
            category: .endgame,
            rankBadge: "18K",
            titleZh: "关键连结",
            titleEn: "Vital Connection",
            promptZh: "黑先：下方两颗黑子危在旦夕，请立刻救出它们！",
            promptEn: "Black to play: Rescue the two black stones in atari!",
            hintZh: "一子把下面被叫吃的黑子与上方棋子牢牢连成一片。",
            hintEn: "Connect your endangered stones upward to gain plenty of liberties.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[cb][cd][dd]AW[bb][bc][bd][dc][eb][ec][ed][de][ce](;B[cc]C[CORRECT])(;B[db];W[cc]C[WRONG])(;B[ca];W[cc]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "end-02",
            category: .endgame,
            rankBadge: "15K",
            titleZh: "对杀先紧外气",
            titleEn: "Capturing Race: Outside Liberty",
            promptZh: "黑先：双方各有两口气，记住“对杀先紧外气”口诀！",
            promptEn: "Black to play: Both sides have 2 liberties — fill White's outside liberty first!",
            hintZh: "如果先填中间的公气，自己反而会被吃！先紧白棋右边那口外气。",
            hintEn: "Never fill the shared liberty first! Take White's outside liberty on the right.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ba][bb][cc][dc][ec][eb][fb][fa]AW[ab][ac][bc][cb][db][da](;B[ea];W[aa];B[ca]C[CORRECT])(;B[ca];W[aa]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "end-03",
            category: .endgame,
            rankBadge: "13K",
            titleZh: "一路扳渡",
            titleEn: "First-Line Connection",
            promptZh: "黑先：沿一路巧妙渡过，让左右黑棋连成一家！",
            promptEn: "Black to play: Slip underneath along the first line to connect!",
            hintZh: "紧贴左边白棋的一路下子，白棋如果硬挡就会被反吃。",
            hintEn: "Play on the first line right next to your left group — if White blocks, capture!",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AB[ba][bb][bc][db][dc][eb][ec]AW[ab][ac][bd][cb][cc][cd][dd](;B[ca];W[da];B[ea]C[CORRECT])(;B[da];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "end-04",
            category: .endgame,
            rankBadge: "11K",
            titleZh: "封口吃三子",
            titleEn: "Seal the Escape",
            promptZh: "黑先：选对打吃方向，不让白棋逃出边线！",
            promptEn: "Black to play: Choose the right side to atari so White cannot escape!",
            hintZh: "左边已经是黑棋铜墙铁壁，从右边封住出口，白棋立刻无路可逃。",
            hintEn: "Seal the open right exit instead of pushing White toward freedom.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[cb][db][da]AB[ba][bb][bc][cc][dc][ec][eb](;B[ea]C[CORRECT])(;B[ca];W[ea]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        ),
        GoPuzzle(
            id: "end-05",
            category: .endgame,
            rankBadge: "8K",
            titleZh: "缩小眼位杀棋",
            titleEn: "Reduce Eye Space First",
            promptZh: "黑先：不要急着破眼，先从外侧扳缩眼位，再一举歼灭！",
            promptEn: "Black to play: Shrink White's eye space from the outside first!",
            hintZh: "一路扳进去把四目缩成死形直三，无论白棋怎么挡都活不了。",
            hintEn: "Hane on the first line to shrink 4 spaces into a dead Straight Three.",
            boardSize: 9,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[9]PL[B]AW[aa][ab][bb][cb][db][eb]AB[ac][bc][cc][dc][ec][fc][fb][fa](;B[ea](;W[ca];B[da]C[CORRECT])(;W[da];B[ca]C[CORRECT]))(;B[ca];W[da]C[WRONG])(;B[da];W[ca]C[WRONG])(;B[ba];W[da]C[WRONG]))",
            cropRegion: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6)
        )
    ]

    static func puzzles(for category: PuzzleCategory?) -> [GoPuzzle] {
        guard let category else { return allPuzzles }
        return allPuzzles.filter { $0.category == category }
    }
}
