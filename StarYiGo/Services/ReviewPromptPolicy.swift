import Foundation
import Combine

/// App-wide, persistent limits on attempts, since StoreKit does not report presentation or ratings.
struct ReviewPromptHistory: Codable {
    var firstSeen: Date
    var completedGames = 0
    var gamesAtLastRequest = 0
    var requestedVersions: Set<String> = []
    var requestDates: [Date] = []

    func isEligible(now: Date, version: String) -> Bool {
        let day: TimeInterval = 86_400
        guard completedGames >= 1,
              !version.isEmpty,
              !requestedVersions.contains(version)
        else { return false }
        if let last = requestDates.max() {
            return now.timeIntervalSince(last) >= 30 * day
        }
        return true
    }

    mutating func recordRequest(now: Date, version: String) {
        requestDates.append(now)
        requestedVersions.insert(version)
        gamesAtLastRequest = completedGames
    }
}

@MainActor
final class ReviewPromptPolicy: ObservableObject {
    @Published private(set) var pendingRequestDate: Date?
    #if DEBUG
    /// Session-only switch; test requests never consume the real cooldown or version allowance.
    @Published var debugBypassLimits = false
    #endif
    static let shared = ReviewPromptPolicy()
    private let defaults: UserDefaults
    private let key = "appReview.promptHistory.v1"
    private var history: ReviewPromptHistory

    init(defaults: UserDefaults = .standard, now: Date = Date()) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let stored = try? JSONDecoder().decode(ReviewPromptHistory.self, from: data) {
            history = stored
        } else {
            history = ReviewPromptHistory(firstSeen: now)
        }
        persist()
    }

    func recordCompletedGame(now: Date = Date()) {
        history.completedGames += 1
        persist()
        // Owned by the app, so navigation cannot cancel the one-second delay.
        if pendingRequestDate == nil {
            pendingRequestDate = now.addingTimeInterval(1)
        }
    }

    func consumeRequestIfEligible(now: Date = Date(),
                                  version: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") -> Bool {
        guard let pendingRequestDate, now >= pendingRequestDate else { return false }
        self.pendingRequestDate = nil
        #if DEBUG
        if debugBypassLimits { return true }
        #endif
        guard history.isEligible(now: now, version: version) else { return false }
        history.recordRequest(now: now, version: version)
        persist()
        return true
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: key)
        }
    }
}
