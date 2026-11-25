//
//  SoundAndHapticsManager.swift
//  StarYi Go
//

import AVFoundation
import UIKit

enum UITapWeight: Sendable {
    case light
    case standard
    case card
    case heavy
}

enum MusicMood: Equatable, Sendable {
    case none
    case island
    case match
    case boss
}

/// Nintendo-style kid voice encouragement cues (bundled per language under `Resources/Voice/<lang>/`).
enum VoiceCue: String, CaseIterable, Sendable {
    case correct
    case wrong
    case combo3
    case combo5
    case hint
    case illegalMove
    case atari
    case captureSmall
    case captureBig
    case rewind
    case victory
    case bossVictory
    case encourageLoss
    case examPass
    case codexUnlock
    case shopUnlock
    case notEnoughCoins
    case locked
    case photoDone
    case welcome

    var filePrefix: String {
        switch self {
        case .correct:        return "correct"
        case .wrong:          return "wrong"
        case .combo3:         return "combo3"
        case .combo5:         return "combo5"
        case .hint:           return "hint"
        case .illegalMove:    return "illegal"
        case .atari:          return "atari"
        case .captureSmall:   return "capture_small"
        case .captureBig:     return "capture_big"
        case .rewind:         return "rewind"
        case .victory:        return "victory"
        case .bossVictory:    return "boss_victory"
        case .encourageLoss:  return "encourage"
        case .examPass:       return "exam_pass"
        case .codexUnlock:    return "codex"
        case .shopUnlock:     return "shop_unlock"
        case .notEnoughCoins: return "no_coins"
        case .locked:         return "locked"
        case .photoDone:      return "photo_done"
        case .welcome:        return "welcome"
        }
    }

    var variantCount: Int {
        switch self {
        case .correct:        return 5
        case .wrong:          return 4
        case .victory:        return 3
        case .combo3, .combo5, .hint, .illegalMove, .atari,
             .captureSmall, .captureBig, .bossVictory,
             .encourageLoss, .examPass, .welcome:
            return 2
        case .rewind, .codexUnlock, .shopUnlock,
             .notEnoughCoins, .locked, .photoDone:
            return 1
        }
    }
}

/// Nintendo-grade acoustic & haptic engine for StarYi Go:
/// - Physical modal synthesis of Kaya-wood goban resonance + Clamshell/Slate stone impacts (with stereo board panning!)
/// - Authentic wooden Go-ke (棋笥) capture bowl cascades with micro-randomized stone clinks
/// - Long-form 64-beat A-B-A'-C pentatonic compositions with smooth crossfades & dynamic tension layer
/// - Nintendo-style kid voice encouragement cues with BGM ducking, non-repeating shuffle, and clean interruption
/// - Automatic support for bundled studio .m4a/.wav samples when present, with zero-latency modal fallback
@MainActor
final class SoundAndHapticsManager {
    static let shared = SoundAndHapticsManager()

    var soundEnabled: Bool = true
    var bgmEnabled: Bool = true {
        didSet { updateBGMPlayback() }
    }
    var voiceEnabled: Bool = true {
        didSet {
            if !voiceEnabled { stopVoice() }
        }
    }
    /// Active voice pack language code (e.g. `"zh"`; future packs: `"en"`, `"ja"`, `"ko"`).
    var voiceLanguageCode: String = "zh"
    var zenDojoMode: Bool = false {
        didSet {
            if zenDojoMode { stopVoice() }
            updateBGMPlayback()
        }
    }
    var hapticsEnabled: Bool = true

    private let audio = GameAudioPlayback()
    private var currentMood: MusicMood = .none
    private var tensionActive: Bool = false
    private var lastVoiceTimestamp: [VoiceCue: TimeInterval] = [:]

    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        selectionFeedback.prepare()
        softImpact.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
    }

    func setMusicMood(_ mood: MusicMood) {
        currentMood = mood
        if mood != .match { tensionActive = false }
        updateBGMPlayback()
    }

    /// Dynamically crossfades a subtle rhythmic tension layer during Ko fights, Atari threats, or Byo-yomi.
    func setMatchTension(_ active: Bool) {
        guard tensionActive != active else { return }
        tensionActive = active
        updateBGMPlayback()
    }

    func updateBGMPlayback() {
        let mood = soundEnabled && bgmEnabled && !zenDojoMode ? currentMood : .none
        let tension = (mood == .match) && tensionActive
        audio.updateMusic(to: mood, tensionLayer: tension)
    }

    private func playKey(_ key: String, pan: Float = 0.0, pitchShift: Float = 1.0) {
        guard soundEnabled else { return }
        audio.playEffect(key, pan: pan, rate: pitchShift)
    }

    // MARK: - Public Feedback Triggers

    func playUITap(weight: UITapWeight = .standard) {
        playKey("uiTap")
        guard hapticsEnabled else { return }
        switch weight {
        case .light:
            lightImpact.impactOccurred(intensity: 0.52)
        case .standard:
            lightImpact.impactOccurred(intensity: 0.72)
        case .card:
            softImpact.impactOccurred(intensity: 0.60)
        case .heavy:
            mediumImpact.impactOccurred(intensity: 0.74)
        }
    }

    func playGridTick() {
        playKey("gridTick")
        if hapticsEnabled {
            selectionFeedback.selectionChanged()
            selectionFeedback.prepare()
        }
    }

    /// Plays a position-aware Kaya wood & stone impact with subtle stereo panning across the board.
    func playStonePlace(at point: BoardPoint? = nil, boardSize: Int = 9, isAtari: Bool = false) {
        let pan: Float = {
            guard let pt = point, boardSize > 1 else { return 0.0 }
            let norm = (Float(pt.col) / Float(boardSize - 1)) * 2.0 - 1.0 // -1...1
            return max(-0.34, min(0.34, norm * 0.34))
        }()
        let microRate = Float.random(in: 0.97...1.03)

        if isAtari {
            playKey("stoneAtari", pan: pan, pitchShift: microRate)
            if hapticsEnabled { mediumImpact.impactOccurred(intensity: 0.92) }
            return
        }
        if let pt = point, boardSize >= 5 {
            let edgeDist = min(min(pt.row, boardSize - 1 - pt.row), min(pt.col, boardSize - 1 - pt.col))
            if edgeDist <= 1 {
                playKey("stoneEdge", pan: pan, pitchShift: microRate)
                if hapticsEnabled { lightImpact.impactOccurred(intensity: 0.70) }
                return
            } else if edgeDist >= boardSize / 3 {
                playKey("stoneCenter", pan: pan, pitchShift: microRate)
                if hapticsEnabled { lightImpact.impactOccurred(intensity: 0.88) }
                return
            }
        }
        playKey("stone", pan: pan, pitchShift: microRate)
        if hapticsEnabled { lightImpact.impactOccurred(intensity: 0.80) }
    }

    func playCapture(count: Int = 1) {
        if count >= 5 {
            playKey("captureMassive")
            if hapticsEnabled { heavyImpact.impactOccurred(intensity: 0.92) }
        } else {
            playKey(count >= 3 ? "captureBig" : "captureSmall")
            if hapticsEnabled { mediumImpact.impactOccurred(intensity: count >= 3 ? 0.95 : 0.82) }
        }
    }

    func playWonderMoment() {
        playKey("wonder")
        if hapticsEnabled { notificationFeedback.notificationOccurred(.success) }
    }

    func playStickerPop() {
        playKey("stickerPop")
        if hapticsEnabled { softImpact.impactOccurred(intensity: 0.65) }
    }

    func playUndo() {
        playKey("undo")
        if hapticsEnabled { softImpact.impactOccurred(intensity: 0.65) }
    }

    func playHint() {
        playKey("hint")
        if hapticsEnabled { lightImpact.impactOccurred(intensity: 0.60) }
    }

    func playSuccess() {
        playKey("success")
        if hapticsEnabled { notificationFeedback.notificationOccurred(.success) }
    }

    func playVictoryFanfare() {
        playKey("victory")
        if hapticsEnabled { notificationFeedback.notificationOccurred(.success) }
    }

    func playBossFanfare() {
        playKey("bossVictory")
        if hapticsEnabled { notificationFeedback.notificationOccurred(.success) }
    }

    func playCodexUnlock() {
        playKey("codexUnlock")
        if hapticsEnabled { lightImpact.impactOccurred(intensity: 0.72) }
    }

    func playLockedDoor() {
        playKey("lockedDoor")
        if hapticsEnabled { softImpact.impactOccurred(intensity: 0.32) }
    }

    func playWrong() {
        playKey("wrong")
        if hapticsEnabled { notificationFeedback.notificationOccurred(.warning) }
    }

    func playKoBounce() {
        playKey("koBounce")
        if hapticsEnabled { notificationFeedback.notificationOccurred(.warning) }
    }

    func playFireflyInspect() {
        playKey("firefly")
        if hapticsEnabled { softImpact.impactOccurred(intensity: 0.5) }
    }

    func playHourglassRewind() {
        playKey("hourglass")
        if hapticsEnabled { mediumImpact.impactOccurred(intensity: 0.75) }
    }

    func playCountdownTick(urgent: Bool = false) {
        playKey(urgent ? "countdownUrgent" : "gridTick")
        if hapticsEnabled {
            if urgent {
                lightImpact.impactOccurred(intensity: 0.68)
            } else {
                selectionFeedback.selectionChanged()
            }
        }
    }

    // MARK: - Nintendo-Style Kid Voice Encouragement

    /// Plays a bundled kid-voice encouragement clip for the active language pack.
    /// Automatically respects `voiceEnabled` and `zenDojoMode`, ducks BGM,
    /// avoids repeating the same variant twice in a row, and cleanly interrupts overlapping clips.
    func playVoice(
        _ cue: VoiceCue,
        delay: TimeInterval = 0.0,
        cooldown: TimeInterval = 0.0,
        interrupt: Bool = true
    ) {
        guard voiceEnabled, !zenDojoMode else { return }
        // Avoid talking over VoiceOver accessibility announcements
        guard !UIAccessibility.isVoiceOverRunning else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if cooldown > 0, let last = lastVoiceTimestamp[cue], (now - last) < cooldown {
            return
        }
        lastVoiceTimestamp[cue] = now
        audio.playVoice(cue, languageCode: voiceLanguageCode, delay: delay, interrupt: interrupt)
    }

    func stopVoice() {
        audio.stopVoice()
    }
}

// MARK: - Serial Audio Engine (Physical Modal Synthesis + Smooth Adaptive BGM + Kid Voice)

private final class GameAudioPlayback: @unchecked Sendable {
    private let queue = DispatchQueue(label: "StarYiGo.audio", qos: .userInitiated)
    private var players: [String: [AVAudioPlayer]] = [:]
    private var voicePlayers: [String: AVAudioPlayer] = [:]
    private var activeVoicePlayer: AVAudioPlayer?
    private var pendingVoiceWorkItem: DispatchWorkItem?
    private var pendingUnduckWorkItem: DispatchWorkItem?
    private var lastVoiceVariant: [VoiceCue: Int] = [:]
    private var isBGMDUcked: Bool = false
    private var bgmPlayers: [MusicMood: AVAudioPlayer] = [:]
    private var bgmTargetVolumes: [MusicMood: Float] = [
        .island: 0.16,
        .match: 0.13,
        .boss: 0.17
    ]
    private var tensionPlayer: AVAudioPlayer?
    private var lastMood: MusicMood = .none
    private var lastTension: Bool = false

    init() {
        queue.async {
            self.configureAudioSession()
            self.prepareSynthesizedSounds()
            self.prepareAdaptiveBGM()
            self.observeAudioInterruptions()
        }
    }

    private func observeAudioInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self,
                  let info = notification.userInfo,
                  let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
            if type == .ended {
                self.queue.async {
                    try? AVAudioSession.sharedInstance().setActive(true)
                    self.applyMusicState(mood: self.lastMood, tensionLayer: self.lastTension)
                }
            }
        }
    }

    func updateMusic(to currentMood: MusicMood, tensionLayer: Bool) {
        queue.async {
            self.lastMood = currentMood
            self.lastTension = tensionLayer
            self.applyMusicState(mood: currentMood, tensionLayer: tensionLayer)
        }
    }

    private func applyMusicState(mood currentMood: MusicMood, tensionLayer: Bool) {
        let duckScale: Float = isBGMDUcked ? 0.38 : 1.0
        for (mood, player) in bgmPlayers {
            if mood == currentMood {
                let target = (bgmTargetVolumes[mood] ?? 0.15) * duckScale
                if !player.isPlaying {
                    player.volume = 0.0
                    player.play()
                }
                player.setVolume(target, fadeDuration: 0.65)
            } else if player.isPlaying {
                player.setVolume(0.0, fadeDuration: 0.50)
                let fadingPlayer = player
                queue.asyncAfter(deadline: .now() + 0.55) {
                    if self.lastMood != mood && fadingPlayer.volume <= 0.01 {
                        fadingPlayer.pause()
                    }
                }
            }
        }

        if let tp = tensionPlayer {
            if tensionLayer && currentMood == .match {
                if !tp.isPlaying {
                    tp.volume = 0.0
                    tp.play()
                }
                tp.setVolume(0.11 * duckScale, fadeDuration: 0.65)
            } else if tp.isPlaying {
                tp.setVolume(0.0, fadeDuration: 0.45)
                queue.asyncAfter(deadline: .now() + 0.50) {
                    if !self.lastTension && tp.volume <= 0.01 {
                        tp.pause()
                    }
                }
            }
        }
    }

    func playEffect(_ key: String, pan: Float = 0.0, rate: Float = 1.0) {
        queue.async {
            guard let pool = self.players[key], !pool.isEmpty else { return }
            // Prefer an idle player in the pool for clean polyphony (fast captures/clicks never clip!)
            let chosen = pool.first(where: { !$0.isPlaying }) ?? pool.randomElement()!
            chosen.pan = pan
            if chosen.enableRate {
                chosen.rate = max(0.85, min(1.15, rate))
            }
            chosen.currentTime = 0
            chosen.play()
        }
    }

    func playVoice(_ cue: VoiceCue, languageCode: String, delay: TimeInterval, interrupt: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            if !interrupt, let active = self.activeVoicePlayer, active.isPlaying {
                return
            }
            self.pendingVoiceWorkItem?.cancel()
            self.pendingVoiceWorkItem = nil

            let startPlayback = { [weak self] in
                guard let self else { return }
                guard let player = self.resolveVoicePlayer(for: cue, languageCode: languageCode) else { return }

                if let active = self.activeVoicePlayer, active.isPlaying {
                    active.stop()
                }
                self.pendingUnduckWorkItem?.cancel()

                player.currentTime = 0
                player.volume = 0.92
                self.activeVoicePlayer = player
                self.duckBGM(true)
                player.play()

                let restoreDelay = max(0.25, player.duration + 0.14)
                let unduckWork = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    if self.activeVoicePlayer == nil || self.activeVoicePlayer?.isPlaying == false {
                        self.duckBGM(false)
                    }
                }
                self.pendingUnduckWorkItem = unduckWork
                self.queue.asyncAfter(deadline: .now() + restoreDelay, execute: unduckWork)
            }

            if delay > 0.005 {
                let work = DispatchWorkItem(block: startPlayback)
                self.pendingVoiceWorkItem = work
                self.queue.asyncAfter(deadline: .now() + delay, execute: work)
            } else {
                startPlayback()
            }
        }
    }

    func stopVoice() {
        queue.async {
            self.pendingVoiceWorkItem?.cancel()
            self.pendingVoiceWorkItem = nil
            self.pendingUnduckWorkItem?.cancel()
            self.pendingUnduckWorkItem = nil
            if let active = self.activeVoicePlayer, active.isPlaying {
                active.stop()
            }
            self.activeVoicePlayer = nil
            self.duckBGM(false)
        }
    }

    private func duckBGM(_ duck: Bool) {
        guard isBGMDUcked != duck else { return }
        isBGMDUcked = duck
        let scale: Float = duck ? 0.38 : 1.0
        let fade: TimeInterval = duck ? 0.10 : 0.32
        if let player = bgmPlayers[lastMood], player.isPlaying {
            let target = (bgmTargetVolumes[lastMood] ?? 0.15) * scale
            player.setVolume(target, fadeDuration: fade)
        }
        if let tp = tensionPlayer, tp.isPlaying {
            tp.setVolume(0.11 * scale, fadeDuration: fade)
        }
    }

    private func resolveVoicePlayer(for cue: VoiceCue, languageCode: String) -> AVAudioPlayer? {
        let count = max(1, cue.variantCount)
        let chosenVariant: Int
        if count == 1 {
            chosenVariant = 1
        } else {
            let last = lastVoiceVariant[cue] ?? 0
            let candidates = (1...count).filter { $0 != last }
            chosenVariant = candidates.randomElement() ?? Int.random(in: 1...count)
        }
        lastVoiceVariant[cue] = chosenVariant

        let resourceName = "voice_\(languageCode)_\(cue.filePrefix)_\(chosenVariant)"
        if let cached = voicePlayers[resourceName] {
            return cached
        }
        if let loaded = loadVoiceAsset(resourceName: resourceName, languageCode: languageCode) {
            voicePlayers[resourceName] = loaded
            return loaded
        }
        // Fallback to variant 1 if a higher variant is missing
        if chosenVariant != 1 {
            let fallbackName = "voice_\(languageCode)_\(cue.filePrefix)_1"
            if let cached = voicePlayers[fallbackName] { return cached }
            if let loaded = loadVoiceAsset(resourceName: fallbackName, languageCode: languageCode) {
                voicePlayers[fallbackName] = loaded
                return loaded
            }
        }
        return nil
    }

    private func loadVoiceAsset(resourceName: String, languageCode: String) -> AVAudioPlayer? {
        let subdirs: [String?] = [
            "Resources/Voice/\(languageCode)",
            "Voice/\(languageCode)",
            languageCode,
            nil
        ]
        for subdir in subdirs {
            for ext in ["m4a", "wav", "mp3"] {
                let url: URL?
                if let subdir {
                    url = Bundle.main.url(forResource: resourceName, withExtension: ext, subdirectory: subdir)
                } else {
                    url = Bundle.main.url(forResource: resourceName, withExtension: ext)
                }
                if let url, let player = try? AVAudioPlayer(contentsOf: url) {
                    player.volume = 0.92
                    player.prepareToPlay()
                    return player
                }
            }
        }
        return nil
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Silently ignore in simulator/preview environments
        }
    }

    /// Loads a bundled studio audio asset if present, otherwise falls back to synthesized PCM WAV.
    private func loadBundledOrSynthesized(resourceName: String, volume: Float, fallback: () -> Data) -> AVAudioPlayer? {
        for ext in ["m4a", "wav", "mp3"] {
            if let url = Bundle.main.url(forResource: resourceName, withExtension: ext),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.volume = volume
                player.enableRate = true
                player.prepareToPlay()
                return player
            }
        }
        return makePlayer(from: fallback(), volume: volume)
    }

    // MARK: - 64-Beat Adaptive BGM Compositions (Zero Loop Fatigue)

    private func prepareAdaptiveBGM() {
        // 1. Island Breeze (C Major Pentatonic — 64-step A-B-A'-C warm marimba + harp + warm bass)
        let islandA: [(Double, Double, Double)] = [
            (523.25, 261.63, 329.63), (0, 0, 0), (659.25, 0, 0), (783.99, 0, 0),
            (880.00, 349.23, 440.00), (0, 0, 0), (783.99, 0, 0), (659.25, 0, 0),
            (587.33, 293.66, 392.00), (0, 0, 0), (659.25, 0, 0), (523.25, 0, 0),
            (587.33, 196.00, 293.66), (0, 0, 0), (0, 0, 0), (523.25, 0, 0)
        ]
        let islandB: [(Double, Double, Double)] = [
            (783.99, 329.63, 392.00), (0, 0, 0), (880.00, 0, 0), (1046.50, 0, 0),
            (880.00, 261.63, 329.63), (0, 0, 0), (783.99, 0, 0), (659.25, 0, 0),
            (659.25, 220.00, 329.63), (587.33, 0, 0), (523.25, 0, 0), (587.33, 0, 0),
            (659.25, 196.00, 293.66), (0, 0, 0), (523.25, 0, 0), (0, 0, 0)
        ]
        let islandC: [(Double, Double, Double)] = [
            (1046.50, 261.63, 392.00), (0, 0, 0), (880.00, 0, 0), (783.99, 0, 0),
            (659.25, 349.23, 440.00), (783.99, 0, 0), (880.00, 0, 0), (659.25, 0, 0),
            (587.33, 293.66, 392.00), (659.25, 0, 0), (523.25, 0, 0), (440.00, 0, 0),
            (523.25, 261.63, 329.63), (0, 0, 0), (0, 0, 0), (0, 0, 0)
        ]
        let islandFull = islandA + islandB + islandA + islandC
        if let p = makeLoopingBGMPlayer(
            from: synthesizeRichPentatonicBGM(steps: islandFull, stepDuration: 0.34, brightness: 0.22, padWarmth: 0.16),
            volume: 0.16
        ) {
            bgmPlayers[.island] = p
        }

        // 2. Calm Zen Match (D Major / A Pentatonic — spacious koto & wooden kalimba, generous silences)
        let matchA: [(Double, Double, Double)] = [
            (440.00, 220.00, 293.66), (0, 0, 0), (0, 0, 0), (523.25, 0, 0),
            (587.33, 196.00, 293.66), (0, 0, 0), (523.25, 0, 0), (0, 0, 0),
            (440.00, 174.61, 261.63), (0, 0, 0), (392.00, 0, 0), (0, 0, 0),
            (440.00, 220.00, 329.63), (0, 0, 0), (0, 0, 0), (0, 0, 0)
        ]
        let matchB: [(Double, Double, Double)] = [
            (659.25, 261.63, 329.63), (0, 0, 0), (587.33, 0, 0), (0, 0, 0),
            (523.25, 220.00, 329.63), (0, 0, 0), (440.00, 0, 0), (392.00, 0, 0),
            (440.00, 196.00, 293.66), (0, 0, 0), (523.25, 0, 0), (0, 0, 0),
            (392.00, 196.00, 246.94), (0, 0, 0), (0, 0, 0), (0, 0, 0)
        ]
        let matchC: [(Double, Double, Double)] = [
            (587.33, 220.00, 293.66), (0, 0, 0), (659.25, 0, 0), (0, 0, 0),
            (783.99, 261.63, 392.00), (0, 0, 0), (659.25, 0, 0), (587.33, 0, 0),
            (523.25, 196.00, 293.66), (0, 0, 0), (440.00, 0, 0), (0, 0, 0),
            (392.00, 196.00, 261.63), (0, 0, 0), (0, 0, 0), (0, 0, 0)
        ]
        let matchFull = matchA + matchB + matchA + matchC
        if let p = makeLoopingBGMPlayer(
            from: synthesizeRichPentatonicBGM(steps: matchFull, stepDuration: 0.44, brightness: 0.14, padWarmth: 0.22),
            volume: 0.13
        ) {
            bgmPlayers[.match] = p
        }

        // 2B. Dynamic Match Tension Layer (gentle taiko/woodblock pulse layered over Match BGM during Ko/Atari/Byo-yomi)
        if let tp = makeLoopingBGMPlayer(
            from: synthesizeTensionPulseLoop(beats: 16, stepDuration: 0.44),
            volume: 0.0
        ) {
            tensionPlayer = tp
        }

        // 3. Boss Duel (Energetic 32-step shamisen/marimba groove)
        let bossA: [(Double, Double, Double)] = [
            (440.00, 220.00, 329.63), (523.25, 0, 0), (587.33, 293.66, 0), (659.25, 0, 0),
            (783.99, 329.63, 440.00), (659.25, 0, 0), (587.33, 293.66, 0), (523.25, 0, 0),
            (440.00, 220.00, 329.63), (659.25, 0, 0), (783.99, 329.63, 0), (880.00, 0, 0),
            (783.99, 329.63, 440.00), (659.25, 293.66, 0), (587.33, 220.00, 0), (523.25, 196.00, 0)
        ]
        let bossB: [(Double, Double, Double)] = [
            (880.00, 220.00, 329.63), (0, 0, 0), (783.99, 293.66, 0), (659.25, 0, 0),
            (783.99, 261.63, 392.00), (880.00, 0, 0), (1046.50, 329.63, 0), (880.00, 0, 0),
            (783.99, 293.66, 440.00), (659.25, 0, 0), (587.33, 220.00, 0), (659.25, 0, 0),
            (523.25, 196.00, 293.66), (587.33, 0, 0), (440.00, 220.00, 0), (0, 0, 0)
        ]
        if let p = makeLoopingBGMPlayer(
            from: synthesizeRichPentatonicBGM(steps: bossA + bossB, stepDuration: 0.24, brightness: 0.28, padWarmth: 0.14),
            volume: 0.17
        ) {
            bgmPlayers[.boss] = p
        }
    }

    private func makeLoopingBGMPlayer(from wavData: Data, volume: Float) -> AVAudioPlayer? {
        guard let player = try? AVAudioPlayer(data: wavData) else { return nil }
        player.volume = volume
        player.numberOfLoops = -1
        player.prepareToPlay()
        return player
    }

    // MARK: - Physical Modal SFX Bank

    private func prepareSynthesizedSounds() {
        // 6 subtle Kaya-wood + Clamshell/Slate stone variants for zero mechanical repetition
        let stoneConfigs: [(Double, Double, Double, UInt32)] = [
            (1380, 295, 680, 0x1357_2468),
            (1445, 312, 710, 0x2468_1357),
            (1310, 282, 655, 0x3579_4680),
            (1495, 324, 730, 0x4680_3579),
            (1355, 302, 695, 0x5791_6802),
            (1415, 290, 670, 0x6802_5791)
        ]
        players["stone"] = stoneConfigs.enumerated().compactMap { idx, cfg in
            loadBundledOrSynthesized(resourceName: "stone_\(idx + 1)", volume: 0.78) {
                self.synthesizePhysicalStoneClack(shellFreq: cfg.0, woodBodyFreq: cfg.1, plateFreq: cfg.2, seed: cfg.3)
            }
        }

        // Edge of board: crisper, tighter wood cavity
        players["stoneEdge"] = [
            (1590.0, 358.0, 790.0, UInt32(0xA1B2_C3D4)),
            (1655.0, 372.0, 825.0, UInt32(0xB2C3_D4E5)),
            (1545.0, 346.0, 775.0, UInt32(0xC3D4_E5F6))
        ].compactMap { cfg in
            makePlayer(from: synthesizePhysicalStoneClack(shellFreq: cfg.0, woodBodyFreq: cfg.1, plateFreq: cfg.2, seed: cfg.3), volume: 0.74)
        }

        // Center of board (Tengen / middle): deeper, warmer hollow Kaya wood belly resonance
        players["stoneCenter"] = [
            (1225.0, 248.0, 595.0, UInt32(0xD4E5_F607)),
            (1270.0, 260.0, 620.0, UInt32(0xE5F6_0718)),
            (1195.0, 240.0, 580.0, UInt32(0xF607_1829))
        ].compactMap { cfg in
            makePlayer(from: synthesizePhysicalStoneClack(shellFreq: cfg.0, woodBodyFreq: cfg.1, plateFreq: cfg.2, seed: cfg.3), volume: 0.84)
        }

        // Atari snap: decisive sharp stone strike with subtle high harmonic shimmer
        players["stoneAtari"] = [
            makePlayer(from: synthesizePhysicalStoneClack(shellFreq: 1760, woodBodyFreq: 335, plateFreq: 860, seed: 0x9988_7766, crispness: 1.32), volume: 0.88),
            makePlayer(from: synthesizePhysicalStoneClack(shellFreq: 1810, woodBodyFreq: 345, plateFreq: 890, seed: 0x8877_6655, crispness: 1.32), volume: 0.88)
        ].compactMap { $0 }

        // Wooden Go-ke bowl capture cascades
        players["captureSmall"] = [
            makePlayer(from: synthesizeGoBowlCapture(stoneCount: 2, seed: 0x1122), volume: 0.80),
            makePlayer(from: synthesizeGoBowlCapture(stoneCount: 2, seed: 0x3344), volume: 0.80)
        ].compactMap { $0 }
        players["captureBig"] = [
            makePlayer(from: synthesizeGoBowlCapture(stoneCount: 4, seed: 0x5566), volume: 0.84)
        ].compactMap { $0 }
        players["captureMassive"] = [
            makePlayer(from: synthesizeGoBowlCapture(stoneCount: 7, seed: 0x7788), volume: 0.90)
        ].compactMap { $0 }

        if let p = makePlayer(from: synthesizeChime(frequencies: [523.25, 659.25, 783.99, 1046.5, 1318.5, 1567.98], stepDuration: 0.055), volume: 0.48) {
            players["wonder"] = [p]
        }
        if let p = makePlayer(from: synthesizeChime(frequencies: [740.0, 987.77], stepDuration: 0.040), volume: 0.36) {
            players["stickerPop"] = [p]
        }
        if let p = makePlayer(from: synthesizeUITap(freq: 390, duration: 0.048), volume: 0.20) {
            players["lockedDoor"] = [p]
        }
        players["uiTap"] = [
            makePlayer(from: synthesizeUITap(freq: 900), volume: 0.26),
            makePlayer(from: synthesizeUITap(freq: 945), volume: 0.26)
        ].compactMap { $0 }
        players["gridTick"] = [
            makePlayer(from: synthesizeUITap(freq: 1460, duration: 0.022), volume: 0.14),
            makePlayer(from: synthesizeUITap(freq: 1520, duration: 0.022), volume: 0.14)
        ].compactMap { $0 }
        if let p = makePlayer(from: synthesizeUITap(freq: 1180, duration: 0.045), volume: 0.34) {
            players["countdownUrgent"] = [p]
        }
        if let p = makePlayer(from: synthesizeChime(frequencies: [440.0, 349.23], stepDuration: 0.055), volume: 0.34) {
            players["undo"] = [p]
        }
        if let p = makePlayer(from: synthesizeChime(frequencies: [659.25, 880.0], stepDuration: 0.075), volume: 0.42) {
            players["hint"] = [p]
        }
        if let p = makePlayer(from: synthesizeChime(frequencies: [523.25, 659.25, 783.99, 1046.5], stepDuration: 0.08), volume: 0.50) {
            players["success"] = [p]
        }
        if let p = makePlayer(from: synthesizeChime(frequencies: [523.25, 587.33, 659.25, 783.99, 1046.5], stepDuration: 0.09), volume: 0.54) {
            players["victory"] = [p]
        }
        if let p = makePlayer(from: synthesizeChime(frequencies: [523.25, 659.25, 783.99, 1046.5, 1318.5], stepDuration: 0.085), volume: 0.56) {
            players["bossVictory"] = [p]
        }
        if let p = makePlayer(from: synthesizeChime(frequencies: [659.25, 783.99, 1046.5, 1318.5], stepDuration: 0.065), volume: 0.48) {
            players["codexUnlock"] = [p]
        }
        if let p = makePlayer(from: synthesizeHollowKnock(), volume: 0.46) {
            players["wrong"] = [p]
        }
        if let p = makePlayer(from: synthesizeBouncePop(), volume: 0.45) {
            players["koBounce"] = [p]
        }
        if let p = makePlayer(from: synthesizeChime(frequencies: [880.0, 1174.66], stepDuration: 0.045), volume: 0.28) {
            players["firefly"] = [p]
        }
        if let p = makePlayer(from: synthesizeChime(frequencies: [880.0, 783.99, 659.25, 587.33, 523.25], stepDuration: 0.065), volume: 0.46) {
            players["hourglass"] = [p]
        }
    }

    private func makePlayer(from wavData: Data, volume: Float) -> AVAudioPlayer? {
        guard let player = try? AVAudioPlayer(data: wavData) else { return nil }
        player.volume = volume
        player.enableRate = true
        player.prepareToPlay()
        return player
    }

    // MARK: - Physical Modal PCM WAV Synthesis

    /// Synthesizes a realistic 3-layer Kaya wood + Clamshell/Slate stone impact with early room reflection.
    private func synthesizePhysicalStoneClack(
        shellFreq: Double,
        woodBodyFreq: Double,
        plateFreq: Double,
        seed: UInt32,
        crispness: Double = 1.0
    ) -> Data {
        let sampleRate = 44100
        let duration = 0.145
        let count = Int(Double(sampleRate) * duration)
        var raw = [Double](repeating: 0, count: count)

        var noiseState: UInt32 = seed
        var lpNoise = 0.0

        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            noiseState = noiseState &* 1664525 &+ 1013904223
            let white = Double(Int32(bitPattern: noiseState)) / Double(Int32.max)
            // Band-shaped contact transient noise
            lpNoise = lpNoise * 0.62 + white * 0.38
            let hpTransient = white - lpNoise

            // Layer 1: Micro-transient fingernail/stone contact click (~2ms)
            let contactEnv = exp(-t * 420.0)
            let contact = hpTransient * 0.55 * contactEnv * crispness

            // Layer 2: Inharmonic clamshell/slate stone modes (~12ms)
            let shellEnv = exp(-t * 175.0)
            let shell = (
                sin(2.0 * .pi * shellFreq * t) * 0.50 +
                sin(2.0 * .pi * (shellFreq * 1.73) * t) * 0.28 +
                sin(2.0 * .pi * (shellFreq * 2.67) * t) * 0.14
            ) * shellEnv * crispness

            // Layer 3: Warm Kaya wood cavity + plate resonance with subtle pitch-drop on strike
            let pitchDrop = 1.0 + 0.08 * exp(-t * 90.0)
            let woodEnv = exp(-t * 44.0)
            let plateEnv = exp(-t * 78.0)
            let wood = sin(2.0 * .pi * (woodBodyFreq * pitchDrop) * t) * 0.62 * woodEnv
                + sin(2.0 * .pi * plateFreq * t) * 0.26 * plateEnv
                + sin(2.0 * .pi * (woodBodyFreq * 0.52) * t) * 0.18 * exp(-t * 32.0)

            let attack = min(1.0, t / 0.0009)
            raw[i] = (contact * 0.42 + shell * 0.46 + wood * 0.64) * attack
        }

        // Subtle wooden-table early reflection tail (11ms & 23ms)
        let d1 = Int(0.011 * Double(sampleRate))
        let d2 = Int(0.023 * Double(sampleRate))
        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            var v = raw[i]
            if i >= d1 { v += raw[i - d1] * 0.16 }
            if i >= d2 { v += raw[i - d2] * 0.08 }
            // Soft tanh saturation for warm analog-like punch
            let sat = tanh(v * 1.15)
            samples[i] = Int16(max(-0.98, min(0.98, sat)) * 30500.0)
        }
        return encodeWAV(samples: samples, sampleRate: sampleRate)
    }

    /// Synthesizes captured stones tumbling into a wooden Go-ke (棋笥) bowl.
    private func synthesizeGoBowlCapture(stoneCount: Int, seed: UInt32) -> Data {
        let sampleRate = 44100
        let duration = 0.068 * Double(stoneCount) + 0.18
        let count = Int(Double(sampleRate) * duration)
        var mix = [Double](repeating: 0, count: count)

        var rng = seed
        func nextRand() -> Double {
            rng = rng &* 1664525 &+ 1013904223
            return Double(rng & 0xFFFF) / 65535.0
        }

        var cursor = 0.0
        for p in 0..<stoneCount {
            let offset = cursor
            cursor += 0.042 + nextRand() * 0.028
            let clinkFreq = 1650.0 + Double(p) * 145.0 + nextRand() * 190.0
            let bowlFreq = 310.0 + nextRand() * 55.0

            let startIdx = Int(offset * Double(sampleRate))
            let len = Int(0.11 * Double(sampleRate))
            for j in 0..<len where startIdx + j < count {
                let t = Double(j) / Double(sampleRate)
                let env = min(1.0, t / 0.001) * exp(-t * 72.0)
                let clink = (
                    sin(2.0 * .pi * clinkFreq * t) * 0.45 +
                    sin(2.0 * .pi * (clinkFreq * 1.61) * t) * 0.25
                ) * exp(-t * 145.0)
                let bowl = sin(2.0 * .pi * bowlFreq * t) * 0.48 * env
                mix[startIdx + j] += (clink + bowl) * 0.58
            }
        }

        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            samples[i] = Int16(max(-0.96, min(0.96, tanh(mix[i]))) * 29500.0)
        }
        return encodeWAV(samples: samples, sampleRate: sampleRate)
    }

    /// Synthesizes a long-form warm marimba + koto + soft pad pentatonic loop with gentle room tail.
    private func synthesizeRichPentatonicBGM(
        steps: [(Double, Double, Double)],
        stepDuration: Double,
        brightness: Double,
        padWarmth: Double
    ) -> Data {
        let sampleRate = 22050
        let totalDuration = stepDuration * Double(steps.count)
        let count = Int(Double(sampleRate) * totalDuration)
        var mix = [Double](repeating: 0, count: count)

        for (idx, chord) in steps.enumerated() {
            let start = Int(Double(idx) * stepDuration * Double(sampleRate))
            let noteLen = Int((stepDuration * 2.2) * Double(sampleRate))
            let (lead, bass, harmony) = chord

            for j in 0..<noteLen {
                let sampleIdx = (start + j) % count
                let t = Double(j) / Double(sampleRate)
                var val = 0.0
                if lead > 0 {
                    // Warm wooden marimba/koto pluck with harmonic decay
                    let attack = min(1.0, t / 0.009)
                    let fundEnv = attack * exp(-t * 5.2)
                    let overEnv = attack * exp(-t * 14.0)
                    val += (
                        sin(2.0 * .pi * lead * t) * (1.0 - brightness) * fundEnv +
                        sin(2.0 * .pi * lead * 2.0 * t) * brightness * 0.72 * overEnv +
                        sin(2.0 * .pi * lead * 3.0 * t) * brightness * 0.22 * overEnv
                    ) * 0.36
                }
                if bass > 0 {
                    let bEnv = min(1.0, t / 0.025) * exp(-t * 2.8)
                    val += (sin(2.0 * .pi * bass * t) * 0.80 + sin(2.0 * .pi * bass * 2.0 * t) * 0.20) * bEnv * 0.24
                }
                if harmony > 0 {
                    let pEnv = min(1.0, t / 0.090) * exp(-t * 1.9)
                    val += sin(2.0 * .pi * harmony * t) * pEnv * padWarmth
                }
                mix[sampleIdx] += val
            }
        }

        // Gentle circular stereo-feel warm reverb tap so the loop boundary is 100% seamless
        let tap1 = Int(0.115 * Double(sampleRate))
        let tap2 = Int(0.235 * Double(sampleRate))
        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let wet = mix[i]
                + mix[(i - tap1 + count) % count] * 0.18
                + mix[(i - tap2 + count) % count] * 0.09
            let clamped = max(-0.92, min(0.92, tanh(wet)))
            samples[i] = Int16(clamped * 27000.0)
        }
        return encodeWAV(samples: samples, sampleRate: sampleRate)
    }

    /// Synthesizes a subtle wooden taiko + hyoshigi rhythmic layer for tense Ko/Atari/Byo-yomi moments.
    private func synthesizeTensionPulseLoop(beats: Int, stepDuration: Double) -> Data {
        let sampleRate = 22050
        let count = Int(Double(sampleRate) * stepDuration * Double(beats))
        var mix = [Double](repeating: 0, count: count)

        for b in 0..<beats {
            let start = Int(Double(b) * stepDuration * Double(sampleRate))
            let isDownbeat = (b % 4 == 0)
            let isOffbeat = (b % 2 == 1)
            let len = Int(0.16 * Double(sampleRate))
            for j in 0..<len {
                let idx = (start + j) % count
                let t = Double(j) / Double(sampleRate)
                if isDownbeat {
                    let freq = 112.0 * (1.0 + 0.14 * exp(-t * 35.0))
                    let env = min(1.0, t / 0.004) * exp(-t * 18.0)
                    mix[idx] += sin(2.0 * .pi * freq * t) * env * 0.55
                } else if isOffbeat {
                    let env = min(1.0, t / 0.002) * exp(-t * 48.0)
                    mix[idx] += sin(2.0 * .pi * 820.0 * t) * env * 0.18
                }
            }
        }
        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            samples[i] = Int16(max(-0.92, min(0.92, mix[i])) * 26000.0)
        }
        return encodeWAV(samples: samples, sampleRate: sampleRate)
    }

    private func synthesizeBouncePop() -> Data {
        let sampleRate = 44100
        let duration = 0.16
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let env = min(1.0, t / 0.004) * exp(-t * 24.0)
            let pitch = 310.0 + 180.0 * sin(t * 36.0)
            let wave = sin(2.0 * .pi * pitch * t) * env
            samples[i] = Int16(max(-1.0, min(1.0, wave)) * 25000.0)
        }
        return encodeWAV(samples: samples, sampleRate: sampleRate)
    }

    private func synthesizeUITap(freq: Double, duration: Double = 0.04) -> Data {
        let sampleRate = 44100
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let env = min(1.0, t / 0.0015) * exp(-t * 140.0)
            let body = sin(2.0 * .pi * freq * t) * 0.72 + sin(2.0 * .pi * (freq * 1.5) * t) * 0.28
            let val = max(-1.0, min(1.0, body * env))
            samples[i] = Int16(val * 26000.0)
        }
        return encodeWAV(samples: samples, sampleRate: sampleRate)
    }

    private func synthesizeHollowKnock() -> Data {
        let sampleRate = 44100
        let duration = 0.14
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let env = min(1.0, t / 0.002) * exp(-t * 36.0)
            let pitch = 235.0 - t * 380.0
            let wave = sin(2.0 * .pi * max(110, pitch) * t) * 0.78 + sin(2.0 * .pi * 390.0 * t) * exp(-t * 80.0) * 0.22
            samples[i] = Int16(max(-1.0, min(1.0, wave * env)) * 27000.0)
        }
        return encodeWAV(samples: samples, sampleRate: sampleRate)
    }

    private func synthesizeChime(frequencies: [Double], stepDuration: Double) -> Data {
        let sampleRate = 44100
        let totalDuration = stepDuration * Double(frequencies.count) + 0.28
        let count = Int(Double(sampleRate) * totalDuration)
        var samples = [Int16](repeating: 0, count: count)

        for (idx, freq) in frequencies.enumerated() {
            let start = Int(Double(idx) * stepDuration * Double(sampleRate))
            let noteLen = Int((stepDuration + 0.24) * Double(sampleRate))
            for j in 0..<noteLen where start + j < count {
                let t = Double(j) / Double(sampleRate)
                let env = min(1.0, t / 0.006) * exp(-t * 8.5)
                let tone = (sin(2.0 * .pi * freq * t) * 0.72 + sin(2.0 * .pi * freq * 2.0 * t) * 0.20 + sin(2.0 * .pi * freq * 3.0 * t) * 0.08) * env
                let current = Double(samples[start + j]) / 32767.0
                let mixed = max(-1.0, min(1.0, current + tone * 0.44))
                samples[start + j] = Int16(mixed * 32000.0)
            }
        }
        return encodeWAV(samples: samples, sampleRate: sampleRate)
    }

    private func encodeWAV(samples: [Int16], sampleRate: Int) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        let chunkSize = 36 + dataSize

        var data = Data()
        data.reserveCapacity(Int(44 + dataSize))

        func appendUInt32(_ value: UInt32) {
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        func appendUInt16(_ value: UInt16) {
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: "RIFF".utf8)
        appendUInt32(chunkSize)
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(numChannels)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(byteRate)
        appendUInt16(blockAlign)
        appendUInt16(bitsPerSample)
        data.append(contentsOf: "data".utf8)
        appendUInt32(dataSize)

        samples.withUnsafeBufferPointer { ptr in
            data.append(UnsafeBufferPointer(
                start: UnsafeRawPointer(ptr.baseAddress)?.assumingMemoryBound(to: UInt8.self),
                count: Int(dataSize)
            ))
        }
        return data
    }
}
