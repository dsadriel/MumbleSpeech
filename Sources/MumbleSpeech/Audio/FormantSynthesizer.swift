import Foundation
import AVFoundation

/// Procedural digital signal processor that synthesizes warm, natural human-like vowel phonemes.
/// Uses a Rosenberg smooth glottal flow model with spectral tilt, filtered breath noise,
/// pulse-to-pulse shimmer/jitter, and 3-band resonant formant filters.
public final class FormantSynthesizer: @unchecked Sendable {
    public static let shared = FormantSynthesizer()

    public let sampleRate: Double = 44100.0
    public let audioFormat: AVAudioFormat

    public init() {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100.0,
            channels: 1,
            interleaved: false
        ) else {
            fatalError("Failed to initialize standard AVAudioFormat")
        }
        self.audioFormat = format
    }

    /// Synthesizes a natural, warm vowel burst PCM buffer.
    public func synthesizeVowel(
        vowel: Vowel,
        pitch: Float,
        profile: VoiceProfile,
        amplitude: Float = 0.8
    ) -> AVAudioPCMBuffer? {
        let duration = max(0.06, min(0.20, profile.vowelDuration))
        let totalSamples = Int(Double(duration) * sampleRate)
        guard totalSamples > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(totalSamples)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(totalSamples)

        guard let channelData = buffer.floatChannelData?[0] else {
            return nil
        }

        // 1. Calculate Formant Frequencies scaled by Vocal Tract Length
        let tractScale = max(0.6, min(1.8, profile.tractLengthScale))
        let f1 = min(Float(sampleRate * 0.42), vowel.baseFormants.f1 * tractScale)
        let f2 = min(Float(sampleRate * 0.42), vowel.baseFormants.f2 * tractScale)
        let f3 = min(Float(sampleRate * 0.42), vowel.baseFormants.f3 * tractScale)

        // Resonant biquad bandpass filters for F1, F2, F3
        var filter1 = ResonantFilter(centerFreq: f1, bandwidth: vowel.bandwidths.b1 * tractScale, sampleRate: Float(sampleRate))
        var filter2 = ResonantFilter(centerFreq: f2, bandwidth: vowel.bandwidths.b2 * tractScale, sampleRate: Float(sampleRate))
        var filter3 = ResonantFilter(centerFreq: f3, bandwidth: vowel.bandwidths.b3 * tractScale, sampleRate: Float(sampleRate))

        let gains = vowel.gains

        // 2. Swelling Envelope parameters proportional to duration
        let attackSamples = Int(min(0.018, Double(duration) * 0.20) * sampleRate)
        let releaseSamples = Int(min(0.028, Double(duration) * 0.35) * sampleRate)
        let sustainSamples = max(0, totalSamples - attackSamples - releaseSamples)

        var phase: Float = 0.0
        let basePitch = max(50.0, min(800.0, pitch))

        // Glottal state
        var jitterOffset: Float = 0.0
        var pulseShimmer: Float = 1.0
        var samplesUntilNextPeriod = 0

        // Filter state variables for warm acoustics
        var glottalTiltFilter: Float = 0.0
        var breathLowPassFilter: Float = 0.0
        var postWarmthFilter: Float = 0.0

        for i in 0..<totalSamples {
            let syllableProgress = Float(i) / Float(totalSamples)

            // A. Natural pitch micro-inflection across the syllable
            let microPitchGlide = 1.0 + (sin(syllableProgress * .pi) * 0.015) - (syllableProgress * 0.025)
            let currentPitch = basePitch * microPitchGlide

            // B. Calculate Envelope (Swell up, hold, let go)
            let env: Float
            if i < attackSamples {
                let progress = Float(i) / Float(attackSamples)
                env = sin(progress * .pi * 0.5)
            } else if i < attackSamples + sustainSamples {
                env = 1.0
            } else {
                let releaseIndex = i - (attackSamples + sustainSamples)
                let progress = Float(releaseIndex) / Float(releaseSamples)
                env = cos(progress * .pi * 0.5)
            }

            // C. Glottal Pulse Generator with Jitter & Shimmer
            if samplesUntilNextPeriod <= 0 {
                // Period jitter
                let jitterAmount = Float.random(in: -1.0...1.0) * profile.jitter
                jitterOffset = currentPitch * jitterAmount
                // Amplitude shimmer (pulse-to-pulse energy variation)
                pulseShimmer = 1.0 + Float.random(in: -0.04...0.04)

                let periodInSeconds = 1.0 / max(40.0, (currentPitch + jitterOffset))
                samplesUntilNextPeriod = max(2, Int(Double(periodInSeconds) * sampleRate))
            }
            samplesUntilNextPeriod -= 1

            // Rosenberg polynomial smooth glottal flow wave
            let t = phase
            var rawGlottal: Float = 0.0
            let tp: Float = 0.55 // Glottis opening phase
            let tn: Float = 0.75 // Glottis closing phase

            if t < tp {
                let normalizedT = t / tp
                rawGlottal = (3.0 * normalizedT * normalizedT) - (2.0 * normalizedT * normalizedT * normalizedT)
            } else if t < tn {
                let normalizedClosing = (t - tp) / (tn - tp)
                rawGlottal = 1.0 - (normalizedClosing * normalizedClosing)
            } else {
                rawGlottal = 0.0
            }

            // Advance phase
            let phaseStep = (currentPitch + jitterOffset) / Float(sampleRate)
            phase += phaseStep
            if phase >= 1.0 {
                phase -= 1.0
            }

            // D. Spectral Tilt Filter (Rolls off harsh digital buzz into a warm glottal hum)
            glottalTiltFilter = (0.78 * glottalTiltFilter) + (0.22 * rawGlottal * pulseShimmer)
            let voicedSource = glottalTiltFilter

            // E. Soft Filtered Pink Noise (Aspiration breath)
            let rawWhite = Float.random(in: -1.0...1.0)
            breathLowPassFilter = (0.80 * breathLowPassFilter) + (0.20 * rawWhite)
            let breathAspiration = breathLowPassFilter * profile.breathiness

            // Combined vocal tract excitation
            let excitation = (voicedSource * (1.0 - profile.breathiness * 0.4)) + (breathAspiration * 0.5)

            // F. Formant Resonance Filtering
            let y1 = filter1.process(excitation) * gains.g1
            let y2 = filter2.process(excitation) * gains.g2
            let y3 = filter3.process(excitation) * gains.g3

            let filteredVocal = (y1 + y2 + y3)

            // G. Vocal Warmth Low-Pass (Simulates acoustic absorption of throat & lips ~4.8 kHz)
            postWarmthFilter = (0.35 * postWarmthFilter) + (0.65 * filteredVocal)

            // H. Final sample with envelope and master amplitude
            let sample = postWarmthFilter * env * amplitude * 1.3
            channelData[i] = max(-1.0, min(1.0, sample))
        }

        return buffer
    }
}

// MARK: - Resonant Bandpass Filter (2nd-Order Biquad)
private struct ResonantFilter {
    private var b0: Float = 0
    private var b1: Float = 0
    private var b2: Float = 0
    private var a1: Float = 0
    private var a2: Float = 0

    private var x1: Float = 0
    private var x2: Float = 0
    private var y1: Float = 0
    private var y2: Float = 0

    init(centerFreq: Float, bandwidth: Float, sampleRate: Float) {
        update(centerFreq: centerFreq, bandwidth: bandwidth, sampleRate: sampleRate)
    }

    mutating func update(centerFreq: Float, bandwidth: Float, sampleRate: Float) {
        let f0 = max(20.0, min(sampleRate * 0.45, centerFreq))
        let bw = max(25.0, min(f0 * 1.5, bandwidth))
        let omega = 2.0 * Float.pi * f0 / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let q = max(0.7, f0 / bw)
        let alpha = sinOmega / (2.0 * q)

        // 2-pole resonant bandpass with normalized 0 dB peak
        let a0 = 1.0 + alpha
        b0 = alpha / a0
        b1 = 0.0
        b2 = -alpha / a0
        a1 = (-2.0 * cosOmega) / a0
        a2 = (1.0 - alpha) / a0
    }

    mutating func process(_ x: Float) -> Float {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = x
        y2 = y1
        y1 = y
        return y
    }
}
