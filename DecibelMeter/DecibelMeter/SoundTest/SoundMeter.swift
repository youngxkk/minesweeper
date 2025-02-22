//
//  SoundMeter.swift
//  DecibelMeter
//
//  Created by DEEP SEA on 2023/5/15.
//

import SwiftUI
import AVFoundation

class SoundMeter: ObservableObject {
    private var audioRecorder: AVAudioRecorder!
    
    @Published var decibels: Float = 0.0
    
    init() {
        setupAudioSession()
    }
    
    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let url = URL(fileURLWithPath: "/dev/null", isDirectory: true)
            
            let settings: [String: Any] = [
                AVFormatIDKey: NSNumber(value: kAudioFormatAppleLossless),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder.isMeteringEnabled = true
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func startMeasuring() {
        audioRecorder.record()
        // 定时器，每0.8秒更新一次分贝级别
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.audioRecorder.updateMeters()
            let decibels = self.audioRecorder.averagePower(forChannel: 0)
            self.decibels = self.scaleDecibels(decibels)
        }
    }
    
    func stopMeasuring() {
        audioRecorder.stop()
    }
//   这个公式目前是将原始的分贝值（范围在 -160 到 0）线性映射到 0 到 120 的范围,可以通过修改这个公式来调整灵敏度。
    private func scaleDecibels(_ decibels: Float) -> Float {
        return (decibels + 160) / 2
    }
}
