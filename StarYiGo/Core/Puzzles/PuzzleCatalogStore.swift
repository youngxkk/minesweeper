//
//  PuzzleCatalogStore.swift
//  StarYi Go
//

import Foundation

/// Builds the ~1,900-puzzle catalog off the main thread and publishes when it is ready.
///
/// The catalog expands 267 JSON templates into ~1,600 variants (each with an SGF
/// parse + re-serialize), so touching it during the first Home render used to cost the
/// whole launch. Home now shows a cached/placeholder count, the warm-up runs in the
/// background, and the archipelago shows a short loading state until it is ready.
@MainActor
final class PuzzleCatalogStore: ObservableObject {
    static let shared = PuzzleCatalogStore()

    /// Marketing fallback used before the very first build has ever finished.
    static let placeholderCount = 1900
    private static let cachedCountKey = "staryigo.puzzleCatalog.cachedCount"

    @Published private(set) var isReady = false
    @Published private(set) var puzzleCount: Int

    private var loadTask: Task<Void, Never>?

    private init() {
        let cached = UserDefaults.standard.integer(forKey: Self.cachedCountKey)
        puzzleCount = cached > 0 ? cached : Self.placeholderCount
    }

    /// Kicks off the one-time background build. Safe to call from multiple screens.
    func warmUp() {
        guard loadTask == nil else { return }
        loadTask = Task { [weak self] in
            let count = await Task.detached(priority: .utility) {
                DojoPuzzleBank.fullCatalog.count
            }.value
            guard let self else { return }
            UserDefaults.standard.set(count, forKey: Self.cachedCountKey)
            self.puzzleCount = count
            self.isReady = true
        }
    }

    /// Awaits the warm-up so a screen can show a loading state instead of blocking its body.
    func waitUntilReady() async {
        warmUp()
        await loadTask?.value
    }
}
