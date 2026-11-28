import Foundation
import Testing
@testable import StarYiGo

@MainActor
struct ReviewPromptPolicyTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private func day(_ days: Double) -> Date { start.addingTimeInterval(days * 86_400) }

    #if DEBUG
    @Test func debugBypassPreservesDelayAndNormalHistory() throws {
        let suite = "ReviewPromptPolicyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let policy = ReviewPromptPolicy(defaults: defaults, now: start)
        policy.debugBypassLimits = true
        policy.recordCompletedGame(now: start)
        #expect(!policy.consumeRequestIfEligible(now: start, version: "1"))
        #expect(policy.consumeRequestIfEligible(now: start.addingTimeInterval(1), version: "1"))
        policy.recordCompletedGame(now: start.addingTimeInterval(2))
        #expect(policy.consumeRequestIfEligible(now: start.addingTimeInterval(3), version: "1"))
        // Turning the switch off still allows the first real request for this version.
        policy.debugBypassLimits = false
        policy.recordCompletedGame(now: start.addingTimeInterval(4))
        #expect(policy.consumeRequestIfEligible(now: start.addingTimeInterval(5), version: "1"))
        policy.debugBypassLimits = true
        policy.recordCompletedGame(now: start.addingTimeInterval(6))
        #expect(policy.consumeRequestIfEligible(now: start.addingTimeInterval(7), version: "1"))
        let restored = ReviewPromptPolicy(defaults: defaults, now: day(1))
        #expect(!restored.debugBypassLimits)
        restored.recordCompletedGame(now: day(1))
        #expect(!restored.consumeRequestIfEligible(now: day(1).addingTimeInterval(1), version: "2"))
        restored.recordCompletedGame(now: day(31))
        #expect(!restored.consumeRequestIfEligible(now: day(31).addingTimeInterval(1), version: "1"))
    }
    #endif

    @Test func firstGameIsEligibleImmediately() {
        var history = ReviewPromptHistory(firstSeen: start)
        #expect(!history.isEligible(now: start, version: "1"))
        history.completedGames = 1
        #expect(history.isEligible(now: start, version: "1"))
        #expect(!history.isEligible(now: start, version: ""))
    }

    @Test func requiresThirtyDaysAndAnUnrequestedVersion() {
        var history = ReviewPromptHistory(firstSeen: start)
        history.completedGames = 1
        history.recordRequest(now: start, version: "1")
        #expect(!history.isEligible(now: day(29.99), version: "2"))
        #expect(history.isEligible(now: day(30), version: "2"))
        #expect(!history.isEligible(now: day(400), version: "1"))
        history.recordRequest(now: day(30), version: "2")
        #expect(!history.isEligible(now: day(59), version: "3"))
        #expect(history.isEligible(now: day(60), version: "3"))
        history.recordRequest(now: day(60), version: "3")
        #expect(history.isEligible(now: day(90), version: "4"))
        #expect(!history.isEligible(now: day(-1), version: "4"))
    }

    @Test func delaysOneSecondAndPersistsAttempts() throws {
        let suite = "ReviewPromptPolicyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let policy = ReviewPromptPolicy(defaults: defaults, now: start)
        #expect(!policy.consumeRequestIfEligible(now: day(1), version: "1"))
        policy.recordCompletedGame(now: start)
        #expect(policy.pendingRequestDate == start.addingTimeInterval(1))
        #expect(!policy.consumeRequestIfEligible(now: start.addingTimeInterval(0.99), version: "1"))
        #expect(policy.consumeRequestIfEligible(now: start.addingTimeInterval(1), version: "1"))
        #expect(policy.pendingRequestDate == nil)
        #expect(!policy.consumeRequestIfEligible(now: day(1), version: "1"))
        let restored = ReviewPromptPolicy(defaults: defaults, now: day(1))
        restored.recordCompletedGame(now: day(1))
        #expect(!restored.consumeRequestIfEligible(now: day(1).addingTimeInterval(1), version: "2"))
        restored.recordCompletedGame(now: day(31))
        #expect(!restored.consumeRequestIfEligible(now: day(31).addingTimeInterval(1), version: "1"))
        restored.recordCompletedGame(now: day(31))
        #expect(restored.consumeRequestIfEligible(now: day(31).addingTimeInterval(1), version: "2"))
    }

    @Test func pendingRequestSurvivesWaitingAndDoesNotResetDeadline() throws {
        let suite = "ReviewPromptPolicyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let policy = ReviewPromptPolicy(defaults: defaults, now: start)
        policy.recordCompletedGame(now: start)
        policy.recordCompletedGame(now: start.addingTimeInterval(0.5))
        #expect(policy.pendingRequestDate == start.addingTimeInterval(1))
        // A backgrounded app can consume the request on its next foreground activation.
        #expect(policy.consumeRequestIfEligible(now: day(1), version: "1"))
    }
}
