//
//  PhotoBoardRecognizerTests.swift
//  StarYiGoTests
//

import UIKit
import XCTest
@testable import StarYiGo

final class PhotoBoardRecognizerTests: XCTestCase {

    func testOrderCornersClockwiseNormalizesPermutations() {
        let tl = CGPoint(x: 0.1, y: 0.1)
        let tr = CGPoint(x: 0.9, y: 0.12)
        let br = CGPoint(x: 0.88, y: 0.9)
        let bl = CGPoint(x: 0.12, y: 0.88)

        let ordered = GoBoardPhotoRecognizer.orderCornersClockwise([br, tl, bl, tr])
        XCTAssertEqual(ordered.topLeft, tl)
        XCTAssertEqual(ordered.topRight, tr)
        XCTAssertEqual(ordered.bottomRight, br)
        XCTAssertEqual(ordered.bottomLeft, bl)
    }

    func testOfflineRecognizerDetects9x9StonesAndWinner() async {
        // Construct a 9x9 endgame position where Black clearly owns columns 0...5 and White owns columns 7...8
        var expected = GoBoardState(size: 9, komi: 5.5)
        for r in 0..<9 {
            expected.grid[expected.index(row: r, col: 5)] = .black
            expected.grid[expected.index(row: r, col: 6)] = .white
        }
        // Add a few extra stones inside each territory
        expected.grid[expected.index(row: 2, col: 2)] = .black
        expected.grid[expected.index(row: 6, col: 2)] = .black
        expected.grid[expected.index(row: 4, col: 7)] = .white

        let syntheticImage = renderSyntheticWoodBoard(state: expected, side: 760, insetFraction: 0.05)
        let fullQuad = BoardCornerQuad(
            topLeft: CGPoint(x: 0.0, y: 0.0),
            topRight: CGPoint(x: 1.0, y: 0.0),
            bottomRight: CGPoint(x: 1.0, y: 1.0),
            bottomLeft: CGPoint(x: 0.0, y: 1.0)
        )

        let recognized = GoBoardPhotoRecognizer.recognizeBoard(
            from: syntheticImage,
            corners: fullQuad,
            boardSize: .nine,
            gridInsetFraction: 0.05,
            komi: 5.5
        )

        XCTAssertEqual(recognized.boardState.grid, expected.grid, "All 81 intersections should be recognized accurately")
        XCTAssertEqual(recognized.blackStoneCount, 11)
        XCTAssertEqual(recognized.whiteStoneCount, 10)

        let eval = await CoreMLGoAIEngine.shared.evaluateForPhotoJudge(
            state: recognized.boardState,
            rule: .chinese,
            deadStoneIndices: []
        )
        XCTAssertEqual(eval.gameResult.winner, .black)
        XCTAssertGreaterThan(eval.gameResult.blackScore, eval.gameResult.whiteScore)
    }

    func testOfflineRecognizerHandles19x19BoardWithSpecularHighlights() {
        var expected = GoBoardState(size: 19, komi: 7.5)
        let blackCoords = [(3, 3), (3, 15), (15, 3), (9, 9), (4, 10), (14, 12)]
        let whiteCoords = [(3, 9), (15, 15), (9, 3), (10, 10), (16, 4), (2, 16)]

        for (r, c) in blackCoords {
            expected.grid[expected.index(row: r, col: c)] = .black
        }
        for (r, c) in whiteCoords {
            expected.grid[expected.index(row: r, col: c)] = .white
        }

        let syntheticImage = renderSyntheticWoodBoard(state: expected, side: 900, insetFraction: 0.045)
        let fullQuad = BoardCornerQuad(
            topLeft: CGPoint(x: 0.0, y: 0.0),
            topRight: CGPoint(x: 1.0, y: 0.0),
            bottomRight: CGPoint(x: 1.0, y: 1.0),
            bottomLeft: CGPoint(x: 0.0, y: 1.0)
        )

        let recognized = GoBoardPhotoRecognizer.recognizeBoard(
            from: syntheticImage,
            corners: fullQuad,
            boardSize: .nineteen,
            gridInsetFraction: 0.045,
            komi: 7.5
        )

        XCTAssertEqual(recognized.boardState.grid, expected.grid, "All 361 intersections on 19x19 should match")
        XCTAssertEqual(recognized.blackStoneCount, blackCoords.count)
        XCTAssertEqual(recognized.whiteStoneCount, whiteCoords.count)
    }

    func testAutoDetectGridStructureDistinguishes19x19_13x13_9x9WithDenseStones() {
        let cases: [(BoardSize, CGFloat)] = [
            (.nineteen, 0.045),
            (.nineteen, 0.075),
            (.thirteen, 0.05),
            (.nine, 0.06)
        ]

        let fullQuad = BoardCornerQuad(
            topLeft: CGPoint(x: 0.0, y: 0.0),
            topRight: CGPoint(x: 1.0, y: 0.0),
            bottomRight: CGPoint(x: 1.0, y: 1.0),
            bottomLeft: CGPoint(x: 0.0, y: 1.0)
        )

        for (expectedSize, inset) in cases {
            var state = GoBoardState(size: expectedSize.rawValue, komi: expectedSize.defaultKomi)
            // Populate ~40% of the board with alternating black & white clusters (realistic endgame density)
            let n = expectedSize.rawValue
            for r in 0..<n {
                for c in 0..<n {
                    if (r * 7 + c * 13) % 5 == 0 {
                        state.grid[state.index(row: r, col: c)] = (r + c) % 2 == 0 ? .black : .white
                    }
                }
            }

            let img = renderSyntheticWoodBoard(state: state, side: 800, insetFraction: inset)
            let detected = GoBoardPhotoRecognizer.detectBoardGridStructure(
                from: img,
                corners: fullQuad,
                candidates: [.nineteen, .thirteen, .nine]
            )

            XCTAssertEqual(
                detected.boardSize,
                expectedSize,
                "Expected auto-detected size \(expectedSize.rawValue)x\(expectedSize.rawValue) for inset \(inset), got \(detected.boardSize.rawValue)x\(detected.boardSize.rawValue)"
            )
            XCTAssertEqual(Double(detected.gridInsetFraction), Double(inset), accuracy: 0.015)
            XCTAssertGreaterThanOrEqual(detected.confidence, 0.50)
        }
    }

    func testEndToEndTabletop19x19PhotoAutoDetectsCornersSizeAndStones() async {
        // Build a realistic 19x19 endgame with >100 stones where Black clearly controls the left 11 columns
        var expected = GoBoardState(size: 19, komi: 7.5)
        for r in 0..<19 {
            expected.grid[expected.index(row: r, col: 10)] = .black
            expected.grid[expected.index(row: r, col: 11)] = .white
        }
        // Scatter realistic stones inside both territories
        for r in stride(from: 2, to: 17, by: 2) {
            for c in stride(from: 2, to: 9, by: 3) {
                expected.grid[expected.index(row: r, col: c)] = .black
            }
            for c in stride(from: 13, to: 18, by: 2) {
                expected.grid[expected.index(row: r, col: c)] = .white
            }
        }

        // Render the 19x19 wooden board sitting on a larger dark tabletop photo (1200x900 landscape photo)
        let boardImg = renderSyntheticWoodBoard(state: expected, side: 640, insetFraction: 0.05)
        let tabletopPhoto = renderBoardOnTabletop(boardImage: boardImg, canvasSize: CGSize(width: 1200, height: 900))

        // Step 1: Fully automatic corner detection (no hardcoded corners!)
        let detectedCorners = GoBoardPhotoRecognizer.detectBoardCorners(in: tabletopPhoto)

        // Step 2: Fully automatic 19x19 vs 13x13 vs 9x9 detection
        let gridInfo = GoBoardPhotoRecognizer.detectBoardGridStructure(
            from: tabletopPhoto,
            corners: detectedCorners,
            candidates: [.nineteen, .thirteen, .nine]
        )
        XCTAssertEqual(gridInfo.boardSize, .nineteen, "19x19 tabletop photo MUST auto-detect as 19x19, not 9x9")

        // Step 3: Recognize stones and judge winner offline
        let recognized = GoBoardPhotoRecognizer.recognizeBoard(
            from: tabletopPhoto,
            corners: detectedCorners,
            boardSize: gridInfo.boardSize,
            gridInsetFraction: gridInfo.gridInsetFraction,
            komi: 7.5
        )
        XCTAssertEqual(recognized.boardState.size, 19)

        var matches = 0
        for i in 0..<(19 * 19) {
            if recognized.boardState.grid[i] == expected.grid[i] {
                matches += 1
            }
        }
        let accuracy = Double(matches) / 361.0
        XCTAssertGreaterThanOrEqual(accuracy, 0.96, "Expected >=96% accuracy on full auto 19x19 tabletop photo, got \(accuracy)")

        let eval = await CoreMLGoAIEngine.shared.evaluateForPhotoJudge(
            state: recognized.boardState,
            rule: .chinese,
            deadStoneIndices: []
        )
        XCTAssertEqual(eval.gameResult.winner, .black)
    }

    func testAutoDetectBoardAndGridDistinguishesAllFourSizesOnTabletop() {
        let sizes: [BoardSize] = [.nineteen, .thirteen, .nine, .seven]
        for expectedSize in sizes {
            let n = expectedSize.rawValue
            var state = GoBoardState(size: n, komi: expectedSize.defaultKomi)
            for r in 0..<n {
                for c in 0..<n {
                    if (r * 5 + c * 7) % 6 == 0 {
                        state.grid[state.index(row: r, col: c)] = ((r + c) % 2 == 0) ? .black : .white
                    }
                }
            }

            let boardImg = renderSyntheticWoodBoard(state: state, side: 640, insetFraction: 0.05)
            let tabletopPhoto = renderBoardOnTabletop(boardImage: boardImg, canvasSize: CGSize(width: 1200, height: 900))

            let detected = GoBoardPhotoRecognizer.autoDetectBoardAndGrid(
                in: tabletopPhoto,
                candidates: [.nineteen, .thirteen, .nine, .seven]
            )
            XCTAssertEqual(
                detected.boardSize,
                expectedSize,
                "Expected \(n)x\(n) tabletop board to auto-detect as \(n)x\(n), got \(detected.boardSize.rawValue)x\(detected.boardSize.rawValue)"
            )
            XCTAssertGreaterThanOrEqual(detected.confidence, 0.45)

            let recognized = GoBoardPhotoRecognizer.recognizeBoard(
                from: tabletopPhoto,
                corners: detected.corners,
                boardSize: detected.boardSize,
                gridInsetFraction: detected.gridInsetFraction,
                komi: expectedSize.defaultKomi
            )
            var matches = 0
            for i in 0..<(n * n) {
                if recognized.boardState.grid[i] == state.grid[i] {
                    matches += 1
                }
            }
            let accuracy = Double(matches) / Double(n * n)
            XCTAssertGreaterThanOrEqual(
                accuracy,
                0.96,
                "Expected >=96% stone accuracy after one-shot autoDetectBoardAndGrid for \(n)x\(n), got \(accuracy)"
            )
        }
    }

    func testAsymmetricBoardMarginsAutoSnapGridAndRecognizeAccurately() {
        let n = 13
        var expected = GoBoardState(size: n, komi: 6.5)
        for r in 0..<n {
            expected.grid[expected.index(row: r, col: 6)] = .black
            expected.grid[expected.index(row: r, col: 7)] = .white
        }
        expected.grid[expected.index(row: 2, col: 2)] = .black
        expected.grid[expected.index(row: 10, col: 10)] = .white

        // Asymmetric wooden borders (left 9%, right 3%, top 8%, bottom 4%)
        let asymImage = renderAsymmetricWoodBoard(
            state: expected,
            side: 760,
            leftInset: 0.09,
            rightInset: 0.03,
            topInset: 0.08,
            bottomInset: 0.04
        )
        let fullQuad = BoardCornerQuad(
            topLeft: CGPoint(x: 0.0, y: 0.0),
            topRight: CGPoint(x: 1.0, y: 0.0),
            bottomRight: CGPoint(x: 1.0, y: 1.0),
            bottomLeft: CGPoint(x: 0.0, y: 1.0)
        )

        let gridInfo = GoBoardPhotoRecognizer.detectBoardGridStructure(
            from: asymImage,
            corners: fullQuad,
            candidates: [.nineteen, .thirteen, .nine, .seven],
            snapCorners: true
        )
        XCTAssertEqual(gridInfo.boardSize, .thirteen)
        XCTAssertNotNil(gridInfo.refinedCorners)

        let recognized = GoBoardPhotoRecognizer.recognizeBoard(
            from: asymImage,
            corners: gridInfo.refinedCorners ?? fullQuad,
            boardSize: gridInfo.boardSize,
            gridInsetFraction: gridInfo.gridInsetFraction,
            komi: 6.5
        )
        var matches = 0
        for i in 0..<(n * n) {
            if recognized.boardState.grid[i] == expected.grid[i] {
                matches += 1
            }
        }
        let accuracy = Double(matches) / Double(n * n)
        XCTAssertGreaterThanOrEqual(accuracy, 0.98, "Asymmetric board should snap cleanly to >=98% accuracy, got \(accuracy)")
    }

    func testRotatedWoodOnWoodBoardAutoAlignsAndDetectsSize() {
        // Hard real-world scenario: a 9x9 wooden board rotated 10 degrees on a similar light-wood desk
        let n = 9
        var expected = GoBoardState(size: n, komi: 5.5)
        for r in 0..<n {
            expected.grid[expected.index(row: r, col: 4)] = .black
            expected.grid[expected.index(row: r, col: 5)] = .white
        }
        expected.grid[expected.index(row: 2, col: 2)] = .black
        expected.grid[expected.index(row: 6, col: 7)] = .white

        let boardImg = renderSyntheticWoodBoard(state: expected, side: 560, insetFraction: 0.05)
        let canvasSize = CGSize(width: 1100, height: 850)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let tiltedPhoto = UIGraphicsImageRenderer(size: canvasSize, format: format).image { ctx in
            let cg = ctx.cgContext
            // Similar warm light-wood desk background (low border contrast!)
            cg.setFillColor(UIColor(red: 0.80, green: 0.66, blue: 0.44, alpha: 1.0).cgColor)
            cg.fill(CGRect(origin: .zero, size: canvasSize))

            cg.saveGState()
            cg.translateBy(x: canvasSize.width * 0.5, y: canvasSize.height * 0.5)
            cg.rotate(by: 10.0 * .pi / 180.0)
            let rect = CGRect(x: -280, y: -280, width: 560, height: 560)
            boardImg.draw(in: rect)
            cg.restoreGState()
        }

        let detected = GoBoardPhotoRecognizer.autoDetectBoardAndGrid(
            in: tiltedPhoto,
            candidates: [.nineteen, .thirteen, .nine, .seven]
        )
        XCTAssertEqual(detected.boardSize, .nine, "Rotated wood-on-wood 9x9 board should auto-detect as 9x9")
        XCTAssertGreaterThanOrEqual(detected.confidence, 0.40)

        let recognized = GoBoardPhotoRecognizer.recognizeBoard(
            from: tiltedPhoto,
            corners: detected.corners,
            boardSize: detected.boardSize,
            gridInsetFraction: detected.gridInsetFraction,
            komi: 5.5
        )
        var matches = 0
        for i in 0..<(n * n) {
            if recognized.boardState.grid[i] == expected.grid[i] {
                matches += 1
            }
        }
        let accuracy = Double(matches) / Double(n * n)
        XCTAssertGreaterThanOrEqual(accuracy, 0.90, "Rotated wood-on-wood 9x9 board should auto-align cleanly, got accuracy \(accuracy)")
    }

    // MARK: - Synthetic Wooden Go Board Renderer

    private func renderBoardOnTabletop(boardImage: UIImage, canvasSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            // Dark tabletop background
            cg.setFillColor(UIColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1.0).cgColor)
            cg.fill(CGRect(origin: .zero, size: canvasSize))

            let boardSide = min(canvasSize.width, canvasSize.height) * 0.78
            let origin = CGPoint(
                x: (canvasSize.width - boardSide) * 0.52,
                y: (canvasSize.height - boardSide) * 0.48
            )
            boardImage.draw(in: CGRect(origin: origin, size: CGSize(width: boardSide, height: boardSide)))
        }
    }

    private func renderSyntheticWoodBoard(state: GoBoardState, side: Int, insetFraction: CGFloat) -> UIImage {
        renderAsymmetricWoodBoard(
            state: state,
            side: side,
            leftInset: insetFraction,
            rightInset: insetFraction,
            topInset: insetFraction,
            bottomInset: insetFraction
        )
    }

    private func renderAsymmetricWoodBoard(
        state: GoBoardState,
        side: Int,
        leftInset: CGFloat,
        rightInset: CGFloat,
        topInset: CGFloat,
        bottomInset: CGFloat
    ) -> UIImage {
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            // Warm kaya wood fill
            cg.setFillColor(UIColor(red: 0.87, green: 0.72, blue: 0.48, alpha: 1.0).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            let n = state.size
            let startX = CGFloat(side) * leftInset
            let endX = CGFloat(side) * (1.0 - rightInset)
            let startY = CGFloat(side) * topInset
            let endY = CGFloat(side) * (1.0 - bottomInset)
            let spanX = endX - startX
            let spanY = endY - startY
            let stepX = spanX / CGFloat(n - 1)
            let stepY = spanY / CGFloat(n - 1)

            // Grid lines
            cg.setStrokeColor(UIColor(red: 0.22, green: 0.16, blue: 0.10, alpha: 0.9).cgColor)
            cg.setLineWidth(1.5)
            for i in 0..<n {
                let y = startY + CGFloat(i) * stepY
                cg.move(to: CGPoint(x: startX, y: y))
                cg.addLine(to: CGPoint(x: endX, y: y))
                let x = startX + CGFloat(i) * stepX
                cg.move(to: CGPoint(x: x, y: startY))
                cg.addLine(to: CGPoint(x: x, y: endY))
            }
            cg.strokePath()

            // Stones with realistic highlight/shadow
            let radius = min(stepX, stepY) * 0.44
            for r in 0..<n {
                for c in 0..<n {
                    guard let stone = state.stone(at: BoardPoint(row: r, col: c)) else { continue }
                    let cx = startX + CGFloat(c) * stepX
                    let cy = startY + CGFloat(r) * stepY
                    let rect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)

                    if stone == .black {
                        cg.setFillColor(UIColor(white: 0.08, alpha: 1.0).cgColor)
                        cg.fillEllipse(in: rect)
                        // Realistic glossy specular spot on black stone
                        let glare = CGRect(x: cx - radius * 0.35, y: cy - radius * 0.38, width: radius * 0.28, height: radius * 0.28)
                        cg.setFillColor(UIColor(white: 0.65, alpha: 0.55).cgColor)
                        cg.fillEllipse(in: glare)
                    } else {
                        cg.setFillColor(UIColor(white: 0.95, alpha: 1.0).cgColor)
                        cg.fillEllipse(in: rect)
                        cg.setStrokeColor(UIColor(white: 0.65, alpha: 0.7).cgColor)
                        cg.setLineWidth(1.2)
                        cg.strokeEllipse(in: rect)
                    }
                }
            }
        }
    }
}
