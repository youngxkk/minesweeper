//
//  SoundAndHapticsManager.swift
//  StarYi Go
//

import AVFoundation
import UIKit

enum MusicMood: Equatable, Sendable {
    case none
    case island
    case match
    case boss
}

/// Synthesizes Nintendo-inspired tactile wooden UI clicks, authentic Kaya-wood Go stone clacks,
/// capture bowl cascades, discovery hint chimes, Codex unlock sparkles, victory fanfares,
/// AND gentle loopable pentatonic marimba/kalimba adaptive BGM — 100% procedural, zero assets.
@MainActor
final class SoundAndHapticsManager {
    static let shared = SoundAndHapticsManager()

    var soundEnabled: Bool = true
    var bgmEnabled: Bool = true {
        didSet { updateBGMPlayback() }
    }
    var zenDojoMode: Bool = false {
        didSet { updateBGMPlayback() }
    }
    var hapticsEnabled: Bool = true

    private let audio = GameAudioPlayback()
    private var currentMood: MusicMood = .none

    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        selectionFeedback.prepare()
        lightImpact.prepare()
    }

    func setMusicMood(_ mood: MusicMood) {
        currentMood = mood
        updateBGMPlayback()
    }

    func updateBGMPlayback() {
        let mood = soundEnabled && bgmEnabled && !zenDojoMode ? currentMood : .none
        audio.updateMusic(to: mood)
    }

    private func playKey(_ key: String) {
        guard soundEnabled else { return }
        audio.playEffect(key)
    }

    // MARK: - Public Feedback Triggers

    func playUITap() {
        playKey("uiTap")
        if hapticsEnabled { softImpact.impactOccurred(intensity: 0.55) }
    }

    func playGridTick() {
        playKey("gridTick")
        if hapticsEnabled {
            selectionFeedback.selectionChanged()
            selectionFeedback.prepare()
        }
    }

    func playStonePlace() {
        playKey("stone")
        if hapticsEnabled { lightImpact.impactOccurred(intensity: 0.80) }
    }

    func playCapture(count: Int = 1) {
        playKey(count >= 3 ? "captureBig" : "captureSmall")
        if hapticsEnabled { mediumImpact.impactOccurred(intensity: count >= 3 ? 1.0 : 0.85) }
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

}

// The serial queue owns the audio session setup and all player access.
private final class GameAudioPlayback: @unchecked Sendable {
    private let queue = DispatchQueue(label: "StarYiGo.audio", qos: .userInitiated)
    private var players: [String: [AVAudioPlayer]] = [:]
    private var bgmPlayers: [MusicMood: AVAudioPlayer] = [:]

    init() {
        queue.async {
            self.configureAudioSession()
            self.prepareSynthesizedSounds()
            self.prepareAdaptiveBGM()
        }
    }

    func updateMusic(to currentMood: MusicMood) {
        queue.async {
            for (mood, player) in self.bgmPlayers {
                if mood == currentMood {
                    if !player.isPlaying { player.play() }
                } else if player.isPlaying {
                    player.pause()
                }
            }
        }
    }

    func playEffect(_ key: String) {
        queue.async {
            guard let chosen = self.players[key]?.randomElement() else { return }
            chosen.currentTime = 0
            chosen.play()
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Silently ignore in simulator/preview environments
        }
    }

    private func prepareAdaptiveBGM() {
        // Cheerful Nintendo Island Marimba loop (C major pentatonic, 8 bars, 16 beats)
        let islandNotes: [(Double, Double)] = [
            (523.25, 261.63), (659.25, 0), (783.99, 329.63), (659.25, 0),
            (880.00, 349.23), (783.99, 0), (659.25, 392.00), (587.33, 0),
            (523.25, 261.63), (587.33, 0), (659.25, 329.63), (783.99, 0),
            (1046.50, 392.00), (880.00, 0), (783.99, 261.63), (659.25, 0)
        ]
        if let p = makeLoopingBGMPlayer(from: synthesizePentatonicLoop(notes: islandNotes, stepDuration: 0.34, brightness: 0.24), volume: 0.17) {
            bgmPlayers[.island] = p
        }

        // Calm warm wooden Kalimba thinking loop
        let matchNotes: [(Double, Double)] = [
            (392.00, 196.00), (0, 0), (523.25, 0), (587.33, 261.63),
            (659.25, 0), (0, 0), (523.25, 220.00), (440.00, 0),
            (392.00, 196.00), (0, 0), (440.00, 0), (523.25, 261.63),
            (587.33, 0), (523.25, 0), (440.00, 196.00), (0, 0)
        ]
        if let p = makeLoopingBGMPlayer(from: synthesizePentatonicLoop(notes: matchNotes, stepDuration: 0.44, brightness: 0.14), volume: 0.14) {
            bgmPlayers[.match] = p
        }

        // Energetic Boss Duel pentatonic groove
        let bossNotes: [(Double, Double)] = [
            (440.00, 220.00), (523.25, 220.00), (587.33, 293.66), (659.25, 220.00),
            (783.99, 329.63), (659.25, 220.00), (587.33, 293.66), (523.25, 220.00),
            (440.00, 220.00), (659.25, 220.00), (783.99, 329.63), (880.00, 220.00),
            (783.99, 329.63), (659.25, 293.66), (587.33, 220.00), (523.25, 196.00)
        ]
        if let p = makeLoopingBGMPlayer(from: synthesizePentatonicLoop(notes: bossNotes, stepDuration: 0.24, brightness: 0.30), volume: 0.19) {
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

    // MARK: - SFX Synthesis

    private func prepareSynthesizedSounds() {
        let stoneVariants = [
            synthesizeStoneClack(baseFreq: 1360, bodyFreq: 305),
            synthesizeStoneClack(baseFreq: 1445, bodyFreq: 326),
            synthesizeStoneClack(baseFreq: 1295, bodyFreq: 292),
            synthesizeStoneClack(baseFreq: 1510, bodyFreq: 338)
        ]
        players["stone"] = stoneVariants.compactMap { makePlayer(from: $0, volume: 0.72) }

        if let p = makePlayer(from: synthesizeCaptureClack(pulses: 2), volume: 0.78) {
            players["captureSmall"] = [p]
        }
        if let p = makePlayer(from: synthesizeCaptureClack(pulses: 3), volume: 0.82) {
            players["captureBig"] = [p]
        }
        if let p = makePlayer(from: synthesizeUITap(freq: 390, duration: 0.048), volume: 0.20) {
            players["lockedDoor"] = [p]
        }
        if let p = makePlayer(from: synthesizeUITap(freq: 920), volume: 0.28) {
            players["uiTap"] = [p]
        }
        if let p = makePlayer(from: synthesizeUITap(freq: 1480, duration: 0.024), volume: 0.16) {
            players["gridTick"] = [p]
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
        player.prepareToPlay()
        return player
    }

    // MARK: - Procedural PCM WAV Synthesis

    private func synthesizePentatonicLoop(notes: [(Double, Double)], stepDuration: Double, brightness: Double) -> Data {
        let sampleRate = 22050
        let totalDuration = stepDuration * Double(notes.count)
        let count = Int(Double(sampleRate) * totalDuration)
        var mix = [Double](repeating: 0, count: count)

        for (idx, pair) in notes.enumerated() {
            let start = Int(Double(idx) * stepDuration * Double(sampleRate))
            let noteLen = Int((stepDuration * 1.45) * Double(sampleRate))
            let lead = pair.0
            let bass = pair.1

            for j in 0..<noteLen {
                let sampleIdx = (start + j) % count
                let t = Double(j) / Double(sampleRate)
                var val = 0.0
                if lead > 0 {
                    let env = min(1.0, t / 0.008) * exp(-t * 6.2)
                    val += (sin(2.0 * .pi * lead * t) * (1.0 - brightness) + sin(2.0 * .pi * lead * 2.0 * t) * brightness) * env * 0.42
                }
                if bass > 0 {
                    let bEnv = min(1.0, t / 0.012) * exp(-t * 4.5)
                    val += sin(2.0 * .pi * bass * t) * bEnv * 0.24
                }
                mix[sampleIdx] += val
            }
        }

        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let clamped = max(-0.92, min(0.92, mix[i]))
            samples[i] = Int16(clamped * 28000.0)
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

    private func synthesizeStoneClack(baseFreq: Double, bodyFreq: Double) -> Data {
        let sampleRate = 44100
        let duration = 0.095
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)

        var noiseState: UInt32 = 0x1234_5678
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let clickEnv = exp(-t * 165.0)
            let woodEnv = exp(-t * 46.0)

            noiseState = noiseState &* 1664525 &+ 1013904223
            let noise = Double(Int32(bitPattern: noiseState)) / Double(Int32.max)

            let click = (sin(2.0 * .pi * baseFreq * t) * 0.55 + sin(2.0 * .pi * (baseFreq * 1.62) * t) * 0.25 + noise * 0.42) * clickEnv
            let wood = (sin(2.0 * .pi * bodyFreq * t) * 0.65 + sin(2.0 * .pi * (bodyFreq * 2.08) * t) * 0.25) * woodEnv
            let attack = min(1.0, t / 0.0012)
            let value = max(-1.0, min(1.0, (click * 0.65 + wood * 0.55) * attack))
            samples[i] = Int16(value * 30000.0)
        }
        return encodeWAV(samples: samples, sampleRate: sampleRate)
    }

    private func synthesizeCaptureClack(pulses: Int) -> Data {
        let sampleRate = 44100
        let duration = 0.07 * Double(pulses) + 0.09
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)

        for p in 0..<pulses {
            let offset = Double(p) * 0.055
            let freqBoost = Double(p) * 210.0
            for i in 0..<count {
                let t = Double(i) / Double(sampleRate) - offset
                guard t >= 0 else { continue }
                let env = min(1.0, t / 0.0012) * exp(-t * 88.0)
                let wave = (sin(2.0 * .pi * (1420 + freqBoost) * t) * 0.48 + sin(2.0 * .pi * (340 + freqBoost * 0.35) * t) * 0.52) * env
                let current = Double(samples[i]) / 32767.0
                let mixed = max(-1.0, min(1.0, current + wave * 0.62))
                samples[i] = Int16(mixed * 29500.0)
            }
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
