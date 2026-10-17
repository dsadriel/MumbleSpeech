import Foundation

/// Analyzes grammatical and punctuation cues to calculate pitch contour, declination, and amplitude.
public struct ProsodyEngine: Sendable {
    public init() {}

    public struct ProsodyResult: Sendable {
        public let pitch: Float
        public let amplitude: Float
    }

    /// Evaluates dynamic pitch and amplitude for a vowel sound at a given point in the sentence.
    ///
    /// - Parameters:
    ///   - profile: The character's acoustic settings.
    ///   - phrasePosition: 0.0 at phrase start to 1.0 at phrase boundary (comma/period).
    ///   - isNearQuestion: True if this phrase ends with a question mark.
    ///   - isExclamation: True if this phrase ends with an exclamation mark.
    ///   - isEllipsis: True if this phrase ends with trailing ellipsis.
    ///   - isAllUppercase: True if the current word is written in ALL-CAPS (shouting).
    ///   - timeElapsed: Total speech time in seconds (drives the LFO vibrato/tremor).
    public func calculateProsody(
        profile: VoiceProfile,
        phrasePosition: Float,
        isNearQuestion: Bool,
        isExclamation: Bool,
        isEllipsis: Bool,
        isAllUppercase: Bool,
        timeElapsed: Double
    ) -> ProsodyResult {
        let baseF0 = profile.basePitch

        // 1. Natural phrase declination drift:
        // Pitch starts slightly elevated (~ +8%) and drifts down (~ -12%) towards the end of the phrase.
        var phraseDrift = 1.08 - (phrasePosition * 0.20)

        // 2. Exclamation mark: starts phrase significantly higher and maintains excitement
        if isExclamation {
            phraseDrift += 0.15
        }

        // 3. Question mark: pitch curves upward on the final 30% of the question phrase
        var questionRise: Float = 0.0
        if isNearQuestion && phrasePosition > 0.65 {
            let questionProgress = (phrasePosition - 0.65) / 0.35
            questionRise = questionProgress * 0.32 // up to +32% pitch rise
        }

        // 4. Word shout (ALL CAPS): higher pitch
        let shoutFactor: Float = isAllUppercase ? 1.18 : 1.0

        // 5. Vibrato / Tremor LFO: slow steady wobble (rate ~2 Hz)
        var vibratoOffset: Float = 0.0
        if profile.vibratoDepth > 0.001 {
            let lfo = sin(Float(2.0 * Double.pi * Double(profile.vibratoRate) * timeElapsed))
            vibratoOffset = lfo * profile.vibratoDepth
        }

        // Calculate combined pitch frequency
        let totalPitch = baseF0 * (phraseDrift + questionRise + vibratoOffset) * shoutFactor

        // 6. Amplitude calculation
        var amplitude: Float = 0.85
        if isAllUppercase {
            amplitude = 1.0 // Shouts are louder
        } else if isExclamation {
            amplitude = 0.95
        }

        // 7. Ellipsis fade out: gradual decay in volume near the end
        if isEllipsis && phrasePosition > 0.4 {
            let fadeProgress = (phrasePosition - 0.4) / 0.6
            amplitude *= max(0.2, 1.0 - (fadeProgress * 0.75))
        }

        return ProsodyResult(
            pitch: max(50.0, min(800.0, totalPitch)),
            amplitude: max(0.1, min(1.0, amplitude))
        )
    }
}
