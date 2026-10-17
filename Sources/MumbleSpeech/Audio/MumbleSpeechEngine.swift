import Foundation
import AVFoundation

/// Manages real-time audio playback using AVAudioEngine with an overlapping player node pool.
public final class MumbleSpeechEngine: @unchecked Sendable {
    public static let shared = MumbleSpeechEngine()

    public enum SoundEffectSource: @unchecked Sendable {
        case buffer(AVAudioPCMBuffer)
        case file(URL)
        case custom(@Sendable () -> Void)
    }

    private let audioEngine = AVAudioEngine()
    private let mixerNode = AVAudioMixerNode()

    // Round-robin player pool for seamless overlapping vowel playback
    private let poolSize = 6
    private var playerNodes: [AVAudioPlayerNode] = []
    private var nextPlayerIndex = 0

    private var soundEffects: [String: SoundEffectSource] = [:]

    private let lock = NSRecursiveLock()
    private var isEngineRunning = false

    public init() {
        setupEngine()
    }

    private func setupEngine() {
        audioEngine.attach(mixerNode)
        audioEngine.connect(mixerNode, to: audioEngine.mainMixerNode, format: FormantSynthesizer.shared.audioFormat)

        for _ in 0..<poolSize {
            let player = AVAudioPlayerNode()
            audioEngine.attach(player)
            audioEngine.connect(player, to: mixerNode, format: FormantSynthesizer.shared.audioFormat)
            playerNodes.append(player)
        }

        startEngineIfNeeded()
    }

    public func startEngineIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        guard !audioEngine.isRunning else {
            isEngineRunning = true
            return
        }

        do {
            try audioEngine.start()
            isEngineRunning = true
            for player in playerNodes {
                player.play()
            }
        } catch {
            print("Failed to start AVAudioEngine: \(error)")
        }
    }

    /// Registers a sound effect using an in-memory PCM buffer.
    public func registerSoundEffect(named name: String, buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        soundEffects[name.lowercased()] = .buffer(buffer)
    }

    /// Registers a sound effect from an audio file URL (.wav, .mp3, .caf, .aif).
    public func registerSoundEffect(named name: String, url: URL) {
        lock.lock()
        defer { lock.unlock() }
        soundEffects[name.lowercased()] = .file(url)
    }

    /// Registers a custom closure or playback callback for a sound effect tag.
    public func registerSoundEffect(named name: String, action: @Sendable @escaping () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        soundEffects[name.lowercased()] = .custom(action)
    }

    /// Plays a synthesized vowel sound buffer with smooth overlap.
    public func playVowel(buffer: AVAudioPCMBuffer, volume: Float = 1.0) {
        lock.lock()
        defer { lock.unlock() }

        startEngineIfNeeded()

        guard !playerNodes.isEmpty else { return }

        let player = playerNodes[nextPlayerIndex]
        nextPlayerIndex = (nextPlayerIndex + 1) % playerNodes.count

        player.volume = max(0.0, min(1.0, volume))
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    /// Plays a registered sound effect or built-in procedural fallback.
    public func playSoundEffect(named sfx: String) {
        lock.lock()
        let effect = soundEffects[sfx.lowercased()]
        lock.unlock()

        if let effect = effect {
            switch effect {
            case .buffer(let buffer):
                playVowel(buffer: buffer)
            case .file(let url):
                playAudioFile(url: url)
            case .custom(let action):
                action()
            }
        } else if sfx.lowercased() == "purr" {
            // Built-in procedural cat purr fallback
            synthesizeAndPlayPurr()
        }
    }

    func playAudioFile(url: URL) {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            lock.lock()
            defer { lock.unlock() }

            startEngineIfNeeded()
            guard !playerNodes.isEmpty else { return }

            let player = playerNodes[nextPlayerIndex]
            nextPlayerIndex = (nextPlayerIndex + 1) % playerNodes.count

            player.scheduleFile(audioFile, at: nil, completionHandler: nil)
            if !player.isPlaying {
                player.play()
            }
        } catch {
            print("Failed to load sound effect at \(url): \(error)")
        }
    }

    private func synthesizeAndPlayPurr() {
        let sampleRate = FormantSynthesizer.shared.sampleRate
        let duration = 0.35
        let totalSamples = Int(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: FormantSynthesizer.shared.audioFormat,
            frameCapacity: AVAudioFrameCount(totalSamples)
        ), let data = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(totalSamples)

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let purrLFO = sin(2.0 * .pi * 24.0 * t) // 24 Hz motor purr
            let carrier = sin(2.0 * .pi * 180.0 * t)
            let env = sin(Double(i) / Double(totalSamples) * .pi)
            let noise = Float.random(in: -0.15...0.15)
            data[i] = Float(purrLFO * carrier * env * 0.4) + noise * Float(env * 0.2)
        }

        playVowel(buffer: buffer, volume: 0.9)
    }

    /// Immediately stops all currently playing and queued audio.
    public func stopAll() {
        lock.lock()
        defer { lock.unlock() }

        for player in playerNodes {
            player.stop()
            player.play()
        }
    }
}
