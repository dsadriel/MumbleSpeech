import Foundation

/// Events emitted during procedural dialogue playback for game logic, animation, and visemes.
public enum DialogueEvent: Sendable, Equatable {
    /// A single visible character was emitted to the screen.
    case character(Character, displayedText: String)

    /// A vowel phoneme was sounded, providing viseme geometry for 2D/3D mouth animation.
    case vowel(Vowel, mouthOpenness: Float, pitch: Float)

    /// An inline game cue or sound effect tag was encountered (e.g. "{camera_shake}", "{purr}").
    case tag(String)

    /// The entire dialogue string finished speaking.
    case completed(fullText: String)

    /// Dialogue playback was skipped or stopped prematurely.
    case interrupted
}
