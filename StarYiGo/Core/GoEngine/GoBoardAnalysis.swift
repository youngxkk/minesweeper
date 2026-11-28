//
//  GoBoardAnalysis.swift
//  StarYi Go
//

import Foundation

/// A single, reusable snapshot of the expensive per-position board analysis.
///
/// Previously `GoBoardView` recomputed `atariPoints()`, `twoEyeAliveAnalysis()` and
/// `allGroups()` from inside its `body`. Every hover change, touch and redraw therefore
/// triggered several full-board flood fills on the main thread. The owning model now
/// computes this once per position and hands it to the view.
struct GoBoardAnalysis: Sendable, Hashable {
    var atariPoints: Set<BoardPoint> = []
    var eyePoints: Set<BoardPoint> = []
    var aliveStoneIndices: Set<Int> = []
    var groups: [GoGroup] = []

    static func build(
        from state: GoBoardState,
        includeAtari: Bool = true,
        includeTwoEye: Bool = true,
        includeGroups: Bool = true
    ) -> GoBoardAnalysis {
        var analysis = GoBoardAnalysis()
        let needsGroups = includeAtari || includeGroups || includeTwoEye
        let groups = needsGroups ? state.allGroups() : []
        if includeGroups { analysis.groups = groups }
        if includeAtari {
            var points: Set<BoardPoint> = []
            for group in groups where group.liberties.count == 1 {
                for index in group.stones {
                    points.insert(state.point(for: index))
                }
            }
            analysis.atariPoints = points
        }
        if includeTwoEye {
            let twoEye = state.twoEyeAliveAnalysis(precomputedGroups: groups)
            analysis.eyePoints = twoEye.eyePoints
            analysis.aliveStoneIndices = twoEye.aliveStoneIndices
        }
        return analysis
    }
}
