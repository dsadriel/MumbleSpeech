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

    /// Vowel burst sound duration in seconds (typically ~0.12s to 0.18s).
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

// MARK: - Character Presets
public extension VoiceProfile {
    /// Deep, authoritative town guard with a long vocal tract and steady pitch.
    static let guardProfile = VoiceProfile(
        id: "guard",
        name: "Captain Thorne",
        roleDescription: "Castle Guard",
        icon: "shield.fill",
        basePitch: 92.0,
        tractLengthScale: 0.88,
        breathiness: 0.06,
        vibratoDepth: 0.005,
        vibratoRate: 1.8,
        jitter: 0.010,
        vowelDuration: 0.105
    )

    /// Young woman (Sister Agnes archetype) with higher pitch and shorter vocal tract.
    static let youngWoman = VoiceProfile(
        id: "sister_agnes",
        name: "Sister Agnes",
        roleDescription: "Temple Priestess",
        icon: "sparkles",
        basePitch: 225.0,
        tractLengthScale: 1.25,
        breathiness: 0.10,
        vibratoDepth: 0.012,
        vibratoRate: 2.2,
        jitter: 0.012,
        vowelDuration: 0.085
    )

    /// Energetic child with very high pitch and an extra-short vocal tract.
    static let child = VoiceProfile(
        id: "child",
        name: "Pip",
        roleDescription: "Village Orphan",
        icon: "figure.walk",
        basePitch: 320.0,
        tractLengthScale: 1.48,
        breathiness: 0.12,
        vibratoDepth: 0.015,
        vibratoRate: 2.5,
        jitter: 0.015,
        vowelDuration: 0.075
    )

    /// Village elder with unsteady, slow vibrato (~2 Hz) and mid-low fundamental pitch.
    static let elder = VoiceProfile(
        id: "elder",
        name: "Elder Raymond",
        roleDescription: "Ancient Scholar",
        icon: "book.fill",
        basePitch: 125.0,
        tractLengthScale: 1.02,
        breathiness: 0.14,
        vibratoDepth: 0.055, // Slow steady wobble as highlighted in devlog
        vibratoRate: 2.0,   // ~2 Hz wobble
        jitter: 0.020,
        vowelDuration: 0.110
    )

    /// Pirate who mutters with mouth almost closed, raspy voice.
    static let pirate = VoiceProfile(
        id: "pirate",
        name: "Barnaby",
        roleDescription: "Scurvy Pirate",
        icon: "anchor.fill",
        basePitch: 110.0,
        tractLengthScale: 0.94,
        breathiness: 0.18,
        vibratoDepth: 0.025,
        vibratoRate: 1.9,
        jitter: 0.025,
        vowelDuration: 0.095
    )

/// Cackling witch with high raspy pitch, fast vibrato, and shorter vocal tract.
    static let witch = VoiceProfile(
        id: "witch",
        name: "Morgana",
        roleDescription: "Forest Witch",
        icon: "flame.fill",
        basePitch: 260.0,
        tractLengthScale: 1.15,
        breathiness: 0.16,
        vibratoDepth: 0.040,
        vibratoRate: 3.5,
        jitter: 0.022,
        vowelDuration: 0.090
    )

    /// Default collection of all built-in characters.
    static let allPresets: [VoiceProfile] = [
        .guardProfile,
        .youngWoman,
        .child,
        .elder,
        .pirate,
        .witch
    ]
}
