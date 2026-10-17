# MumbleSpeech

A lightweight, pure Swift procedural dialogue voice synthesis engine ("Mumble Speech") designed for games and interactive apps.

Based on acoustic speech research and procedural formant synthesis:
- **Zero Audio Assets Required**: Synthesizes speech phonemes procedurally via source-filter formant DSP in real time.
- **Fast & Zero-Allocation**: Pre-renders small vowel banks (~50 KB) per character so active gameplay at 60/120 FPS incurs zero audio allocations.
- **Natural Acoustics**: Rosenberg smooth glottal flow model, glottal spectral tilt, aspiration breath, shimmer, and micro-pitch inflection.
- **Syllable-Based Pacing**: Detects vowel groups so speech cadence drops from robotic 30 beeps/sec to a natural chatty pace of ~10 vowel bursts/sec.
- **Punctuation Prosody**: Natural phrase declination drift, resets at commas, rising inflection on `?`, shouting on `ALL CAPS` and `!`, and volume fade on `...`.
- **Game-Ready Viseme Events**: Exposes callbacks and async streams for character portraits, mouth animation, and camera/screen shake tags.

---

## Installation (Swift Package Manager)

Add `MumbleSpeech` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/Voice.git", from: "1.0.0")
]
```

Or in Xcode: **File** > **Add Package Dependencies...** and point to this repository or local folder.

---

## Quick Start in Games

```swift
import MumbleSpeech

// 1. Create a speaker with a character voice profile
let speaker = MumbleSpeaker(profile: .youngWoman)

// 2. Listen to visemes and game event tags for animation
speaker.onEvent = { event in
    switch event {
    case .character(let char, let currentText):
        dialogueLabel.text = currentText

    case .vowel(let vowel, let openness, let pitch):
        // Drive 2D or 3D character mouth shape
        characterMouth.setOpenness(openness)

    case .tag(let tag):
        // Trigger game events directly inside dialogue!
        if tag == "camera_shake" {
            camera.shake(intensity: 0.5)
        } else if tag == "purr" {
            playPetAnimation()
        }

    case .completed(let fullText):
        advancePromptArrow.show()

    case .interrupted:
        break
    }
}

// 3. Speak dialogue asynchronously
Task {
    await speaker.speak("Sister Agnes told me to watch the gates! {camera_shake} Be careful.")
}

// 4. Instant skip (e.g. on player tap or spacebar press)
speaker.skip()
```

---

## Character Voice Presets

`VoiceProfile` provides ready-to-use character archetypes:
- `VoiceProfile.guardProfile`: Deep, steady pitch (92 Hz), long vocal tract ($0.88\times$).
- `VoiceProfile.youngWoman`: High, bright pitch (225 Hz), shorter tract ($1.25\times$).
- `VoiceProfile.child`: Energetic pitch (320 Hz), extra-short vocal tract ($1.48\times$).
- `VoiceProfile.elder`: Ancient voice with a 2 Hz unsteady tremor/vibrato.
- `VoiceProfile.pirate`: Raspy breath, narrow mouth tract, low-mid pitch.

### Custom Voice Creation (1 Line)

```swift
let customVoice = VoiceProfile(
    id: "wizard",
    name: "Archmage",
    roleDescription: "Mystic",
    icon: "sparkles",
    basePitch: 140.0,          // Fundamental frequency F0
    tractLengthScale: 1.10,     // Vocal tract size multiplier
    breathiness: 0.12,         // Soft aspiration air (0.0 to 0.4)
    vibratoDepth: 0.03,        // Tremor / wobble depth (0.0 to 0.08)
    vibratoRate: 3.0           // Tremor frequency in Hz
)
```

---

## Supported Platforms
- macOS 13+
- iOS 16+
- tvOS 16+
- visionOS 1+

No external dependencies. Built strictly on Swift standard library and `AVFoundation`.
