import Foundation

/// Pacing element emitted sequentially by the typewriter text engine.
public enum DialogueStep: Equatable, Sendable {
    /// A single visible character with its punctuation-calculated delay before the next step.
    case character(Character, delay: TimeInterval, isVowelGroupStart: Bool, vowelCluster: String?)
    /// An inline sound effect cue (e.g. "{purr}") that shouldn't appear in the visible dialogue.
    case soundEffect(String)
}

/// Computes the typewriter pacing and cadence based on punctuation rhythm.
public struct TextPacer: Sendable {
    /// Base typing speed (normal letter delay ~ 1/25th of a second for brisk, responsive dialogue)
    public var baseLetterDelay: TimeInterval = 1.0 / 25.0

    public init(baseLetterDelay: TimeInterval = 1.0 / 25.0) {
        self.baseLetterDelay = baseLetterDelay
    }

    /// Comma delay: ~3x base letter delay
    public var commaDelay: TimeInterval {
        baseLetterDelay * 3.0
    }

    /// Major sentence pause (period, ?, !): ~5x base letter delay
    public var sentenceDelay: TimeInterval {
        baseLetterDelay * 5.0
    }

    /// Colon / semicolon / dash pause: ~2x base letter delay
    public var minorPauseDelay: TimeInterval {
        baseLetterDelay * 2.0
    }

    /// Parses dialogue text into timed steps, identifying vowel group starts and inline tags.
    public func parse(text: String) -> [DialogueStep] {
        var steps: [DialogueStep] = []
        let characters = Array(text)
        var i = 0

        var inVowelGroup = false

        while i < characters.count {
            let char = characters[i]

            // Check for inline sound effect tag: e.g. "{purr}"
            if char == "{" {
                if let closeIndex = characters[i...].firstIndex(of: "}") {
                    let tagChars = characters[(i + 1)..<closeIndex]
                    let tag = String(tagChars).trimmingCharacters(in: .whitespaces)
                    steps.append(.soundEffect(tag))
                    i = closeIndex + 1
                    continue
                }
            }

            // Check vowel status
            let isVowel = isVowelChar(char)
            var isGroupStart = false
            var vowelCluster: String? = nil

            if isVowel {
                if !inVowelGroup {
                    isGroupStart = true
                    inVowelGroup = true
                    // Peek next char to check for digraph (e.g. 'oo', 'ee', 'ea')
                    if i + 1 < characters.count && isVowelChar(characters[i + 1]) {
                        vowelCluster = String([char, characters[i + 1]])
                    } else {
                        vowelCluster = String(char)
                    }
                }
            } else {
                inVowelGroup = false
            }

            // Compute delay based on punctuation
            let delay = delayFor(char: char, nextChar: (i + 1 < characters.count) ? characters[i + 1] : nil)

            steps.append(.character(
                char,
                delay: delay,
                isVowelGroupStart: isGroupStart,
                vowelCluster: vowelCluster
            ))

            i += 1
        }

        return steps
    }

    private func isVowelChar(_ char: Character) -> Bool {
        guard let ascii = char.lowercased().first else { return false }
        return "aeiouy".contains(ascii)
    }

    private func delayFor(char: Character, nextChar: Character?) -> TimeInterval {
        switch char {
        case ",":
            return commaDelay
        case ".", "?", "!":
            // Check for ellipsis: if next char is also a period, don't do full sentence delay on each dot
            if char == "." && nextChar == "." {
                return baseLetterDelay * 2.0
            }
            return sentenceDelay
        case ":", ";", "—", "-":
            return minorPauseDelay
        case " ":
            return baseLetterDelay * 0.8
        default:
            return baseLetterDelay
        }
    }
}
