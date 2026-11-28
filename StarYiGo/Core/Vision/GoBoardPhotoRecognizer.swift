//
//  GoBoardPhotoRecognizer.swift
//  StarYi Go — 100% Offline On-Device Go Board Photo Recognition (Vision + CoreImage)
//

import CoreGraphics
import CoreImage
import CoreML
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

    /// Exact 3×3 projective homography mapping normalized warped coordinates (u, v) in [0, 1]²
    /// back into image space — matches `CIPerspectiveCorrection` even under steep 30°–45° handheld tilt.
    func projectivePoint(u: CGFloat, v: CGFloat) -> CGPoint {
        let x0 = Double(topLeft.x),     y0 = Double(topLeft.y)
        let x1 = Double(topRight.x),    y1 = Double(topRight.y)
        let x2 = Double(bottomRight.x), y2 = Double(bottomRight.y)
        let x3 = Double(bottomLeft.x),  y3 = Double(bottomLeft.y)

        let dx1 = x1 - x2, dy1 = y1 - y2
        let dx2 = x3 - x2, dy2 = y3 - y2
        let sx = x0 - x1 + x2 - x3
        let sy = y0 - y1 + y2 - y3

        let det = dx1 * dy2 - dx2 * dy1
        guard abs(det) > 1e-9 else {
            return point(u: u, v: v)
        }

        let g = (sx * dy2 - sy * dx2) / det
        let h = (dx1 * sy - dy1 * sx) / det
        let a = x1 - x0 + g * x1
        let b = x3 - x0 + h * x3
        let c = x0
        let d = y1 - y0 + g * y1
        let e = y3 - y0 + h * y3
        let f = y0

        let ud = Double(u)
        let vd = Double(v)
        let w = g * ud + h * vd + 1.0
        guard abs(w) > 1e-9 else {
            return point(u: u, v: v)
        }
        return CGPoint(
            x: CGFloat((a * ud + b * vd + c) / w),
            y: CGFloat((d * ud + e * vd + f) / w)
        )
    }

    func clamped() -> BoardCornerQuad {
        func clampPt(_ p: CGPoint) -> CGPoint {
            CGPoint(x: min(0.998, max(0.002, p.x)), y: min(0.998, max(0.002, p.y)))
        }
        return BoardCornerQuad(
            topLeft: clampPt(topLeft),
            topRight: clampPt(topRight),
            bottomRight: clampPt(bottomRight),
            bottomLeft: clampPt(bottomLeft)
        )
    }

    /// Returns the inner quadrilateral at normalized `inset` from all 4 edges using exact projective homography.
    func insetBy(_ inset: CGFloat) -> BoardCornerQuad {
        let i = min(0.25, max(0.0, inset))
        guard i > 1e-5 else { return self }
        return BoardCornerQuad(
            topLeft: projectivePoint(u: i, v: i),
            topRight: projectivePoint(u: 1.0 - i, v: i),
            bottomRight: projectivePoint(u: 1.0 - i, v: 1.0 - i),
            bottomLeft: projectivePoint(u: i, v: 1.0 - i)
        ).clamped()
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
    let usedNeuralStoneClassifier: Bool

    init(
        boardState: GoBoardState,
        warpedBoardImage: UIImage,
        blackStoneCount: Int,
        whiteStoneCount: Int,
        averageConfidence: Double,
        lowConfidencePoints: [BoardPoint],
        detectedCorners: BoardCornerQuad,
        usedNeuralStoneClassifier: Bool = false
    ) {
        self.boardState = boardState
        self.warpedBoardImage = warpedBoardImage
        self.blackStoneCount = blackStoneCount
        self.whiteStoneCount = whiteStoneCount
        self.averageConfidence = averageConfidence
        self.lowConfidencePoints = lowConfidencePoints
        self.detectedCorners = detectedCorners
        self.usedNeuralStoneClassifier = usedNeuralStoneClassifier
    }
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
        guard min(topW, botW) >= 0.15 && min(leftH, rightH) >= 0.15 else { return false }

        // Verify strict convexity (all 4 edge cross products share the same non-zero sign)
        let pts = [q.topLeft, q.topRight, q.bottomRight, q.bottomLeft]
        var sign = 0.0
        for i in 0..<4 {
            let a = pts[i]
            let b = pts[(i + 1) % 4]
            let c = pts[(i + 2) % 4]
            let cross = Double((b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x))
            if abs(cross) < 1e-6 { return false }
            if sign == 0.0 {
                sign = cross
            } else if cross * sign < 0 {
                return false
            }
        }
        return true
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
            autoreleasepool {
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

    /// Ensures 4 corners are strictly ordered clockwise as (topLeft, topRight, bottomRight, bottomLeft),
    /// robust even near 45° rotation or steep perspective tilt.
    static func orderCornersClockwise(_ pts: [CGPoint]) -> BoardCornerQuad {
        guard pts.count == 4 else { return .defaultCentered }
        let cx = pts.reduce(0.0) { $0 + Double($1.x) } / 4.0
        let cy = pts.reduce(0.0) { $0 + Double($1.y) } / 4.0
        // In UIKit top-left origin coordinates (y increases downward), ascending atan2(dy, dx) orders clockwise
        let cw = pts.sorted {
            atan2(Double($0.y) - cy, Double($0.x) - cx) < atan2(Double($1.y) - cy, Double($1.x) - cx)
        }
        // Rotate cyclic order so the vertex closest to (0, 0) becomes topLeft
        let tlIndex = cw.indices.min { lhs, rhs in
            let dl = cw[lhs].x * cw[lhs].x + cw[lhs].y * cw[lhs].y
            let dr = cw[rhs].x * cw[rhs].x + cw[rhs].y * cw[rhs].y
            return dl < dr
        } ?? 0
        return BoardCornerQuad(
            topLeft: cw[tlIndex],
            topRight: cw[(tlIndex + 1) % 4],
            bottomRight: cw[(tlIndex + 2) % 4],
            bottomLeft: cw[(tlIndex + 3) % 4]
        )
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
        let side = 720
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
        // A grid line is a thin dark valley (1-7px) flanked by brighter wood at +-d1 or +-d2 pixels.
        // Interiors of black stones (dark on both sides) and white stones (bright on both sides) cancel to ~0.
        let d1 = max(2, Int((Double(min(w, h)) / 200.0).rounded()))
        let d2 = max(d1 + 2, Int((Double(min(w, h)) / 100.0).rounded()))
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
                if ridge > 0.022 {
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
                if ridge > 0.022 {
                    colSum += min(ridge, 0.45)
                }
            }
            colProfile[x] = colSum / Double(max(1, h - 2 * marginY))
        }

        normalizeProfile(&rowProfile)
        normalizeProfile(&colProfile)

        // Count distinct prominent grid-line peaks along both axes to guard against coarse harmonic misdetection
        // (e.g. a 19x19 board with 18 intervals falsely matching 7x7's 6 intervals).
        let minPeakSpacing = max(12, min(w, h) / 28)
        let xPeakCount = countDistinctPeaks(in: colProfile, threshold: 0.28, minDistance: minPeakSpacing)
        let yPeakCount = countDistinctPeaks(in: rowProfile, threshold: 0.28, minDistance: minPeakSpacing)
        let minAxisPeaks = min(xPeakCount, yPeakCount)

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
            var combined = (xFit.score + yFit.score) * 0.5 - spanDiff * 0.15

            // Penalize small board candidates when both axes clearly show far more distinct grid lines
            if minAxisPeaks >= 14 && n <= 9 {
                combined -= 0.35
            } else if minAxisPeaks >= 10 && n == 7 {
                combined -= 0.28
            }

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

            let tl = corners.projectivePoint(u: u0, v: v0)
            let tr = corners.projectivePoint(u: u1, v: v0)
            let br = corners.projectivePoint(u: u1, v: v1)
            let bl = corners.projectivePoint(u: u0, v: v1)

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
        guard profile.count > 20 else { return }
        // Normalize using the interior [3%...97%] so thick dark outer wooden frames never crush interior 19x19 grid lines.
        let lo = max(0, Int(Double(profile.count) * 0.03))
        let hi = min(profile.count - 1, Int(Double(profile.count) * 0.97))
        let interiorSorted = profile[lo...hi].sorted()
        let ref = interiorSorted[min(interiorSorted.count - 1, Int(Double(interiorSorted.count) * 0.97))]
        guard ref > 1e-6 else { return }
        for i in 0..<profile.count {
            profile[i] = min(1.5, profile[i] / ref)
        }
    }

    private static func countDistinctPeaks(in profile: [Double], threshold: Double, minDistance: Int) -> Int {
        guard profile.count > 6 else { return 0 }
        var candidates: [(idx: Int, val: Double)] = []
        for i in 2..<(profile.count - 2) {
            let v = profile[i]
            if v >= threshold && v >= profile[i - 1] && v >= profile[i + 1] && v >= profile[i - 2] && v >= profile[i + 2] {
                candidates.append((i, v))
            }
        }
        // Greedy non-maximum suppression by peak strength
        candidates.sort { $0.val > $1.val }
        var accepted: [Int] = []
        for c in candidates {
            if accepted.allSatisfy({ abs($0 - c.idx) >= minDistance }) {
                accepted.append(c.idx)
            }
        }
        return accepted.count
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

        // Use a fair, line-width-based tolerance so 19x19 isn't unfairly penalized vs 7x7 under slight lens bow
        let lineTol = max(3, min(5, Int((step * 0.08).rounded())))
        let subTol = lineTol

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

        @inline(__always)
        func rangeMax(from loPos: Double, to hiPos: Double) -> Double {
            let lo = max(0, Int(loPos.rounded()))
            let hi = min(len - 1, Int(hiPos.rounded()))
            guard lo <= hi else { return 0.0 }
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

        // Full-interval interior penalty:
        // On a true N×N board, the middle [22%...78%] of each cell between two adjacent grid lines is empty wood.
        // On a 19×19 board tested as 7×7 (18 = 3×6) or 9×9, every interval contains 1–2 real grid lines inside!
        var interiorPenaltySum = 0.0
        for k in 0..<(n - 1) {
            let base = start + Double(k) * step
            let halfPeak = localPeak(around: base + step * 0.5, tol: subTol)
            let third1 = localPeak(around: base + step / 3.0, tol: subTol)
            let third2 = localPeak(around: base + (2.0 * step) / 3.0, tol: subTol)
            let harmonicPeak = max(halfPeak, (third1 + third2) * 0.5)
            let maxInterior = rangeMax(from: base + step * 0.22, to: base + step * 0.78)
            interiorPenaltySum += max(harmonicPeak, maxInterior * 0.85)
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
        let raw = meanLine - 1.35 * meanInterior - 0.70 * exteriorPenalty
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
        let n = boardSize.rawValue
        let outputSide = 900
        let rawInset = min(0.18, max(0.0, gridInsetFraction))

        // When corners are aligned directly to the outermost grid intersections (gridInsetFraction ≈ 0),
        // expand the warp quad slightly outward so corner/edge stones are never clipped on the bitmap edge.
        let desiredMinInset = CGFloat(max(0.042, 0.72 / Double(max(2, n - 1))))
        var warpQuad = corners
        var effectiveInset = rawInset

        if rawInset < desiredMinInset {
            let neededPad = (desiredMinInset - rawInset) / max(0.5, 1.0 - 2.0 * desiredMinInset)
            // Try desired padding first, falling back to smaller padding if the board touches the photo border
            for scale in [1.0, 0.7, 0.45, 0.25] {
                let pad = neededPad * CGFloat(scale)
                let tl = corners.projectivePoint(u: -pad, v: -pad)
                let tr = corners.projectivePoint(u: 1.0 + pad, v: -pad)
                let br = corners.projectivePoint(u: 1.0 + pad, v: 1.0 + pad)
                let bl = corners.projectivePoint(u: -pad, v: 1.0 + pad)
                let allInside = [tl, tr, br, bl].allSatisfy { p in
                    p.x >= 0.0 && p.x <= 1.0 && p.y >= 0.0 && p.y <= 1.0
                }
                if allInside {
                    warpQuad = BoardCornerQuad(topLeft: tl, topRight: tr, bottomRight: br, bottomLeft: bl)
                    effectiveInset = (rawInset + pad) / (1.0 + 2.0 * pad)
                    break
                }
            }
        }

        let warped = warpBoard(image: image, corners: warpQuad, outputSide: outputSide) ?? normalizedUpImage(image, maxDimension: CGFloat(outputSide))
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

        let width = rgba.width
        let height = rgba.height
        let inset = min(0.18, max(0.0, effectiveInset))
        let startX = Double(width) * Double(inset)
        let startY = Double(height) * Double(inset)
        let spanX = Double(width) * (1.0 - 2.0 * Double(inset))
        let spanY = Double(height) * (1.0 - 2.0 * Double(inset))
        let stepX = n > 1 ? spanX / Double(n - 1) : spanX
        let stepY = n > 1 ? spanY / Double(n - 1) : spanY
        let cellStep = min(stepX, stepY)
        let sampleRadius = max(3, Int((cellStep * 0.30).rounded()))

        // Primary path (Option A): On-device CoreML lightweight 3-class CNN (`StarPointStoneClassifier`)
        // Scores all N×N intersections in a single batched forward pass (~5–20ms on iPad).
        var grid: [StoneColor?] = Array(repeating: nil, count: n * n)
        var blackCount = 0
        var whiteCount = 0
        var confidenceSum = 0.0
        var lowConfidence: [BoardPoint] = []
        var usedNeural = false

        if let neuralPredictions = classifyGridWithCoreML(
            rgba: rgba,
            boardSize: n,
            startX: startX,
            startY: startY,
            stepX: stepX,
            stepY: stepY
        ) {
            usedNeural = true
            for idx in 0..<(n * n) {
                let (stone, conf) = neuralPredictions[idx]
                grid[idx] = stone
                if stone == .black { blackCount += 1 }
                else if stone == .white { whiteCount += 1 }
                confidenceSum += conf
                if conf < 0.72 {
                    lowConfidence.append(BoardPoint(row: idx / n, col: idx % n))
                }
            }
        } else {
            // Fallback: Classical adaptive color/luminance classification relative to local + global wood reference
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

            let globalWoodRef = estimateWoodReference(from: features)
            let halfCellRadius = max(2, Int((cellStep * 0.14).rounded()))
            var halfCellWood: [[WoodReference]] = []
            if n >= 2 {
                halfCellWood.reserveCapacity(n - 1)
                for r in 0..<(n - 1) {
                    var rowRefs: [WoodReference] = []
                    rowRefs.reserveCapacity(n - 1)
                    for c in 0..<(n - 1) {
                        let hx = Int((startX + (Double(c) + 0.5) * stepX).rounded())
                        let hy = Int((startY + (Double(r) + 0.5) * stepY).rounded())
                        let hf = sampleDisk(rgba: rgba, cx: hx, cy: hy, radius: halfCellRadius)
                        rowRefs.append(WoodReference(luma: hf.medianLuma, r: hf.meanR, g: hf.meanG, b: hf.meanB, sat: hf.meanSat))
                    }
                    halfCellWood.append(rowRefs)
                }
            }

            @inline(__always)
            func isCleanWoodSample(_ lw: WoodReference) -> Bool {
                abs(lw.luma - globalWoodRef.luma) < 0.14 && abs(lw.sat - globalWoodRef.sat) < 0.18
            }

            for idx in 0..<(n * n) {
                let r = idx / n
                let c = idx % n
                let f = features[idx]

                let effectiveWood: WoodReference
                if n >= 2 {
                    var sumL = 0.0, sumR = 0.0, sumG = 0.0, sumB = 0.0, sumS = 0.0
                    var cnt = 0.0
                    for dr in [-1, 0] {
                        let hr = r + dr
                        guard hr >= 0 && hr < n - 1 else { continue }
                        for dc in [-1, 0] {
                            let hc = c + dc
                            guard hc >= 0 && hc < n - 1 else { continue }
                            let lw = halfCellWood[hr][hc]
                            if isCleanWoodSample(lw) {
                                sumL += lw.luma; sumR += lw.r; sumG += lw.g; sumB += lw.b; sumS += lw.sat
                                cnt += 1.0
                            }
                        }
                    }
                    if cnt < 2.0 {
                        for dr in -2...1 {
                            let hr = r + dr
                            guard hr >= 0 && hr < n - 1 else { continue }
                            for dc in -2...1 {
                                let hc = c + dc
                                guard hc >= 0 && hc < n - 1 else { continue }
                                if (dr == -1 || dr == 0) && (dc == -1 || dc == 0) { continue }
                                let lw = halfCellWood[hr][hc]
                                if isCleanWoodSample(lw) {
                                    sumL += lw.luma; sumR += lw.r; sumG += lw.g; sumB += lw.b; sumS += lw.sat
                                    cnt += 1.0
                                }
                            }
                        }
                    }
                    if cnt > 0 {
                        let alpha = 0.48
                        effectiveWood = WoodReference(
                            luma: alpha * (sumL / cnt) + (1.0 - alpha) * globalWoodRef.luma,
                            r: alpha * (sumR / cnt) + (1.0 - alpha) * globalWoodRef.r,
                            g: alpha * (sumG / cnt) + (1.0 - alpha) * globalWoodRef.g,
                            b: alpha * (sumB / cnt) + (1.0 - alpha) * globalWoodRef.b,
                            sat: alpha * (sumS / cnt) + (1.0 - alpha) * globalWoodRef.sat
                        )
                    } else {
                        effectiveWood = globalWoodRef
                    }
                } else {
                    effectiveWood = globalWoodRef
                }

                let (stone, conf) = classifyCell(f, wood: effectiveWood)
                grid[idx] = stone
                if stone == .black { blackCount += 1 }
                else if stone == .white { whiteCount += 1 }
                confidenceSum += conf
                if conf < 0.62 {
                    lowConfidence.append(BoardPoint(row: idx / n, col: idx % n))
                }
            }
        }

        var state = GoBoardState(size: n, komi: effectiveKomi)
        for idx in 0..<(n * n) {
            if let stone = grid[idx] {
                state.setSetupStone(stone, at: BoardPoint(row: idx / n, col: idx % n))
            }
        }
        state.resetPositionHistoryToCurrent()

        return BoardRecognitionResult(
            boardState: state,
            warpedBoardImage: warped,
            blackStoneCount: blackCount,
            whiteStoneCount: whiteCount,
            averageConfidence: confidenceSum / Double(max(1, n * n)),
            lowConfidencePoints: lowConfidence,
            detectedCorners: corners,
            usedNeuralStoneClassifier: usedNeural
        )
    }

    // MARK: - 4.5 On-Device CoreML Stone Patch Classifier (Option A)

    private static let stoneModelLock = NSLock()
    private static var cachedStoneModel: MLModel?
    private static var didAttemptStoneModelLoad = false

    private static func loadStoneClassifierModel(cpuOnly: Bool = false) -> MLModel? {
        stoneModelLock.lock()
        defer { stoneModelLock.unlock() }

        if !cpuOnly && didAttemptStoneModelLoad {
            return cachedStoneModel
        }
        didAttemptStoneModelLoad = true

        guard let modelURL = locateStoneClassifierModelURL() else {
            return nil
        }

        let config = MLModelConfiguration()
        #if targetEnvironment(simulator)
        config.computeUnits = .cpuOnly
        #else
        config.computeUnits = cpuOnly ? .cpuOnly : .all
        #endif

        if let model = try? MLModel(contentsOf: modelURL, configuration: config) {
            cachedStoneModel = model
            return model
        }
        if !cpuOnly {
            let fallbackConfig = MLModelConfiguration()
            fallbackConfig.computeUnits = .cpuOnly
            if let model = try? MLModel(contentsOf: modelURL, configuration: fallbackConfig) {
                cachedStoneModel = model
                return model
            }
        }
        return nil
    }

    private static func locateStoneClassifierModelURL() -> URL? {
        let bundles = [Bundle.main] + Bundle.allBundles
        for bundle in bundles {
            if let url = bundle.url(forResource: "StarPointStoneClassifier", withExtension: "mlmodelc") {
                return url
            }
            if let url = bundle.url(forResource: "StarPointStoneClassifier", withExtension: "mlmodelc", subdirectory: "Models") {
                return url
            }
        }
        return nil
    }

    private static func classifyGridWithCoreML(
        rgba: RGBABuffer,
        boardSize n: Int,
        startX: Double,
        startY: Double,
        stepX: Double,
        stepY: Double
    ) -> [(StoneColor?, Double)]? {
        let total = n * n
        guard total >= 1, total <= 361 else { return nil }
        guard let model = loadStoneClassifierModel() else { return nil }

        let patchSide = 32
        let shape: [NSNumber] = [NSNumber(value: total), 3, NSNumber(value: patchSide), NSNumber(value: patchSide)]
        guard let inputArray = try? MLMultiArray(shape: shape, dataType: .float32) else { return nil }

        let ptr = inputArray.dataPointer.assumingMemoryBound(to: Float.self)
        let planeSize = patchSide * patchSide
        let patchStride = 3 * planeSize
        let halfSpanX = stepX * 0.675
        let halfSpanY = stepY * 0.675
        let maxX = Double(rgba.width - 1)
        let maxY = Double(rgba.height - 1)
        let bytes = rgba.bytes
        let imgW = rgba.width

        // Bilinearly crop 32x32 RGB patches centered at every intersection (covering 1.35x cell width)
        for r in 0..<n {
            let cy = startY + Double(r) * stepY
            for c in 0..<n {
                let cx = startX + Double(c) * stepX
                let baseOffset = (r * n + c) * patchStride

                for py in 0..<patchSide {
                    let v = -1.0 + 2.0 * Double(py) / Double(patchSide - 1)
                    let sy = min(maxY, max(0.0, cy + v * halfSpanY))
                    let y0 = Int(sy)
                    let y1 = min(rgba.height - 1, y0 + 1)
                    let fy = sy - Double(y0)
                    let row0 = y0 * imgW * 4
                    let row1 = y1 * imgW * 4

                    for px in 0..<patchSide {
                        let u = -1.0 + 2.0 * Double(px) / Double(patchSide - 1)
                        let sx = min(maxX, max(0.0, cx + u * halfSpanX))
                        let x0 = Int(sx)
                        let x1 = min(rgba.width - 1, x0 + 1)
                        let fx = sx - Double(x0)

                        let w00 = (1.0 - fx) * (1.0 - fy)
                        let w10 = fx * (1.0 - fy)
                        let w01 = (1.0 - fx) * fy
                        let w11 = fx * fy

                        let i00 = row0 + x0 * 4
                        let i10 = row0 + x1 * 4
                        let i01 = row1 + x0 * 4
                        let i11 = row1 + x1 * 4

                        let rVal = (w00 * Double(bytes[i00]) + w10 * Double(bytes[i10]) + w01 * Double(bytes[i01]) + w11 * Double(bytes[i11])) / 255.0
                        let gVal = (w00 * Double(bytes[i00 + 1]) + w10 * Double(bytes[i10 + 1]) + w01 * Double(bytes[i01 + 1]) + w11 * Double(bytes[i11 + 1])) / 255.0
                        let bVal = (w00 * Double(bytes[i00 + 2]) + w10 * Double(bytes[i10 + 2]) + w01 * Double(bytes[i01 + 2]) + w11 * Double(bytes[i11 + 2])) / 255.0

                        let pixIdx = py * patchSide + px
                        ptr[baseOffset + pixIdx] = Float(rVal)
                        ptr[baseOffset + planeSize + pixIdx] = Float(gVal)
                        ptr[baseOffset + 2 * planeSize + pixIdx] = Float(bVal)
                    }
                }
            }
        }

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: [
            "patches": MLFeatureValue(multiArray: inputArray)
        ]) else {
            return nil
        }

        stoneModelLock.lock()
        let output = try? model.prediction(from: provider)
        stoneModelLock.unlock()

        guard let output,
              let probs = output.featureValue(for: "probs")?.multiArrayValue,
              probs.count >= total * 3 else {
            return nil
        }

        var results: [(StoneColor?, Double)] = []
        results.reserveCapacity(total)

        if probs.dataType == .float32 {
            let outPtr = probs.dataPointer.assumingMemoryBound(to: Float.self)
            for i in 0..<total {
                let pEmpty = Double(outPtr[i * 3])
                let pBlack = Double(outPtr[i * 3 + 1])
                let pWhite = Double(outPtr[i * 3 + 2])
                if pBlack >= pEmpty && pBlack >= pWhite {
                    results.append((.black, pBlack))
                } else if pWhite >= pEmpty && pWhite >= pBlack {
                    results.append((.white, pWhite))
                } else {
                    results.append((nil, pEmpty))
                }
            }
        } else {
            for i in 0..<total {
                let pEmpty = probs[i * 3].doubleValue
                let pBlack = probs[i * 3 + 1].doubleValue
                let pWhite = probs[i * 3 + 2].doubleValue
                if pBlack >= pEmpty && pBlack >= pWhite {
                    results.append((.black, pBlack))
                } else if pWhite >= pEmpty && pWhite >= pBlack {
                    results.append((.white, pWhite))
                } else {
                    results.append((nil, pEmpty))
                }
            }
        }

        return results
    }

    // MARK: - Pixel Sampling & Adaptive Classification

    private struct RGBABuffer {
        let width: Int
        let height: Int
        let bytes: [UInt8]
    }

    private struct CellFeatures {
        let medianLuma: Double
        let q25Luma: Double
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
            q25Luma: q25,
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
        // Significantly darker than wood OR majority of pixels are very dark OR deep dark lower quartile
        // (robust to large glossy specular glare spots on Yunzi/glass black stones!)
        let blackThreshold = min(0.40, wood.luma - 0.19)
        if f.medianLuma < blackThreshold
            || f.darkRatio >= 0.52
            || (f.q25Luma < min(0.24, wood.luma - 0.28) && f.medianLuma < wood.luma - 0.14) {
            let margin = max(blackThreshold - f.medianLuma, f.darkRatio - 0.48)
            let conf = min(0.99, max(0.55, 0.72 + margin * 1.4))
            return (.black, conf)
        }

        // 2. White stone detection:
        // Significantly brighter AND noticeably less saturated (more neutral/achromatic) than warm wooden board.
        let woodIsWarm = wood.sat >= 0.13
        let satDrop = wood.sat - f.meanSat
        let whiteLumaThreshold = min(0.84, max(0.56, wood.luma + 0.11))

        let isBrightEnough = f.medianLuma > whiteLumaThreshold || f.brightRatio >= 0.62
        let isNeutralEnough = woodIsWarm ? (f.meanSat < max(0.19, wood.sat * 0.65) || satDrop > 0.09) : (lumaDiff > 0.14)

        if isBrightEnough && isNeutralEnough && colorDist > 0.10 {
            let margin = max(f.medianLuma - whiteLumaThreshold, satDrop)
            let conf = min(0.99, max(0.55, 0.70 + margin * 1.3))
            return (.white, conf)
        }

        // 3. Bright-board chromaticity check (white stone on very bright kaya/bamboo board: slightly brighter + strongly desaturated)
        if woodIsWarm && lumaDiff > 0.05 && satDrop > 0.13 && f.meanSat < wood.sat * 0.52 && colorDist > 0.12 {
            let conf = min(0.94, max(0.52, 0.64 + satDrop * 1.1))
            return (.white, conf)
        }

        // 4. Secondary white stone check for dim lighting (white stone in shadow is still much brighter & whiter than wood)
        if lumaDiff > 0.15 && f.meanSat < 0.18 && colorDist > 0.13 {
            let conf = min(0.92, max(0.50, 0.62 + lumaDiff))
            return (.white, conf)
        }

        // 5. Empty intersection
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
