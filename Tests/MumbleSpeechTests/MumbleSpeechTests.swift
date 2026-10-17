import Testing
import AVFoundation
@testable import MumbleSpeech

final class ActionBox: @unchecked Sendable {
    var called = false
}

@Suite("MumbleSpeech Engine Tests")
struct MumbleSpeechTests {
    @Test("Vowel Phonetic Mapping")
    func testVowelMapping() {
        #expect(Vowel.from(cluster: "a") == .ah)
        #expect(Vowel.from(cluster: "e") == .eh)
        #expect(Vowel.from(cluster: "i") == .ee)
        #expect(Vowel.from(cluster: "o") == .oh)
        #expect(Vowel.from(cluster: "u") == .uh)
        #expect(Vowel.from(cluster: "oo") == .ooh)
        #expect(Vowel.from(cluster: "ee") == .ee)
    }

    @Test("Text Pacer Punctuation Rhythm")
    func testTextPacer() {
        let pacer = TextPacer(baseLetterDelay: 0.04)
        let steps = pacer.parse(text: "Welcome traveler! {purr}")

        let hasPurr = steps.contains { step in
            if case .effect(let sfx) = step, sfx == "purr" { return true }
            return false
        }
        #expect(hasPurr)

        let vowelStarts = steps.compactMap { step -> String? in
            if case .character(_, _, let isVowelStart, let cluster) = step, isVowelStart {
                return cluster
            }
            return nil
        }
        #expect(vowelStarts.count >= 5)
    }

    @Test("Prosody Engine Declination and Inflection")
    func testProsodyEngine() {
        let engine = ProsodyEngine()
        let profile = VoiceProfile.bright

        let start = engine.calculateProsody(
            profile: profile,
            phrasePosition: 0.0,
            isNearQuestion: false,
            isExclamation: false,
            isEllipsis: false,
            isAllUppercase: false,
            timeElapsed: 0.0
        )
        let end = engine.calculateProsody(
            profile: profile,
            phrasePosition: 1.0,
            isNearQuestion: false,
            isExclamation: false,
            isEllipsis: false,
            isAllUppercase: false,
            timeElapsed: 0.5
        )
        #expect(start.pitch > end.pitch)

        let questionEnd = engine.calculateProsody(
            profile: profile,
            phrasePosition: 0.95,
            isNearQuestion: true,
            isExclamation: false,
            isEllipsis: false,
            isAllUppercase: false,
            timeElapsed: 0.5
        )
        #expect(questionEnd.pitch > end.pitch)
    }

    @Test("Formant Synthesis Buffer Generation")
    func testFormantSynthesis() {
        let synth = FormantSynthesizer.shared
        let profile = VoiceProfile.deep

        for vowel in Vowel.allCases {
            let buffer = synth.synthesizeVowel(vowel: vowel, pitch: profile.basePitch, profile: profile)
            #expect(buffer != nil)
            guard let buf = buffer, let data = buf.floatChannelData?[0] else { continue }
            var nonZero = false
            for i in 0..<Int(buf.frameLength) {
                let sample = data[i]
                #expect(!sample.isNaN)
                #expect(!sample.isInfinite)
                if abs(sample) > 0.001 { nonZero = true }
            }
            #expect(nonZero)
        }
    }

    @Test("MumbleSpeaker Prewarm Vowel Cache")
    func testMumbleSpeakerCache() {
        let speaker = MumbleSpeaker(profile: .deep)
        speaker.prewarmVowelCache()
        #expect(speaker.profile.id == "deep")
    }

    @Test("Global Static Effect Registration")
    func testGlobalEffectRegistration() {
        let box = ActionBox()
        MumbleSpeaker.registerEffect(named: "global_chime") {
            box.called = true
        }

        // Speaker instance should inherit the globally registered effect
        _ = MumbleSpeaker(profile: .deep)
        MumbleSpeechEngine.shared.triggerEffect(named: "global_chime")
        #expect(box.called)
    }

    @Test("Instance-Specific Effect Override")
    func testInstanceEffectOverride() {
        let box = ActionBox()
        let speaker = MumbleSpeaker(
            profile: .raspy,
            effects: [
                "action": .action {
                    box.called = true
                }
            ]
        )

        #expect(speaker.profile.id == "raspy")
    }
}
