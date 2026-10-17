import Foundation
import AVFoundation

/// The primary dialogue speaker for games and apps.
/// Handles async text pacing, syllable vowel synthesis, zero-allocation vowel caching,
/// and lifecycle/viseme event emission.
public final class MumbleSpeaker: @unchecked Sendable {
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

    public init(profile: VoiceProfile = .youngWoman, typingSpeedMultiplier: Double = 1.0) {
        self.profile = profile
        self.typingSpeedMultiplier = typingSpeedMultiplier
        prewarmVowelCache()
    }

    /// Pre-renders the 6 standard phonetic vowels into memory (~50 KB)
    /// to avoid any DSP calculations or buffer allocations during gameplay.
    public func prewarmVowelCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        vowelCache.removeAll(keepingCapacity: true)
        let synth = FormantSynthesizer.shared
        for vowel in Vowel.allCases {
            if let buffer = synth.synthesizeVowel(
                vowel: vowel,
                pitch: profile.basePitch,
                profile: profile,
                amplitude: 0.85
            ) {
                vowelCache[vowel] = buffer
            }
        }
    }

    /// Speaks dialogue asynchronously, emitting viseme and character events as text types out.
    ///
    /// - Parameter text: The dialogue text, which may include inline tags like `{purr}` or `{shake}`.
    /// - Returns: The final displayed dialogue string.
    @discardableResult
    public func speak(_ text: String) async -> String {
        stop()

        isSpeaking = true
        displayedText = ""

        let task = Task<String, Never> { [weak self] in
            guard let self = self else { return "" }

            let cleanTarget = self.stripTags(from: text)
            let steps = self.textPacer.parse(text: text)
            let clauses = self.analyzeClauses(from: steps)
            let startTime = CACurrentMediaTime()

            for (index, step) in steps.enumerated() {
                if Task.isCancelled { break }

                switch step {
                case .soundEffect(let tag):
                    MumbleSpeechEngine.shared.playSoundEffect(named: tag)
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
