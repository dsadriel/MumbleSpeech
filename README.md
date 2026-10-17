# MumbleSpeech

A lightweight, pure Swift procedural dialogue voice synthesis engine ("Mumble Speech") designed for games and interactive apps.

Based on acoustic speech research and procedural formant synthesis:
- **Zero Audio Assets Required**: Synthesizes speech phonemes procedurally via source-filter formant DSP in real time.
- **Fast & Zero-Allocation**: Pre-renders small vowel banks (~50 KB) per character so active gameplay at 60/120 FPS incurs zero audio allocations.
- **Natural Acoustics**: Rosenberg smooth glottal flow model, glottal spectral tilt, aspiration breath, shimmer, and micro-pitch inflection.
- **Syllable-Based Pacing**: Detects vowel groups so speech cadence drops from robotic 30 beeps/sec to a natural chatty pace of ~10 vowel bursts/sec.
- **Punctuation Prosody**: Natural phrase declination drift, resets at commas, rising inflection on `?`, shouting on `ALL CAPS` and `!`, and volume fade on `...`.
- **Game-Ready Viseme Events**: Exposes callbacks and async streams for character portraits, mouth animation, and camera/screen shake tags.
- **Generic Effect System**: Register audio files (.mp3, .wav), PCM buffers, or custom game closures (camera shake, haptics, UI animations) triggered directly from inline dialogue tags like `{meow}` or `{witch_laugh}`.

---

## Installation (Swift Package Manager)

Add `MumbleSpeech` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/MumbleSpeech.git", from: "1.0.0")
]
```

Or in Xcode: **File** > **Add Package Dependencies...** and point to the `MumbleSpeech` package folder or Git repository.

---

## Quick Start Guide

### 1. Register Global Effects (Audio Files, Buffers, or Actions)
Register your app-wide or game-wide effects once at application startup. Any NPC or speaker instance automatically inherits these effects:

```swift
import MumbleSpeech

// A. Register an audio file (.mp3, .wav, .caf, .aif) bundled in your app:
if let meowURL = Bundle.main.url(forResource: "cat_meow", withExtension: "mp3") {
    MumbleSpeaker.registerEffect(named: "meow", url: meowURL)
}

if let laughURL = Bundle.main.url(forResource: "witch_laugh", withExtension: "mp3") {
    MumbleSpeaker.registerEffect(named: "witch_laugh", url: laughURL)
}

// B. Register a game action (camera shake, screen flash, haptics, particle burst):
MumbleSpeaker.registerEffect(named: "shake") {
    CameraRig.current.shake(intensity: 0.8)
}

// C. Or configure default voice and effects together centrally:
MumbleSpeaker.configure(
    profile: .bright,
    typingSpeedMultiplier: 1.0,
    effects: [
        "chime": .file(chimeURL),
        "flash": .action { ScreenFlash.trigger() }
    ]
)
```

---

### 2. Speaking with Characters & NPCs

Create dedicated `MumbleSpeaker` instances for your NPCs. Each NPC has its own voice profile and automatically inherits all global effects:

```swift
// Create an NPC speaker instance
let witch = MumbleSpeaker(profile: .witch)

// Optionally override or add NPC-specific local effects:
let pirate = MumbleSpeaker(
    profile: .pirate,
    effects: [
        "aye": .action { playPirateLaugh() }
    ]
)
```

---

### 3. Playing Dialogue with Inline Tags

Embed `{effect_name}` anywhere in the dialogue text. The engine will seamlessly trigger the audio or action at the exact moment that word/tag is reached during the typewriter sequence, without rendering the `{...}` tag in the user's visible text:

```swift
// Listen for typewriter updates and mouth animation (visemes)
witch.onEvent = { event in
    switch event {
    case .character(let char, let currentText):
        dialogueLabel.text = currentText

    case .vowel(let vowel, let openness, let pitch):
        // Animate 2D/3D mouth
        characterAvatar.setMouthOpenness(openness)

    case .tag(let tag):
        // You can also inspect raw inline tags if needed
        print("Encountered dialogue tag: {\(tag)}")

    case .completed(let fullText):
        continueButton.isHidden = false

    case .interrupted:
        break
    }
}

// Speak asynchronously:
Task {
    // Plays witch voice, triggers witch_laugh.mp3, and resumes witch speech!
    await witch.speak("Hehehe! {witch_laugh} You dare enter my forest? Begone!")
}

// Instant skip (e.g. on player click / spacebar):
witch.skip()
```

---

## Voice Presets

`VoiceProfile` provides ready-to-use acoustic voice presets:
- `VoiceProfile.bright`: High, clear resonant tone (225 Hz, vocal tract scale 1.25).
- `VoiceProfile.deep`: Low, authoritative tone (92 Hz, extended vocal tract scale 0.88).
- `VoiceProfile.youth`: Energetic high-pitched voice (320 Hz, compact tract scale 1.48).
- `VoiceProfile.tremor`: Unsteady voice with gentle ~2 Hz tremor vibrato (125 Hz).
- `VoiceProfile.raspy`: Husky, breathy lower tone with narrow cavity (110 Hz).
- `VoiceProfile.sharp`: Sharp tone with fast 3.5 Hz vibrato (260 Hz).

*(Convenience aliases like `.guardProfile`, `.youngWoman`, `.child`, `.elder`, `.pirate`, and `.witch` are also preserved for drop-in compatibility).*

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

---

## Inspiration & Acknowledgements

This project was inspired by the excellent video:
- 📺 **[How Procedural Mumble Speech Works in Games (Mythfall Devlog)](https://www.youtube.com/watch?v=NaW0d7Tghw0)**

Special thanks to the video for demonstrating the practical implementation of formant synthesis, vocal tract resonance scaling, vowel clustering, and prosody declination in games.

## Supported Platforms
- macOS 13+
- iOS 16+
- tvOS 16+
- visionOS 1+

No external dependencies. Built strictly on Swift standard library and `AVFoundation`.
