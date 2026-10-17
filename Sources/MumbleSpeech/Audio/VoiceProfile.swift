import Foundation

/// Defines the physiological acoustic parameters of a character's voice.
public struct VoiceProfile: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var roleDescription: String
    public var icon: String

    /// Fundamental glottal frequency F0 in Hertz (e.g. 85 Hz - 350 Hz).
    public var basePitch: Float

    /// Vocal tract length scaling factor.
    /// Modulates all 3 formant frequencies (F1, F2, F3) up or down.
    /// Values > 1.0 = shorter tract (women, children); < 1.0 = longer tract (deep male).
    public var tractLengthScale: Float

    /// Proportion of breathy turbulence (white/pink noise) mixed into the buzz (0.0 to 0.4).
    public var breathiness: Float

    /// Depth of slow pitch modulation/tremor (0.0 = completely steady, 0.08 = unsteady/wobbly).
    public var vibratoDepth: Float

    /// Frequency of pitch vibrato/tremor in Hertz (typically ~2.0 Hz).
    public var vibratoRate: Float

    /// Micro-pitch pulse-to-pulse jitter (imperfection to prevent robotic tone, ~0.005 to 0.02).
    public var jitter: Float

    /// Vowel burst sound duration in seconds (typically ~0.07s to 0.12s).
    public var vowelDuration: Float

    public init(
        id: String,
        name: String,
        roleDescription: String,
        icon: String,
        basePitch: Float,
        tractLengthScale: Float,
        breathiness: Float = 0.08,
        vibratoDepth: Float = 0.0,
        vibratoRate: Float = 2.0,
        jitter: Float = 0.012,
        vowelDuration: Float = 0.09
    ) {
        self.id = id
        self.name = name
        self.roleDescription = roleDescription
        self.icon = icon
        self.basePitch = basePitch
        self.tractLengthScale = tractLengthScale
        self.breathiness = breathiness
        self.vibratoDepth = vibratoDepth
        self.vibratoRate = vibratoRate
        self.jitter = jitter
        self.vowelDuration = vowelDuration
    }
}

// MARK: - Generic Acoustic Voice Presets
public extension VoiceProfile {
    /// Low, authoritative voice with a long vocal tract and steady pitch.
    static let deep = VoiceProfile(
        id: "deep",
        name: "Deep",
        roleDescription: "Authoritative low tone with extended vocal tract",
        icon: "waveform.badge.minus",
        basePitch: 92.0,
        tractLengthScale: 0.88,
        breathiness: 0.06,
        vibratoDepth: 0.005,
        vibratoRate: 1.8,
        jitter: 0.010,
        vowelDuration: 0.105
    )

    /// Higher pitch, clear and lively resonant tone with shorter vocal tract.
    static let bright = VoiceProfile(
        id: "bright",
        name: "Bright",
        roleDescription: "High, clear resonant tone",
        icon: "waveform.badge.plus",
        basePitch: 225.0,
        tractLengthScale: 1.25,
        breathiness: 0.10,
        vibratoDepth: 0.012,
        vibratoRate: 2.2,
        jitter: 0.012,
        vowelDuration: 0.085
    )

    /// Energetic high-pitched voice with an extra-short vocal tract.
    static let youth = VoiceProfile(
        id: "youth",
        name: "Youth",
        roleDescription: "Very high, energetic pitch with compact vocal tract",
        icon: "figure.walk",
        basePitch: 320.0,
        tractLengthScale: 1.48,
        breathiness: 0.12,
        vibratoDepth: 0.015,
        vibratoRate: 2.5,
        jitter: 0.015,
        vowelDuration: 0.075
    )

    /// Unsteady, slow pitch modulation (~2 Hz) with gentle vibrato tremor.
    static let tremor = VoiceProfile(
        id: "tremor",
        name: "Tremor",
        roleDescription: "Aged voice with slow ~2 Hz tremor vibrato",
        icon: "waveform.path",
        basePitch: 125.0,
        tractLengthScale: 1.02,
        breathiness: 0.14,
        vibratoDepth: 0.055,
        vibratoRate: 2.0,
        jitter: 0.020,
        vowelDuration: 0.110
    )

    /// Husky, breathy lower tone with narrow mouth cavity.
    static let raspy = VoiceProfile(
        id: "raspy",
        name: "Raspy",
        roleDescription: "Breathy, husky lower tone",
        icon: "wind",
        basePitch: 110.0,
        tractLengthScale: 0.94,
        breathiness: 0.18,
        vibratoDepth: 0.025,
        vibratoRate: 1.9,
        jitter: 0.025,
        vowelDuration: 0.095
    )

    /// High raspy pitch with fast 3.5 Hz vibrato.
    static let sharp = VoiceProfile(
        id: "sharp",
        name: "Sharp",
        roleDescription: "High raspy tone with fast vibrato",
        icon: "flame.fill",
        basePitch: 260.0,
        tractLengthScale: 1.15,
        breathiness: 0.16,
        vibratoDepth: 0.040,
        vibratoRate: 3.5,
        jitter: 0.022,
        vowelDuration: 0.090
    )

    /// Default collection of all built-in acoustic presets.
    static let allPresets: [VoiceProfile] = [
        .deep,
        .bright,
        .youth,
        .tremor,
        .raspy,
        .sharp
    ]

    // MARK: - Backwards-Compatible Aliases
    static var guardProfile: VoiceProfile { deep }
    static var youngWoman: VoiceProfile { bright }
    static var child: VoiceProfile { youth }
    static var elder: VoiceProfile { tremor }
    static var pirate: VoiceProfile { raspy }
    static var witch: VoiceProfile { sharp }
}
