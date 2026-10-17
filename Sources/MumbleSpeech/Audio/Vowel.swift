import Foundation

/// The six core phonetic vowels used for formant speech synthesis,
/// based on acoustic speech research (Peterson & Barney / Fant).
public enum Vowel: String, CaseIterable, Identifiable, Sendable {
    case ah   // /ɑ/ as in "father"
    case eh   // /ɛ/ as in "bed"
    case ee   // /i/ as in "see"
    case oh   // /o/ as in "boat"
    case ooh  // /u/ as in "boot"
    case uh   // /ʌ/ as in "cut"

    public var id: String { rawValue }

    /// Standard adult male reference formant frequencies (Hz): (F1, F2, F3)
    public var baseFormants: (f1: Float, f2: Float, f3: Float) {
        switch self {
        case .ah:
            return (730, 1090, 2440)
        case .eh:
            return (530, 1840, 2480)
        case .ee:
            return (270, 2290, 3010)
        case .oh:
            return (500, 700, 2550)
        case .ooh:
            return (300, 870, 2240)
        case .uh:
            return (640, 1190, 2390)
        }
    }

    /// Formant bandwidths (Hz) for Q factor calculation: (B1, B2, B3)
    public var bandwidths: (b1: Float, b2: Float, b3: Float) {
        switch self {
        case .ah:
            return (130, 70, 160)
        case .eh:
            return (110, 90, 150)
        case .ee:
            return (50, 100, 120)
        case .oh:
            return (80, 70, 140)
        case .ooh:
            return (65, 80, 110)
        case .uh:
            return (100, 80, 140)
        }
    }

    /// Formant amplitude gains to balance perceived vowel energy
    public var gains: (g1: Float, g2: Float, g3: Float) {
        switch self {
        case .ah:
            return (1.0, 0.45, 0.25)
        case .eh:
            return (1.0, 0.55, 0.28)
        case .ee:
            return (0.85, 0.70, 0.35)
        case .oh:
            return (1.0, 0.35, 0.20)
        case .ooh:
            return (0.9, 0.30, 0.18)
        case .uh:
            return (1.0, 0.40, 0.22)
        }
    }

    /// Open mouth factor (0.0 = nearly closed, 1.0 = wide open) for mouth animation
    public var mouthOpenness: Float {
        switch self {
        case .ah: return 1.0
        case .eh: return 0.7
        case .ee: return 0.3
        case .oh: return 0.8
        case .ooh: return 0.4
        case .uh: return 0.75
        }
    }

    /// Mouth width factor (narrow/round vs wide smile)
    public var mouthWidth: Float {
        switch self {
        case .ah: return 0.7
        case .eh: return 0.8
        case .ee: return 1.0
        case .oh: return 0.4
        case .ooh: return 0.3
        case .uh: return 0.6
        }
    }

    /// Maps a single character or digraph into the most appropriate vowel sound.
    public static func from(cluster: String) -> Vowel {
        let lower = cluster.lowercased()
        if lower.starts(with: "oo") { return .ooh }
        if lower.starts(with: "ee") || lower.starts(with: "ea") { return .ee }
        if lower.starts(with: "ai") || lower.starts(with: "ay") { return .eh }
        if lower.starts(with: "ou") || lower.starts(with: "ow") { return .oh }

        guard let first = lower.first else { return .ah }
        switch first {
        case "a": return .ah
        case "e": return .eh
        case "i", "y": return .ee
        case "o": return .oh
        case "u": return .uh
        default: return .ah
        }
    }
}
