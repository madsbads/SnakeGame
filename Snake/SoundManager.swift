//
//  SoundManager.swift
//  Snake
//
//  Created by Maddie Nevans on 3/29/25.
//

import AVFoundation

class SoundManager {
    private static var audioPlayer: AVAudioPlayer?

    private static func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Use playback category so sounds still play when the mute switch is on
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("AudioSession setup error: \(error)")
        }
    }

    static func playSound(sound: String, type: String) {
        // Lazily configure the audio session once
        configureAudioSession()

        // Grab the file URL from the bundle
        guard let url = Bundle.main.url(forResource: sound, withExtension: type) else {
            print("Sound file not found: \(sound).\(type)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Audio playback error: \(error)")
        }
    }
}
