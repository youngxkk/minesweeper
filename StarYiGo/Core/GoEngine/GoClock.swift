//
//  GoClock.swift
//  StarYi Go — Official Go Clock & Byoyomi State Machine
//

import Foundation

struct PlayerClockState: Equatable, Sendable {
    var mainSecondsRemaining: Int
    var inByoyomi: Bool
    var byoyomiSecondsRemaining: Int
    var byoyomiPeriodsRemaining: Int
    let periodDuration: Int

    var isFlagged: Bool {
        if periodDuration > 0 {
            return inByoyomi && byoyomiPeriodsRemaining <= 0
        }
        return mainSecondsRemaining <= 0
    }

    var formattedDisplay: String {
        if inByoyomi && periodDuration > 0 {
            return String(format: "%02ds (%d)", max(0, byoyomiSecondsRemaining), max(0, byoyomiPeriodsRemaining))
        }
        let secs = max(0, mainSecondsRemaining)
        let mins = secs / 60
        let rem = secs % 60
        return String(format: "%02d:%02d", mins, rem)
    }

    var isUrgentCountdown: Bool {
        if inByoyomi && periodDuration > 0 {
            return byoyomiSecondsRemaining <= 10 && byoyomiSecondsRemaining > 0
        }
        return mainSecondsRemaining <= 10 && mainSecondsRemaining > 0
    }
}

enum ClockTickEvent: Equatable, Sendable {
    case normal
    case countdownBeep(secondsLeft: Int)
    case periodConsumed(remainingPeriods: Int)
    case timeout(loser: StoneColor)
}

/// Pure value-type Go Clock supporting Unlimited, Sudden Death (包干), and Main + Byoyomi (读秒).
struct GoClock: Equatable, Sendable {
    let timeControl: TimeControl
    var black: PlayerClockState
    var white: PlayerClockState

    init(timeControl: TimeControl) {
        self.timeControl = timeControl
        let initial: PlayerClockState
        switch timeControl {
        case .unlimited:
            initial = PlayerClockState(mainSecondsRemaining: 0, inByoyomi: false, byoyomiSecondsRemaining: 0, byoyomiPeriodsRemaining: 0, periodDuration: 0)
        case .suddenDeath(let minutes):
            initial = PlayerClockState(mainSecondsRemaining: max(1, minutes) * 60, inByoyomi: false, byoyomiSecondsRemaining: 0, byoyomiPeriodsRemaining: 0, periodDuration: 0)
        case .byoyomi(let mainMinutes, let periodSeconds, let periods):
            let mainSecs = max(0, mainMinutes) * 60
            let startByo = (mainSecs == 0)
            initial = PlayerClockState(
                mainSecondsRemaining: mainSecs,
                inByoyomi: startByo,
                byoyomiSecondsRemaining: periodSeconds,
                byoyomiPeriodsRemaining: max(1, periods),
                periodDuration: max(5, periodSeconds)
            )
        }
        self.black = initial
        self.white = initial
    }

    var isActive: Bool {
        timeControl.isTimed
    }

    func state(for color: StoneColor) -> PlayerClockState {
        color == .black ? black : white
    }

    /// Advances active player's clock by 1 second.
    mutating func tick(activeColor: StoneColor) -> ClockTickEvent {
        guard timeControl.isTimed else { return .normal }
        var p = state(for: activeColor)
        var event: ClockTickEvent = .normal

        if !p.inByoyomi {
            if p.mainSecondsRemaining > 0 {
                p.mainSecondsRemaining -= 1
                if p.mainSecondsRemaining == 0 {
                    if p.periodDuration > 0 {
                        p.inByoyomi = true
                        p.byoyomiSecondsRemaining = p.periodDuration
                    } else {
                        event = .timeout(loser: activeColor)
                    }
                } else if p.mainSecondsRemaining <= 10 && p.periodDuration == 0 {
                    event = .countdownBeep(secondsLeft: p.mainSecondsRemaining)
                }
            } else {
                event = .timeout(loser: activeColor)
            }
        } else {
            if p.byoyomiSecondsRemaining > 1 {
                p.byoyomiSecondsRemaining -= 1
                if p.byoyomiSecondsRemaining <= 10 {
                    event = .countdownBeep(secondsLeft: p.byoyomiSecondsRemaining)
                }
            } else {
                p.byoyomiPeriodsRemaining -= 1
                if p.byoyomiPeriodsRemaining <= 0 {
                    p.byoyomiSecondsRemaining = 0
                    event = .timeout(loser: activeColor)
                } else {
                    p.byoyomiSecondsRemaining = p.periodDuration
                    event = .periodConsumed(remainingPeriods: p.byoyomiPeriodsRemaining)
                }
            }
        }

        if activeColor == .black { black = p } else { white = p }
        return event
    }

    /// Resets the current Byoyomi period when `color` completes a move in time.
    mutating func completeMove(for color: StoneColor) {
        guard timeControl.isTimed else { return }
        var p = state(for: color)
        if p.inByoyomi && p.periodDuration > 0 && p.byoyomiPeriodsRemaining > 0 {
            p.byoyomiSecondsRemaining = p.periodDuration
        }
        if color == .black { black = p } else { white = p }
    }
}
