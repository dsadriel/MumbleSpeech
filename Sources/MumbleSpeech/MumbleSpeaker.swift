import Foundation
import AVFoundation

/// The primary dialogue speaker for games and apps.
/// Handles async text pacing, syllable vowel synthesis, zero-allocation vowel caching,
/// generic inline cue effects (audio, animation, haptics), and lifecycle/viseme event emission.
public final class MumbleSpeaker: @unchecked Sendable {
    /// Shared singleton instance for centralized, app-wide or game-wide dialogue management.
    public static let shared = MumbleSpeaker()

    /// Types of effects that can be registered for inline dialogue tags like "{tag}".
    public enum Effect: @unchecked Sendable {
        case buffer(AVAudioPCMBuffer)
        case file(URL)
        case action(@Sendable () -> Void)
    }

    /// Backwards-compatible typealias
    public typealias SoundEffect = Effect

    public var profile: VoiceProfile {
        didSet {
            prewarmVowelCache()
        }
    }

    public var typingSpeedMultiplier: Double = 1.0

    /// Callback invoked on the main thread for game animation, visemes, and state.
    public var onEvent: (@MainActor @Sendable (DialogueEvent) -> Void)?

    public private(set) var isSpeaking: Bool = false
    public private(set) var displayedText: String = ""

    private var activeSpeechTask: Task<String, Never>? = nil
    private let textPacer = TextPacer()
    private let prosodyEngine = ProsodyEngine()

    // Pre-warmed vowel buffer bank for zero allocation during game loops
    private var vowelCache: [Vowel: AVAudioPCMBuffer] = [:]
    private let cacheLock = NSLock()

    // Instance-specific effects that can override or supplement global ones
    private var localEffects: [String: Effect] = [:]
    private let effectsLock = NSLock()

    /// Creates a MumbleSpeaker with optional voice profile, speed, and effect dictionary.
    public init(
        profile: VoiceProfile = .youngWoman,
        typingSpeedMultiplier: Double = 1.0,
        effects: [String: Effect] = [:]
    ) {
        self.profile = profile
        self.typingSpeedMultiplier = typingSpeedMultiplier
        self.localEffects = effects
        prewarmVowelCache()
    }

    /// Backwards-compatible convenience initializer using `soundEffects`.
    public convenience init(
        profile: VoiceProfile = .youngWoman,
        typingSpeedMultiplier: Double = 1.0,
        soundEffects: [String: Effect]
    ) {
        self.init(profile: profile, typingSpeedMultiplier: typingSpeedMultiplier, effects: soundEffects)
    }

    // MARK: - Static (Global) Effect Registration

    /// Registers a global effect using the `Effect` enum (.file, .buffer, or .action).
    /// Affects all speakers and NPC instances across the app/game.
    public static func registerEffect(named name: String, effect: Effect) {
        switch effect {
        case .buffer(let buffer):
            registerEffect(named: name, buffer: buffer)
        case .file(let url):
            registerEffect(named: name, url: url)
        case .action(let action):
            registerEffect(named: name, action: action)
        }
    }

    /// Registers a global in-memory PCM buffer for inline dialogue tags like "{snort}".
    public static func registerEffect(named name: String, buffer: AVAudioPCMBuffer) {
        MumbleSpeechEngine.shared.registerEffect(named: name, buffer: buffer)
    }

    /// Registers a global audio file URL (.wav, .mp3, etc.) for inline dialogue tags like "{chime}".
    public static func registerEffect(named name: String, url: URL) {
        MumbleSpeechEngine.shared.registerEffect(named: name, url: url)
    }

    /// Registers a global callback closure for inline tags like "{shake_screen}" or custom game actions.
    public static func registerEffect(named name: String, action: @Sendable @escaping () -> Void) {
        MumbleSpeechEngine.shared.registerEffect(named: name, action: action)
    }

    // Backwards-compatible static aliases
    public static func registerSoundEffect(named name: String, effect: Effect) {
        registerEffect(named: name, effect: effect)
    }
    public static func registerSoundEffect(named name: String, buffer: AVAudioPCMBuffer) {
        registerEffect(named: name, buffer: buffer)
    }
    public static func registerSoundEffect(named name: String, url: URL) {
        registerEffect(named: name, url: url)
    }
    public static func registerSoundEffect(named name: String, action: @Sendable @escaping () -> Void) {
        registerEffect(named: name, action: action)
    }

    // MARK: - Instance-Specific Effect Registration

    /// Registers an instance-specific effect that applies only to this speaker instance.
    public func registerEffect(named name: String, effect: Effect) {
        effectsLock.lock()
        defer { effectsLock.unlock() }
        localEffects[name.lowercased()] = effect
    }

    /// Registers an instance-specific in-memory PCM buffer.
    public func registerEffect(named name: String, buffer: AVAudioPCMBuffer) {
        registerEffect(named: name, effect: .buffer(buffer))
    }

    /// Registers an instance-specific audio file URL.
    public func registerEffect(named name: String, url: URL) {
        registerEffect(named: name, effect: .file(url))
    }

    /// Registers an instance-specific callback closure.
    public func registerEffect(named name: String, action: @Sendable @escaping () -> Void) {
        registerEffect(named: name, effect: .action(action))
    }

    // Backwards-compatible instance aliases
    public func registerSoundEffect(named name: String, effect: Effect) {
        registerEffect(named: name, effect: effect)
    }
    public func registerSoundEffect(named name: String, buffer: AVAudioPCMBuffer) {
        registerEffect(named: name, buffer: buffer)
    }
    public func registerSoundEffect(named name: String, url: URL) {
        registerEffect(named: name, url: url)
    }
    public func registerSoundEffect(named name: String, action: @Sendable @escaping () -> Void) {
        registerEffect(named: name, action: action)
    }

    /// Centralized configuration helper for `MumbleSpeaker.shared`.
    /// Call once at game/app launch to set global effects and default voice.
    public static func configure(
        profile: VoiceProfile? = nil,
        typingSpeedMultiplier: Double? = nil,
        effects: [String: Effect] = [:]
    ) {
        if let profile = profile {
            shared.profile = profile
        }
        if let speed = typingSpeedMultiplier {
            shared.typingSpeedMultiplier = speed
        }
        for (name, effect) in effects {
            registerEffect(named: name, effect: effect)
        }
    }

    public static func configure(
        profile: VoiceProfile? = nil,
        typingSpeedMultiplier: Double? = nil,
        soundEffects: [String: Effect]
    ) {
        configure(profile: profile, typingSpeedMultiplier: typingSpeedMultiplier, effects: soundEffects)
    }

    /// Pre-synthesizes all base vowels for this speaker's voice profile.
    public func prewarmVowelCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        vowelCache.removeAll(keepingCapacity: true)

        let synth = FormantSynthesizer.shared
        for vowel in Vowel.allCases {
            if let buffer = synth.synthesizeVowel(vowel: vowel, pitch: profile.basePitch, profile: profile) {
                vowelCache[vowel] = buffer
            }
        }
    }

    // MARK: - Dialogue Playback

    /// Types and vocalizes a dialogue string asynchronously.
    @discardableResult
    public func speak(_ text: String) async -> String {
        // Stop any ongoing speech
        stop()

        isSpeaking = true
        displayedText = ""

        let cleanTarget = stripTags(from: text)
        let steps = textPacer.parse(text: text)
        let clauses = analyzeClauses(from: steps)

        let task = Task<String, Never> { [weak self] () -> String in
            guard let self = self else { return "" }
            let startTime = CACurrentMediaTime()

            for (index, step) in steps.enumerated() {
                if Task.isCancelled { break }

                switch step {
                case .effect(let tag):
                    self.triggerEffect(named: tag)
                    await self.emitEvent(.tag(tag))

                case .character(let char, let delay, let isVowelStart, let cluster):
                    self.displayedText.append(char)
                    await self.emitEvent(.character(char, displayedText: self.displayedText))

                    if isVowelStart, let vowelCluster = cluster {
                        let vowel = Vowel.from(cluster: vowelCluster)
                        let clauseInfo = clauses[index]
                        let timeElapsed = CACurrentMediaTime() - startTime

                        let prosody = self.prosodyEngine.calculateProsody(
                            profile: self.profile,
                            phrasePosition: clauseInfo.phrasePosition,
                            isNearQuestion: clauseInfo.isQuestion,
                            isExclamation: clauseInfo.isExclamation,
                            isEllipsis: clauseInfo.isEllipsis,
                            isAllUppercase: clauseInfo.isAllUppercase,
                            timeElapsed: timeElapsed
                        )

                        // Play vowel (using cached buffer or dynamically synthesized)
                        self.playVowel(vowel, pitch: prosody.pitch, amplitude: prosody.amplitude)

                        // Emit viseme event for 2D/3D mouth animation
                        await self.emitEvent(.vowel(
                            vowel,
                            mouthOpenness: vowel.mouthOpenness,
                            pitch: prosody.pitch
                        ))
                    }

                    // Punctuation delay
                    let effectiveDelay = delay / max(0.2, self.typingSpeedMultiplier)
                    let nanos = UInt64(effectiveDelay * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanos)
                }
            }

            if Task.isCancelled {
                return self.displayedText
            }

            self.displayedText = cleanTarget
            self.isSpeaking = false
            await self.emitEvent(.completed(fullText: cleanTarget))
            return cleanTarget
        }

        activeSpeechTask = task
        return await task.value
    }

    /// Triggers an effect, checking instance-specific registrations first, then falling back to global engine registrations.
    private func triggerEffect(named tag: String) {
        effectsLock.lock()
        let local = localEffects[tag.lowercased()]
        effectsLock.unlock()

        if let local = local {
            switch local {
            case .buffer(let buffer):
                MumbleSpeechEngine.shared.playVowel(buffer: buffer)
            case .file(let url):
                MumbleSpeechEngine.shared.playAudioFile(url: url)
            case .action(let action):
                action()
            }
        } else {
            // Fallback to globally registered effect
            MumbleSpeechEngine.shared.triggerEffect(named: tag)
        }
    }

    /// Immediately finishes typing, reveals all text, and silences speech sound.
    public func skip() {
        guard isSpeaking, let task = activeSpeechTask else { return }
        task.cancel()
        activeSpeechTask = nil

        MumbleSpeechEngine.shared.stopAll()
        isSpeaking = false

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.onEvent?(.interrupted)
        }
    }

    /// Stops playback and cuts sound immediately.
    public func stop() {
        activeSpeechTask?.cancel()
        activeSpeechTask = nil
        MumbleSpeechEngine.shared.stopAll()
        isSpeaking = false
    }

    // MARK: - Audio Playback Dispatch
    private func playVowel(_ vowel: Vowel, pitch: Float, amplitude: Float) {
        cacheLock.lock()
        let cached = vowelCache[vowel]
        cacheLock.unlock()

        // If pitch is close to basePitch (within 5%), play cached buffer directly for zero DSP allocation
        if let cached = cached, abs(pitch - profile.basePitch) / profile.basePitch < 0.05 {
            MumbleSpeechEngine.shared.playVowel(buffer: cached, volume: amplitude)
        } else {
            // Synthesize with precise prosody pitch
            if let dynamicBuffer = FormantSynthesizer.shared.synthesizeVowel(
                vowel: vowel,
                pitch: pitch,
                profile: self.profile,
                amplitude: amplitude
            ) {
                MumbleSpeechEngine.shared.playVowel(buffer: dynamicBuffer, volume: amplitude)
            }
        }
    }

    private func emitEvent(_ event: DialogueEvent) async {
        await MainActor.run { [weak self] in
            self?.onEvent?(event)
        }
    }

    // MARK: - Private Analysis Helpers
    private func stripTags(from text: String) -> String {
        var result = ""
        var inTag = false
        for char in text {
            if char == "{" {
                inTag = true
            } else if char == "}" {
                inTag = false
            } else if !inTag {
                result.append(char)
            }
        }
        return result
    }

    private struct StepClauseInfo {
        let phrasePosition: Float
        let isQuestion: Bool
        let isExclamation: Bool
        let isEllipsis: Bool
        let isAllUppercase: Bool
    }

    private func analyzeClauses(from steps: [DialogueStep]) -> [StepClauseInfo] {
        var boundaryIndices: [Int] = []
        for (i, step) in steps.enumerated() {
            if case .character(let char, _, _, _) = step {
                if [",", ".", "?", "!", ";", ":"].contains(char) || i == steps.count - 1 {
                    boundaryIndices.append(i)
                }
            }
        }
        if boundaryIndices.isEmpty {
            boundaryIndices.append(steps.count - 1)
        }

        var currentBoundaryIdx = 0
        var phraseStart = 0
        var clauseInfos: [StepClauseInfo] = []
        clauseInfos.reserveCapacity(steps.count)

        for i in 0..<steps.count {
            while currentBoundaryIdx < boundaryIndices.count && boundaryIndices[currentBoundaryIdx] < i {
                phraseStart = boundaryIndices[currentBoundaryIdx] + 1
                currentBoundaryIdx += 1
            }

            let endIdx = (currentBoundaryIdx < boundaryIndices.count) ? boundaryIndices[currentBoundaryIdx] : (steps.count - 1)
            let phraseLength = max(1, endIdx - phraseStart)
            let position = Float(i - phraseStart) / Float(phraseLength)

            var isQ = false
            var isEx = false
            var isEl = false

            if endIdx < steps.count, case .character(let endChar, _, _, _) = steps[endIdx] {
                if endChar == "?" { isQ = true }
                if endChar == "!" { isEx = true }
                if endChar == "." && endIdx >= 2 {
                    if case .character(let c1, _, _, _) = steps[endIdx - 1], c1 == ".",
                       case .character(let c2, _, _, _) = steps[endIdx - 2], c2 == "." {
                        isEl = true
                    }
                }
            }

            var isUpper = false
            if case .character(let ch, _, _, _) = steps[i], ch.isLetter && ch.isUppercase {
                isUpper = true
            }

            clauseInfos.append(StepClauseInfo(
                phrasePosition: max(0.0, min(1.0, position)),
                isQuestion: isQ,
                isExclamation: isEx,
                isEllipsis: isEl,
                isAllUppercase: isUpper
            ))
        }

        return clauseInfos
    }
}
