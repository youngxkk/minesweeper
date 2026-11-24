//
//  GoBoardPhotoRecognizer.swift
//  StarYi Go — 100% Offline On-Device Go Board Photo Recognition (Vision + CoreImage)
//

import CoreGraphics
import CoreImage
import Foundation
import UIKit
import Vision

/// Normalized 4-corner quadrilateral in image coordinates (x: 0...1 left->right, y: 0...1 top->bottom).
struct BoardCornerQuad: Equatable, Sendable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    static let defaultCentered = BoardCornerQuad(
        topLeft: CGPoint(x: 0.12, y: 0.12),
        topRight: CGPoint(x: 0.88, y: 0.12),
        bottomRight: CGPoint(x: 0.88, y: 0.88),
        bottomLeft: CGPoint(x: 0.12, y: 0.88)
    )

    /// Bilinear interpolation inside the quad for normalized grid coordinates (u, v) in [0, 1].
    func point(u: CGFloat, v: CGFloat) -> CGPoint {
        let topX = topLeft.x + (topRight.x - topLeft.x) * u
        let topY = topLeft.y + (topRight.y - topLeft.y) * u
        let botX = bottomLeft.x + (bottomRight.x - bottomLeft.x) * u
        let botY = bottomLeft.y + (bottomRight.y - bottomLeft.y) * u
        return CGPoint(
            x: topX + (botX - topX) * v,
            y: topY + (botY - topY) * v
        )
    }

    func clamped() -> BoardCornerQuad {
        func clampPt(_ p: CGPoint) -> CGPoint {
            CGPoint(x: min(0.99, max(0.01, p.x)), y: min(0.99, max(0.01, p.y)))
        }
        return BoardCornerQuad(
            topLeft: clampPt(topLeft),
            topRight: clampPt(topRight),
            bottomRight: clampPt(bottomRight),
            bottomLeft: clampPt(bottomLeft)
        )
    }
}

/// Output of offline board photo recognition.
struct BoardRecognitionResult: Sendable {
    let boardState: GoBoardState
    let warpedBoardImage: UIImage
    let blackStoneCount: Int
    let whiteStoneCount: Int
    let averageConfidence: Double
    let lowConfidencePoints: [BoardPoint]
    let detectedCorners: BoardCornerQuad
}

/// Automatically detected board line count (19×19 / 13×13 / 9×9 / 7×7), outer wooden margin inset,
/// and optional refined 4-corner quad snapped tightly to the detected grid lines.
struct DetectedGridStructure: Sendable, Equatable {
    let boardSize: BoardSize
    let gridInsetFraction: CGFloat
    let confidence: Double
    let refinedCorners: BoardCornerQuad?

    init(
        boardSize: BoardSize,
        gridInsetFraction: CGFloat,
        confidence: Double,
        refinedCorners: BoardCornerQuad? = nil
    ) {
        self.boardSize = boardSize
        self.gridInsetFraction = gridInsetFraction
        self.confidence = confidence
        self.refinedCorners = refinedCorners
    }
}

/// Combined one-shot auto-detection result for corners + board size + grid inset.
struct AutoBoardDetectionResult: Sendable, Equatable {
    let corners: BoardCornerQuad
    let boardSize: BoardSize
    let gridInsetFraction: CGFloat
    let confidence: Double
}

/// 100% offline, zero-server Go board photo recognizer powered by Apple Vision & CoreImage.
enum GoBoardPhotoRecognizer {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - 1. Image Orientation Normalization

    /// Renders `UIImage` into an `.up`-oriented upright bitmap so Vision, CoreImage, and SwiftUI share identical coordinates.
    static func normalizedUpImage(_ image: UIImage, maxDimension: CGFloat = 1600) -> UIImage {
        let origSize = image.size
        guard origSize.width > 0, origSize.height > 0 else { return image }

        let scaleRatio = min(1.0, maxDimension / max(origSize.width, origSize.height))
        let targetSize = CGSize(
            width: max(1, (origSize.width * scaleRatio).rounded()),
            height: max(1, (origSize.height * scaleRatio).rounded())
        )

        if image.imageOrientation == .up && scaleRatio >= 0.999 {
            return image
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    // MARK: - 2. Automatic Board Corner Detection (Neural Document + Rectangles + Grid-Angle Fallback)

    /// Detects candidate board quadrilaterals in the photo using:
    /// 1. Apple Vision's neural `VNDetectDocumentSegmentationRequest` (handles perspective tilt, shadows, wood-on-wood)
    /// 2. `VNDetectRectanglesRequest` (standard + contrast-enhanced pass)
    /// 3. Gradient-orientation grid-line bounding quad (finds rotated/close-up Go grids even without a visible outer border)
    /// 4. Centered square fallback
    static func detectCandidateBoardQuads(in image: UIImage, maxCandidates: Int = 6) -> [BoardCornerQuad] {
        let upright = normalizedUpImage(image, maxDimension: 1200)
        var candidates: [BoardCornerQuad] = []

        func appendIfUnique(_ quad: BoardCornerQuad) {
            let clamped = quad.clamped()
            guard isValidConvexBoardQuad(clamped) else { return }
            if !candidates.contains(where: { quadsAreNearlyEqual($0, clamped) }) {
                candidates.append(clamped)
            }
        }

        if let cgImage = upright.cgImage {
            // Pass A: Standard Rectangle Detection (relaxed perspective tolerance for handheld shots)
            for quad in detectVisionRectangles(in: cgImage, maxCount: 4) {
                appendIfUnique(quad)
                if candidates.count >= maxCandidates { break }
            }

            // Pass B: Neural Document Segmentation (on-device Vision ML model, very robust to shadows & tilt)
            let docRequest = VNDetectDocumentSegmentationRequest()
            let docHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            if (try? docHandler.perform([docRequest])) != nil,
               let docObs = docRequest.results?.first {
                let quad = quadFromObservation(docObs)
                appendIfUnique(quad)
            }

            // Pass C: Contrast-enhanced Rectangle Detection (helps light wooden board on light wooden desk)
            if candidates.count < maxCandidates,
               let boosted = contrastEnhancedCGImage(from: cgImage) {
                for quad in detectVisionRectangles(in: boosted, maxCount: 2) {
                    appendIfUnique(quad)
                    if candidates.count >= maxCandidates { break }
                }
            }
        }

        // Pass D: Go-grid-specific gradient-orientation detector (handles rotated & close-up boards where outer border is invisible)
        if let gridAngleQuad = detectGridOrientationQuad(in: upright) {
            appendIfUnique(gridAngleQuad)
        }

        // Pass E: Full-frame & centered square fallbacks
        let fullFrame = BoardCornerQuad(
            topLeft: CGPoint(x: 0.02, y: 0.02),
            topRight: CGPoint(x: 0.98, y: 0.02),
            bottomRight: CGPoint(x: 0.98, y: 0.98),
            bottomLeft: CGPoint(x: 0.02, y: 0.98)
        )
        appendIfUnique(fullFrame)
        appendIfUnique(defaultSquareQuad(for: upright.size))
        return Array(candidates.prefix(maxCandidates + 2))
    }

    private static func quadFromObservation(_ rect: VNRectangleObservation) -> BoardCornerQuad {
        // Vision uses bottom-left origin; convert to top-left origin for SwiftUI display
        let tl = CGPoint(x: rect.topLeft.x, y: 1.0 - rect.topLeft.y)
        let tr = CGPoint(x: rect.topRight.x, y: 1.0 - rect.topRight.y)
        let br = CGPoint(x: rect.bottomRight.x, y: 1.0 - rect.bottomRight.y)
        let bl = CGPoint(x: rect.bottomLeft.x, y: 1.0 - rect.bottomLeft.y)
        return orderCornersClockwise([tl, tr, br, bl]).clamped()
    }

    private static func detectVisionRectangles(in cgImage: CGImage, maxCount: Int) -> [BoardCornerQuad] {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.45
        request.maximumAspectRatio = 1.0
        request.quadratureTolerance = 40.0
        request.minimumSize = 0.18
        request.minimumConfidence = 0.28
        request.maximumObservations = 10

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observations = request.results, !observations.isEmpty else {
            return []
        }
        return observations
            .sorted { rectangleScore($0) > rectangleScore($1) }
            .prefix(maxCount)
            .map { quadFromObservation($0) }
    }

    private static func contrastEnhancedCGImage(from cgImage: CGImage) -> CGImage? {
        let ci = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(1.45, forKey: kCIInputContrastKey)
        filter.setValue(1.25, forKey: kCIInputSaturationKey)
        guard let out = filter.outputImage else { return nil }
        return ciContext.createCGImage(out, from: out.extent)
    }

    private static func isValidConvexBoardQuad(_ q: BoardCornerQuad) -> Bool {
        let topW = hypot(q.topRight.x - q.topLeft.x, q.topRight.y - q.topLeft.y)
        let botW = hypot(q.bottomRight.x - q.bottomLeft.x, q.bottomRight.y - q.bottomLeft.y)
        let leftH = hypot(q.bottomLeft.x - q.topLeft.x, q.bottomLeft.y - q.topLeft.y)
        let rightH = hypot(q.bottomRight.x - q.topRight.x, q.bottomRight.y - q.topRight.y)
        return min(topW, botW) >= 0.15 && min(leftH, rightH) >= 0.15
    }

    /// Finds the dominant orthogonal Go grid angle using a fast Sobel orientation histogram,
    /// then projects dark-ridge energy along both axes to locate the outer grid bounds even when
    /// the photo is rotated or the outer wooden border blends into the table.
    private static func detectGridOrientationQuad(in image: UIImage) -> BoardCornerQuad? {
        let small = normalizedUpImage(image, maxDimension: 320)
        guard let cg = small.cgImage, let rgba = extractRGBA(from: cg) else { return nil }
        let w = rgba.width
        let h = rgba.height
        guard w >= 80, h >= 80 else { return nil }

        var luma = [Double](repeating: 0.0, count: w * h)
        for i in 0..<(w * h) {
            let off = i * 4
            luma[i] = 0.299 * Double(rgba.bytes[off]) / 255.0
                + 0.587 * Double(rgba.bytes[off + 1]) / 255.0
                + 0.114 * Double(rgba.bytes[off + 2]) / 255.0
        }

        // Step 1: 1-degree orientation histogram in [0, 90) degrees (orthogonal grid lines fold onto the same bin!)
        var hist = [Double](repeating: 0.0, count: 90)
        let step = 2
        for y in stride(from: 2, to: h - 2, by: step) {
            let row = y * w
            let up = (y - 1) * w
            let dn = (y + 1) * w
            for x in stride(from: 2, to: w - 2, by: step) {
                let gx = (luma[up + x + 1] + 2 * luma[row + x + 1] + luma[dn + x + 1])
                    - (luma[up + x - 1] + 2 * luma[row + x - 1] + luma[dn + x - 1])
                let gy = (luma[dn + x - 1] + 2 * luma[dn + x] + luma[dn + x + 1])
                    - (luma[up + x - 1] + 2 * luma[up + x] + luma[up + x + 1])
                let mag = hypot(gx, gy)
                guard mag > 0.12 else { continue }
                // Edge tangent angle folded into [0, 90) degrees
                var deg = atan2(gy, gx) * 180.0 / .pi
                deg = deg.truncatingRemainder(dividingBy: 90.0)
                if deg < 0 { deg += 90.0 }
                let bin = Int(deg.rounded()) % 90
                hist[bin] += mag
            }
        }

        // Smooth circular 90-bin histogram and find dominant angle
        var bestBin = 0
        var bestVal = 0.0
        for b in 0..<90 {
            let prev = hist[(b + 89) % 90]
            let next = hist[(b + 1) % 90]
            let v = prev * 0.25 + hist[b] * 0.5 + next * 0.25
            if v > bestVal {
                bestVal = v
                bestBin = b
            }
        }
        guard bestVal > 0 else { return nil }

        // Convert to smallest rotation angle in [-45, +45] degrees
        let thetaDeg = bestBin > 45 ? Double(bestBin - 90) : Double(bestBin)
        let theta = thetaDeg * .pi / 180.0
        let cosT = cos(theta)
        let sinT = sin(theta)

        // Step 2: Project dark-ridge pixels onto rotated axes (u, v) centered at image center
        let cx = Double(w) * 0.5
        let cy = Double(h) * 0.5
        let diag = Int(ceil(hypot(Double(w), Double(h))))
        let halfDiag = diag / 2
        var uProj = [Double](repeating: 0.0, count: diag)
        var vProj = [Double](repeating: 0.0, count: diag)

        let d = 3
        for y in d..<(h - d) {
            let row = y * w
            for x in d..<(w - d) {
                let c = luma[row + x]
                let hFlank = min(luma[(y - d) * w + x], luma[(y + d) * w + x])
                let vFlank = min(luma[row + x - d], luma[row + x + d])
                let ridge = max(hFlank > 0.20 ? (hFlank - c) : 0, vFlank > 0.20 ? (vFlank - c) : 0)
                guard ridge > 0.035 else { continue }
                let dx = Double(x) - cx
                let dy = Double(y) - cy
                let u = dx * cosT + dy * sinT
                let v = -dx * sinT + dy * cosT
                let ui = Int(u.rounded()) + halfDiag
                let vi = Int(v.rounded()) + halfDiag
                let weight = min(ridge, 0.4)
                if ui >= 0 && ui < diag { uProj[ui] += weight }
                if vi >= 0 && vi < diag { vProj[vi] += weight }
            }
        }

        // Step 3: Find outermost strong ridge peaks along u and v (first & last grid lines)
        guard let (uMin, uMax) = findOuterPeakSpan(in: uProj, halfDiag: halfDiag),
              let (vMin, vMax) = findOuterPeakSpan(in: vProj, halfDiag: halfDiag) else {
            return nil
        }

        let uSpan = uMax - uMin
        let vSpan = vMax - vMin
        guard uSpan >= Double(min(w, h)) * 0.30, vSpan >= Double(min(w, h)) * 0.30 else { return nil }
        // Add 4% outer margin so corner stones are inside the quad
        let padU = uSpan * 0.045
        let padV = vSpan * 0.045

        func toNormImagePoint(u: Double, v: Double) -> CGPoint {
            let px = cx + u * cosT - v * sinT
            let py = cy + u * sinT + v * cosT
            return CGPoint(x: px / Double(w), y: py / Double(h))
        }

        let p1 = toNormImagePoint(u: uMin - padU, v: vMin - padV)
        let p2 = toNormImagePoint(u: uMax + padU, v: vMin - padV)
        let p3 = toNormImagePoint(u: uMax + padU, v: vMax + padV)
        let p4 = toNormImagePoint(u: uMin - padU, v: vMax + padV)
        return orderCornersClockwise([p1, p2, p3, p4]).clamped()
    }

    private static func findOuterPeakSpan(in proj: [Double], halfDiag: Int) -> (Double, Double)? {
        guard let maxVal = proj.max(), maxVal > 0.5 else { return nil }
        let threshold = maxVal * 0.28
        var firstIdx: Int?
        var lastIdx: Int?
        for i in 2..<(proj.count - 2) {
            if proj[i] >= threshold && proj[i] >= proj[i - 1] && proj[i] >= proj[i + 1] {
                if firstIdx == nil { firstIdx = i }
                lastIdx = i
            }
        }
        guard let lo = firstIdx, let hi = lastIdx, hi - lo >= 30 else { return nil }
        return (Double(lo - halfDiag), Double(hi - halfDiag))
    }

    /// Detects the largest square-ish board quadrilateral in the photo using Vision's `VNDetectRectanglesRequest`.
    /// Returns corners in top-left-origin normalized coordinates `[0, 1]`.
    static func detectBoardCorners(in image: UIImage) -> BoardCornerQuad {
        detectCandidateBoardQuads(in: image, maxCandidates: 1).first ?? defaultSquareQuad(for: image.size)
    }

    /// One-shot auto-detection: evaluates Vision neural document + rectangle candidates + grid-angle quad,
    /// picks the quad that actually contains the clearest Go grid (so a wooden table doesn't beat the board),
    /// identifies the board size (19×19 / 13×13 / 9×9 / 7×7), and snaps the 4 corners tightly onto the grid.
    static func autoDetectBoardAndGrid(
        in image: UIImage,
        candidates: [BoardSize] = [.nineteen, .thirteen, .nine, .seven]
    ) -> AutoBoardDetectionResult {
        let upright = normalizedUpImage(image, maxDimension: 1400)
        let quadCandidates = detectCandidateBoardQuads(in: upright, maxCandidates: 5)

        var bestResult: AutoBoardDetectionResult?
        var bestCombinedScore: Double = -Double.infinity

        for (index, quad) in quadCandidates.enumerated() {
            let gridInfo = detectBoardGridStructure(
                from: upright,
                corners: quad,
                candidates: candidates,
                snapCorners: true
            )
            // Small preference for higher-ranked Vision quads when grid scores are tied
            let priorBonus = index == 0 ? 0.02 : 0.0
            let totalScore = gridInfo.confidence + priorBonus

            if totalScore > bestCombinedScore {
                bestCombinedScore = totalScore
                bestResult = AutoBoardDetectionResult(
                    corners: gridInfo.refinedCorners ?? quad,
                    boardSize: gridInfo.boardSize,
                    gridInsetFraction: gridInfo.gridInsetFraction,
                    confidence: gridInfo.confidence
                )
            }
        }

        if let bestResult {
            return bestResult
        }

        let fallbackQuad = defaultSquareQuad(for: upright.size)
        return AutoBoardDetectionResult(
            corners: fallbackQuad,
            boardSize: candidates.first ?? .nineteen,
            gridInsetFraction: 0.045,
            confidence: 0.2
        )
    }

    private static func quadsAreNearlyEqual(_ a: BoardCornerQuad, _ b: BoardCornerQuad) -> Bool {
        let tol: CGFloat = 0.03
        return abs(a.topLeft.x - b.topLeft.x) < tol
            && abs(a.topLeft.y - b.topLeft.y) < tol
            && abs(a.topRight.x - b.topRight.x) < tol
            && abs(a.topRight.y - b.topRight.y) < tol
            && abs(a.bottomRight.x - b.bottomRight.x) < tol
            && abs(a.bottomRight.y - b.bottomRight.y) < tol
            && abs(a.bottomLeft.x - b.bottomLeft.x) < tol
            && abs(a.bottomLeft.y - b.bottomLeft.y) < tol
    }

    private static func rectangleScore(_ obs: VNRectangleObservation) -> Double {
        let w = Double(obs.boundingBox.width)
        let h = Double(obs.boundingBox.height)
        let area = w * h
        let aspect = min(w, h) / max(1e-6, max(w, h))
        let centerDist = hypot(Double(obs.boundingBox.midX) - 0.5, Double(obs.boundingBox.midY) - 0.5)
        let centerBonus = max(0.0, 1.0 - centerDist)
        // Strongly favor the full outer board (large area + near-square) over small inner sub-rectangles
        return area * 2.8 + aspect * 0.45 + Double(obs.confidence) * 0.35 + centerBonus * 0.25
    }

    private static func defaultSquareQuad(for size: CGSize) -> BoardCornerQuad {
        guard size.width > 0, size.height > 0 else { return .defaultCentered }
        let aspect = size.width / size.height
        let halfW: CGFloat
        let halfH: CGFloat
        if aspect >= 1.0 {
            halfH = 0.38
            halfW = min(0.42, halfH / aspect)
        } else {
            halfW = 0.38
            halfH = min(0.42, halfW * aspect)
        }
        return BoardCornerQuad(
            topLeft: CGPoint(x: 0.5 - halfW, y: 0.5 - halfH),
            topRight: CGPoint(x: 0.5 + halfW, y: 0.5 - halfH),
            bottomRight: CGPoint(x: 0.5 + halfW, y: 0.5 + halfH),
            bottomLeft: CGPoint(x: 0.5 - halfW, y: 0.5 + halfH)
        )
    }

    /// Ensures 4 corners are strictly ordered as (topLeft, topRight, bottomRight, bottomLeft).
    static func orderCornersClockwise(_ pts: [CGPoint]) -> BoardCornerQuad {
        guard pts.count == 4 else { return .defaultCentered }
        let sortedBySum = pts.sorted { ($0.x + $0.y) < ($1.x + $1.y) }
        let tl = sortedBySum[0]
        let br = sortedBySum[3]
        let remaining = [sortedBySum[1], sortedBySum[2]]
        let sortedByDiff = remaining.sorted { ($0.x - $0.y) < ($1.x - $1.y) }
        let bl = sortedByDiff[0]
        let tr = sortedByDiff[1]
        return BoardCornerQuad(topLeft: tl, topRight: tr, bottomRight: br, bottomLeft: bl)
    }

    // MARK: - 3. Perspective Unwarp (CoreImage)

    /// Warps the quadrilateral region of `image` into a flat top-down square bitmap.
    static func warpBoard(
        image: UIImage,
        corners: BoardCornerQuad,
        outputSide: Int = 760
    ) -> UIImage? {
        let upright = normalizedUpImage(image, maxDimension: 1600)
        guard let cgImage = upright.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        let w = extent.width
        let h = extent.height

        // Convert top-left normalized points to CoreImage bottom-left pixel vectors
        func toCIVector(_ p: CGPoint) -> CIVector {
            CIVector(x: p.x * w, y: (1.0 - p.y) * h)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(toCIVector(corners.topLeft), forKey: "inputTopLeft")
        filter.setValue(toCIVector(corners.topRight), forKey: "inputTopRight")
        filter.setValue(toCIVector(corners.bottomRight), forKey: "inputBottomRight")
        filter.setValue(toCIVector(corners.bottomLeft), forKey: "inputBottomLeft")

        guard let corrected = filter.outputImage else { return nil }
        let corrExtent = corrected.extent
        guard corrExtent.width > 4, corrExtent.height > 4 else { return nil }

        // Scale to exact square outputSide x outputSide
        let scaleX = CGFloat(outputSide) / corrExtent.width
        let scaleY = CGFloat(outputSide) / corrExtent.height
        let normalized = corrected
            .transformed(by: CGAffineTransform(translationX: -corrExtent.origin.x, y: -corrExtent.origin.y))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let outRect = CGRect(x: 0, y: 0, width: outputSide, height: outputSide)
        guard let outCG = ciContext.createCGImage(normalized, from: outRect) else { return nil }
        return UIImage(cgImage: outCG, scale: 1.0, orientation: .up)
    }

    // MARK: - 3.5 Automatic Board Size (19×19 / 13×13 / 9×9 / 7×7) & Grid-Snap Detection

    /// Automatically detects whether a warped Go board photo is 19×19, 13×13, 9×9, or 7×7,
    /// locates its exact outer grid bounds (handling asymmetric borders & slight corner offsets),
    /// and optionally returns refined 4-corner coordinates snapped tightly onto the grid.
    static func detectBoardGridStructure(
        from image: UIImage,
        corners: BoardCornerQuad,
        candidates: [BoardSize] = [.nineteen, .thirteen, .nine, .seven],
        snapCorners: Bool = false
    ) -> DetectedGridStructure {
        let side = 540
        let warped = warpBoard(image: image, corners: corners, outputSide: side) ?? normalizedUpImage(image, maxDimension: CGFloat(side))
        guard let cgImage = warped.cgImage,
              let rgba = extractRGBA(from: cgImage) else {
            return DetectedGridStructure(boardSize: candidates.first ?? .nineteen, gridInsetFraction: 0.045, confidence: 0.0)
        }

        let w = rgba.width
        let h = rgba.height
        guard w >= 120, h >= 120 else {
            return DetectedGridStructure(boardSize: candidates.first ?? .nineteen, gridInsetFraction: 0.045, confidence: 0.0)
        }

        // Precompute grayscale luminance buffer
        var luma = [Double](repeating: 0.0, count: w * h)
        for i in 0..<(w * h) {
            let off = i * 4
            luma[i] = 0.299 * Double(rgba.bytes[off]) / 255.0
                + 0.587 * Double(rgba.bytes[off + 1]) / 255.0
                + 0.114 * Double(rgba.bytes[off + 2]) / 255.0
        }

        // Multi-scale stone-invariant dark-ridge projection:
        // A grid line is a thin dark valley (1-6px) flanked by brighter wood at +-d1 or +-d2 pixels.
        // Interiors of black stones (dark on both sides) and white stones (bright on both sides) cancel to ~0.
        let d1 = max(2, Int((Double(min(w, h)) / 180.0).rounded()))
        let d2 = max(d1 + 2, Int((Double(min(w, h)) / 92.0).rounded()))
        let marginX = max(d2 + 2, w / 28)
        let marginY = max(d2 + 2, h / 28)

        var rowProfile = [Double](repeating: 0.0, count: h)
        var colProfile = [Double](repeating: 0.0, count: w)

        for y in d2..<(h - d2) {
            var rowSum = 0.0
            let rowOff = y * w
            let up1 = (y - d1) * w
            let dn1 = (y + d1) * w
            let up2 = (y - d2) * w
            let dn2 = (y + d2) * w
            for x in marginX..<(w - marginX) {
                let center = luma[rowOff + x]
                var ridge = 0.0
                let flank1 = min(luma[up1 + x], luma[dn1 + x])
                if flank1 > 0.18 {
                    ridge = max(ridge, flank1 - center)
                }
                let flank2 = min(luma[up2 + x], luma[dn2 + x])
                if flank2 > 0.18 {
                    ridge = max(ridge, flank2 - center)
                }
                if ridge > 0.025 {
                    rowSum += min(ridge, 0.45)
                }
            }
            rowProfile[y] = rowSum / Double(max(1, w - 2 * marginX))
        }

        for x in d2..<(w - d2) {
            var colSum = 0.0
            for y in marginY..<(h - marginY) {
                let rowOff = y * w
                let center = luma[rowOff + x]
                var ridge = 0.0
                let flank1 = min(luma[rowOff + x - d1], luma[rowOff + x + d1])
                if flank1 > 0.18 {
                    ridge = max(ridge, flank1 - center)
                }
                let flank2 = min(luma[rowOff + x - d2], luma[rowOff + x + d2])
                if flank2 > 0.18 {
                    ridge = max(ridge, flank2 - center)
                }
                if ridge > 0.025 {
                    colSum += min(ridge, 0.45)
                }
            }
            colProfile[x] = colSum / Double(max(1, h - 2 * marginY))
        }

        normalizeProfile(&rowProfile)
        normalizeProfile(&colProfile)

        struct CandidateFit {
            let size: BoardSize
            let score: Double
            let xFit: (score: Double, startFrac: Double, endFrac: Double)
            let yFit: (score: Double, startFrac: Double, endFrac: Double)
        }

        var fits: [CandidateFit] = []
        fits.reserveCapacity(candidates.count)

        for candidate in candidates {
            let n = candidate.rawValue
            let xFit = findBestAxisFit(profile: colProfile, lineCount: n)
            let yFit = findBestAxisFit(profile: rowProfile, lineCount: n)
            // Combine both axes and reward consistent aspect/span between X and Y
            let spanDiff = abs((xFit.endFrac - xFit.startFrac) - (yFit.endFrac - yFit.startFrac))
            let combined = (xFit.score + yFit.score) * 0.5 - spanDiff * 0.15
            fits.append(CandidateFit(size: candidate, score: combined, xFit: xFit, yFit: yFit))
        }

        fits.sort { $0.score > $1.score }
        guard let top = fits.first, top.score > 0.08 else {
            return DetectedGridStructure(
                boardSize: candidates.first ?? .nineteen,
                gridInsetFraction: 0.045,
                confidence: 0.2,
                refinedCorners: nil
            )
        }

        let secondScore = fits.count > 1 ? fits[1].score : 0.0
        let margin = max(0.0, top.score - max(0.0, secondScore))
        let conf = min(0.99, max(0.38, 0.42 + top.score * 0.42 + margin * 1.15))

        let avgInset = (top.xFit.startFrac + (1.0 - top.xFit.endFrac) + top.yFit.startFrac + (1.0 - top.yFit.endFrac)) * 0.25
        let clampedInset = CGFloat(min(0.12, max(0.0, avgInset)))

        if snapCorners && conf >= 0.45 {
            let (snappedQuad, snappedInset) = snapQuadToDetectedBounds(
                corners: corners,
                uStart: top.xFit.startFrac,
                uEnd: top.xFit.endFrac,
                vStart: top.yFit.startFrac,
                vEnd: top.yFit.endFrac
            )
            return DetectedGridStructure(
                boardSize: top.size,
                gridInsetFraction: snappedInset,
                confidence: conf,
                refinedCorners: snappedQuad
            )
        }

        return DetectedGridStructure(
            boardSize: top.size,
            gridInsetFraction: clampedInset,
            confidence: conf,
            refinedCorners: nil
        )
    }

    private static func findBestAxisFit(profile: [Double], lineCount n: Int) -> (score: Double, startFrac: Double, endFrac: Double) {
        var bestScore = -Double.infinity
        var bestStart = 0.045
        var bestEnd = 0.955

        // Pass 1: Coarse asymmetric search over start in [0.00, 0.22] and end in [0.78, 1.00]
        for sStep in 0...22 {
            let s = Double(sStep) * 0.01
            for eStep in 78...100 {
                let e = Double(eStep) * 0.01
                guard e - s >= 0.58 else { continue }
                let score = axisGridAlignmentScore(profile: profile, lineCount: n, startFrac: s, endFrac: e)
                if score > bestScore {
                    bestScore = score
                    bestStart = s
                    bestEnd = e
                }
            }
        }

        // Pass 2: Fine refinement (+-0.012 in 0.002 increments)
        let refinedStartCenter = bestStart
        let refinedEndCenter = bestEnd
        for ds in -6...6 {
            let s = min(0.25, max(0.0, refinedStartCenter + Double(ds) * 0.002))
            for de in -6...6 {
                let e = min(1.0, max(0.75, refinedEndCenter + Double(de) * 0.002))
                guard e - s >= 0.55 else { continue }
                let score = axisGridAlignmentScore(profile: profile, lineCount: n, startFrac: s, endFrac: e)
                if score > bestScore {
                    bestScore = score
                    bestStart = s
                    bestEnd = e
                }
            }
        }

        return (bestScore, bestStart, bestEnd)
    }

    private static func snapQuadToDetectedBounds(
        corners: BoardCornerQuad,
        uStart: Double,
        uEnd: Double,
        vStart: Double,
        vEnd: Double
    ) -> (BoardCornerQuad, CGFloat) {
        let uSpan = max(0.2, uEnd - uStart)
        let vSpan = max(0.2, vEnd - vStart)

        // Prefer a clean 4% uniform margin so corner stones are never clipped on the bitmap edge.
        // Shrink the margin gracefully if the board reaches the very edge of the photo.
        for candidateInset in [0.04, 0.025, 0.01, 0.0] {
            let factor = candidateInset / max(0.5, 1.0 - 2.0 * candidateInset)
            let u0 = CGFloat(uStart - uSpan * factor)
            let u1 = CGFloat(uEnd + uSpan * factor)
            let v0 = CGFloat(vStart - vSpan * factor)
            let v1 = CGFloat(vEnd + vSpan * factor)

            let tl = corners.point(u: u0, v: v0)
            let tr = corners.point(u: u1, v: v0)
            let br = corners.point(u: u1, v: v1)
            let bl = corners.point(u: u0, v: v1)

            let allInside = [tl, tr, br, bl].allSatisfy { p in
                p.x >= 0.005 && p.x <= 0.995 && p.y >= 0.005 && p.y <= 0.995
            }
            if allInside || candidateInset == 0.0 {
                let snapped = BoardCornerQuad(
                    topLeft: tl,
                    topRight: tr,
                    bottomRight: br,
                    bottomLeft: bl
                ).clamped()
                return (snapped, CGFloat(candidateInset))
            }
        }

        return (corners, 0.04)
    }

    private static func normalizeProfile(_ profile: inout [Double]) {
        guard !profile.isEmpty else { return }
        let sorted = profile.sorted()
        let p98 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.985))]
        guard p98 > 1e-6 else { return }
        for i in 0..<profile.count {
            profile[i] = min(1.5, profile[i] / p98)
        }
    }

    private static func axisGridAlignmentScore(
        profile: [Double],
        lineCount n: Int,
        startFrac: Double,
        endFrac: Double
    ) -> Double {
        let len = profile.count
        guard n >= 5, len > 40 else { return -1.0 }
        let start = startFrac * Double(len - 1)
        let end = endFrac * Double(len - 1)
        let span = end - start
        let step = span / Double(n - 1)
        guard step >= 10.0 else { return -1.0 }

        let lineTol = max(2, min(4, Int((step * 0.08).rounded())))
        let subTol = max(1, min(3, Int((step * 0.07).rounded())))

        @inline(__always)
        func localPeak(around pos: Double, tol: Int) -> Double {
            let center = Int(pos.rounded())
            let lo = max(0, center - tol)
            let hi = min(len - 1, center + tol)
            var peak = 0.0
            for idx in lo...hi {
                if profile[idx] > peak { peak = profile[idx] }
            }
            return peak
        }

        var lineSum = 0.0
        var hitCount = 0
        for k in 0..<n {
            let peak = localPeak(around: start + Double(k) * step, tol: lineTol)
            lineSum += peak
            if peak > 0.22 {
                hitCount += 1
            }
        }

        // Harmonic-safe interior penalty:
        // Checks 1/2 (blocks 7x7 matching 13x13) AND 1/3 & 2/3 (blocks 7x7 matching 19x19)
        var interiorPenaltySum = 0.0
        for k in 0..<(n - 1) {
            let base = start + Double(k) * step
            let halfPeak = localPeak(around: base + step * 0.5, tol: subTol)
            let third1 = localPeak(around: base + step / 3.0, tol: subTol)
            let third2 = localPeak(around: base + (2.0 * step) / 3.0, tol: subTol)
            let harmonicPeak = max(halfPeak, (third1 + third2) * 0.5)
            interiorPenaltySum += harmonicPeak
        }

        // Exterior-line penalty:
        // Prevents a smaller board (e.g. 9×9) from falsely matching an interior sub-grid
        // of a larger board (e.g. lines 2...10 of a 13×13 board). If there is a real grid line
        // one step outside `start` or `end`, this candidate is only a cropped sub-grid!
        var exteriorPenalty = 0.0
        let leftOut = start - step
        if leftOut >= Double(lineTol) {
            exteriorPenalty += localPeak(around: leftOut, tol: lineTol)
        }
        let rightOut = end + step
        if rightOut <= Double(len - 1 - lineTol) {
            exteriorPenalty += localPeak(around: rightOut, tol: lineTol)
        }

        let meanLine = lineSum / Double(n)
        let meanInterior = interiorPenaltySum / Double(n - 1)
        let coverage = Double(hitCount) / Double(n)
        let raw = meanLine - 1.25 * meanInterior - 0.65 * exteriorPenalty
        return raw * (0.45 + 0.55 * coverage)
    }

    // MARK: - 4. Full Board Stone Recognition Pipeline

    /// Recognizes all stones on a Go board photo completely offline.
    /// - Parameters:
    ///   - image: Original photo from Camera or Photo Library.
    ///   - corners: 4 board outer corners (auto-detected or user-adjusted).
    ///   - boardSize: Target Go board size (9×9, 13×13, 19×19, etc.).
    ///   - gridInsetFraction: Fraction of board width between the outer physical board edge and the outermost grid line (typically 0.03–0.07).
    ///   - komi: Komi to store on the resulting `GoBoardState`.
    static func recognizeBoard(
        from image: UIImage,
        corners: BoardCornerQuad,
        boardSize: BoardSize,
        gridInsetFraction: CGFloat = 0.045,
        komi: Double? = nil
    ) -> BoardRecognitionResult {
        let outputSide = 760
        let warped = warpBoard(image: image, corners: corners, outputSide: outputSide) ?? normalizedUpImage(image, maxDimension: CGFloat(outputSide))
        let effectiveKomi = komi ?? boardSize.defaultKomi

        guard let cgImage = warped.cgImage,
              let rgba = extractRGBA(from: cgImage) else {
            return BoardRecognitionResult(
                boardState: GoBoardState(size: boardSize.rawValue, komi: effectiveKomi),
                warpedBoardImage: warped,
                blackStoneCount: 0,
                whiteStoneCount: 0,
                averageConfidence: 0.0,
                lowConfidencePoints: [],
                detectedCorners: corners
            )
        }

        let n = boardSize.rawValue
        let width = rgba.width
        let height = rgba.height
        let inset = min(0.18, max(0.0, gridInsetFraction))
        let startX = Double(width) * Double(inset)
        let startY = Double(height) * Double(inset)
        let spanX = Double(width) * (1.0 - 2.0 * Double(inset))
        let spanY = Double(height) * (1.0 - 2.0 * Double(inset))
        let stepX = n > 1 ? spanX / Double(n - 1) : spanX
        let stepY = n > 1 ? spanY / Double(n - 1) : spanY
        let cellStep = min(stepX, stepY)
        let sampleRadius = max(3, Int((cellStep * 0.30).rounded()))

        // Step A: Measure local cell features at every intersection
        var features: [CellFeatures] = []
        features.reserveCapacity(n * n)

        for r in 0..<n {
            for c in 0..<n {
                let cx = Int((startX + Double(c) * stepX).rounded())
                let cy = Int((startY + Double(r) * stepY).rounded())
                let feat = sampleDisk(
                    rgba: rgba,
                    cx: cx,
                    cy: cy,
                    radius: sampleRadius
                )
                features.append(feat)
            }
        }

        // Step B: Estimate the board's empty wood/surface reference from mid-tone, warm/saturated cells
        let woodRef = estimateWoodReference(from: features)

        // Step C: Classify every intersection relative to the adaptive wood reference
        var grid: [StoneColor?] = Array(repeating: nil, count: n * n)
        var blackCount = 0
        var whiteCount = 0
        var confidenceSum = 0.0
        var lowConfidence: [BoardPoint] = []

        for idx in 0..<(n * n) {
            let f = features[idx]
            let (stone, conf) = classifyCell(f, wood: woodRef)
            grid[idx] = stone
            if stone == .black { blackCount += 1 }
            else if stone == .white { whiteCount += 1 }
            confidenceSum += conf
            if conf < 0.62 {
                lowConfidence.append(BoardPoint(row: idx / n, col: idx % n))
            }
        }

        var state = GoBoardState(size: n, komi: effectiveKomi)
        state.grid = grid

        return BoardRecognitionResult(
            boardState: state,
            warpedBoardImage: warped,
            blackStoneCount: blackCount,
            whiteStoneCount: whiteCount,
            averageConfidence: confidenceSum / Double(max(1, n * n)),
            lowConfidencePoints: lowConfidence,
            detectedCorners: corners
        )
    }

    // MARK: - Pixel Sampling & Adaptive Classification

    private struct RGBABuffer {
        let width: Int
        let height: Int
        let bytes: [UInt8]
    }

    private struct CellFeatures {
        let medianLuma: Double
        let darkRatio: Double
        let brightRatio: Double
        let meanSat: Double
        let meanR: Double
        let meanG: Double
        let meanB: Double
        let lumaIQR: Double
    }

    private struct WoodReference {
        let luma: Double
        let r: Double
        let g: Double
        let b: Double
        let sat: Double
    }

    private static func extractRGBA(from cgImage: CGImage) -> RGBABuffer? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let ctx = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return RGBABuffer(width: width, height: height, bytes: bytes)
    }

    private static func sampleDisk(
        rgba: RGBABuffer,
        cx: Int,
        cy: Int,
        radius: Int
    ) -> CellFeatures {
        let r2 = radius * radius
        var lumas: [Double] = []
        lumas.reserveCapacity(r2 * 4)

        var darkCount = 0
        var brightCount = 0
        var sumSat = 0.0
        var sumR = 0.0
        var sumG = 0.0
        var sumB = 0.0

        let minY = max(0, cy - radius)
        let maxY = min(rgba.height - 1, cy + radius)
        let minX = max(0, cx - radius)
        let maxX = min(rgba.width - 1, cx + radius)

        for y in minY...maxY {
            let dy = y - cy
            let rowOffset = y * rgba.width * 4
            for x in minX...maxX {
                let dx = x - cx
                if dx * dx + dy * dy > r2 { continue }

                let offset = rowOffset + x * 4
                let r = Double(rgba.bytes[offset]) / 255.0
                let g = Double(rgba.bytes[offset + 1]) / 255.0
                let b = Double(rgba.bytes[offset + 2]) / 255.0

                let luma = 0.299 * r + 0.587 * g + 0.114 * b
                let maxC = max(r, max(g, b))
                let minC = min(r, min(g, b))
                let sat = maxC > 0.001 ? (maxC - minC) / maxC : 0.0

                lumas.append(luma)
                if luma < 0.30 { darkCount += 1 }
                if luma > 0.74 { brightCount += 1 }
                sumSat += sat
                sumR += r
                sumG += g
                sumB += b
            }
        }

        let count = max(1, lumas.count)
        lumas.sort()
        let med = lumas.isEmpty ? 0.5 : lumas[lumas.count / 2]
        let q25 = lumas.isEmpty ? 0.5 : lumas[lumas.count / 4]
        let q75 = lumas.isEmpty ? 0.5 : lumas[(lumas.count * 3) / 4]

        return CellFeatures(
            medianLuma: med,
            darkRatio: Double(darkCount) / Double(count),
            brightRatio: Double(brightCount) / Double(count),
            meanSat: sumSat / Double(count),
            meanR: sumR / Double(count),
            meanG: sumG / Double(count),
            meanB: sumB / Double(count),
            lumaIQR: q75 - q25
        )
    }

    private static func estimateWoodReference(
        from features: [CellFeatures]
    ) -> WoodReference {
        // Empty wooden intersections are typically mid-luminance (0.34...0.82) and warmer/more saturated than black/white stones.
        let candidates = features.filter {
            $0.medianLuma >= 0.32 && $0.medianLuma <= 0.84 && $0.darkRatio < 0.45 && $0.brightRatio < 0.72
        }

        let pool = candidates.isEmpty ? features : candidates
        // Prefer the top half most saturated mid-tone cells (wood grain is warm; white/black stones are achromatic)
        let sortedBySat = pool.sorted { $0.meanSat > $1.meanSat }
        let topWood = Array(sortedBySat.prefix(max(1, sortedBySat.count / 2)))

        let luma = median(topWood.map(\.medianLuma))
        let r = median(topWood.map(\.meanR))
        let g = median(topWood.map(\.meanG))
        let b = median(topWood.map(\.meanB))
        let sat = median(topWood.map(\.meanSat))

        return WoodReference(luma: luma, r: r, g: g, b: b, sat: sat)
    }

    private static func classifyCell(
        _ f: CellFeatures,
        wood: WoodReference
    ) -> (StoneColor?, Double) {
        let lumaDiff = f.medianLuma - wood.luma
        let colorDist = sqrt(
            pow(f.meanR - wood.r, 2) +
            pow(f.meanG - wood.g, 2) +
            pow(f.meanB - wood.b, 2)
        )

        // 1. Black stone detection:
        // Significantly darker than wood OR majority of pixels are very dark (robust to glossy white glare dot in center!)
        let blackThreshold = min(0.38, wood.luma - 0.20)
        if f.medianLuma < blackThreshold || f.darkRatio >= 0.56 {
            let margin = max(blackThreshold - f.medianLuma, f.darkRatio - 0.50)
            let conf = min(0.99, max(0.55, 0.72 + margin * 1.4))
            return (.black, conf)
        }

        // 2. White stone detection:
        // Significantly brighter AND noticeably less saturated (more neutral/achromatic) than warm wooden board.
        let woodIsWarm = wood.sat >= 0.14
        let satDrop = wood.sat - f.meanSat
        let whiteLumaThreshold = min(0.86, max(0.68, wood.luma + 0.12))

        let isBrightEnough = f.medianLuma > whiteLumaThreshold || f.brightRatio >= 0.65
        let isNeutralEnough = woodIsWarm ? (f.meanSat < max(0.18, wood.sat * 0.62) || satDrop > 0.10) : (lumaDiff > 0.16)

        if isBrightEnough && isNeutralEnough && colorDist > 0.11 {
            let margin = max(f.medianLuma - whiteLumaThreshold, satDrop)
            let conf = min(0.99, max(0.55, 0.70 + margin * 1.3))
            return (.white, conf)
        }

        // 3. Secondary white stone check for dim lighting (white stone in shadow is still much brighter & whiter than wood)
        if lumaDiff > 0.18 && f.meanSat < 0.16 && colorDist > 0.15 {
            let conf = min(0.92, max(0.50, 0.62 + lumaDiff))
            return (.white, conf)
        }

        // 4. Empty intersection
        let distToBlack = abs(f.medianLuma - blackThreshold)
        let distToWhite = abs(f.medianLuma - whiteLumaThreshold)
        let safetyMargin = min(distToBlack, distToWhite)
        let emptyConf = min(0.98, max(0.50, 0.65 + safetyMargin * 1.5))
        return (nil, emptyConf)
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.5 }
        let s = values.sorted()
        return s[s.count / 2]
    }
}
