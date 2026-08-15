# VANI — Voice AI Native Interface for India

> Your phone, your voice, in your language.
> Hinglish-native. Built for the phones most Indians actually carry.

---

## What is VANI

VANI is a Hinglish-native voice assistant for Android. It holds the system
assistant slot — long-press the power button and VANI opens — and completes
everyday tasks by voice: calls, WhatsApp messages, navigation, launching apps,
in-app search, and the torch.

- *"mummy ji ko phone lagao"* → resolves the contact, places the call
- *"WhatsApp kholo"* → opens the app
- *"Blinkit pe doodh dhundho"* → opens Blinkit and runs the search
- *"Surat railway station navigate karo"* → opens Maps with directions
- *"torch chalu karo"* → turns on the flashlight

Built for mid-range and budget Android phones, not flagships. Around 500
million Indians own a smartphone; only about 50 million transact on food,
grocery and mobility apps. The interface is the barrier, not the appetite —
English-only menus and tap-heavy flows lock out older users, first-time
smartphone owners, and anyone more comfortable speaking than reading.

---

## Status

**v1.1.1-beta** — released and release-signed. In daily use by a small group
of testers. No public distribution yet: Google Play Protect blocks sideloaded
apps requesting sensitive permissions, so distribution moves to a Play Store
closed testing track.

---

## Supported commands

| Command | What it does | Status |
| --- | --- | --- |
| Call contact | Resolves contact by name, places the call | ✅ Working |
| WhatsApp | Resolves contact, opens chat with message pre-drafted | ✅ Working — drafts only, never auto-sends |
| Navigate | Opens Google Maps with directions | ✅ Working |
| Open app | Launches any installed app by name, fuzzy-matched | ✅ Working |
| In-app search | Opens an app and runs a search inside it | ✅ Working |
| Food / grocery | Opens Swiggy or Blinkit and runs a search | ✅ Working — **search only, does not place orders** |
| Torch | Turns the flashlight on and off | ✅ Working |

Every action that reaches another person or spends money passes a spoken
confirmation gate before it runs. The torch is the deliberate exception: it is
instant, reversible, and a confirmation round-trip would defeat the point for
the user it most helps.

---

## How it works — a two-tier intent engine

The core bet: most voice commands are patterns, not reasoning, so they
shouldn't pay the cost of a model.

- **FastIntentEngine** — an on-device rule and pattern matcher resolves roughly
  90% of commands in under 50ms with no model involved and no network call.
- **Cloud conversational layer** — handles the ambiguous remainder. VANI is
  usable without it: if it is unavailable, the fast path still works.

The assistant slot launches in ~670ms on a OnePlus Nord CE 2 Lite, measured on
device.

A category-aware disambiguator handles the tricky cases: in *"doodh order
karo"* the item word *doodh* (milk) outweighs the generic verb *order*, so it
routes to groceries rather than food delivery. Where two contacts match
equally well, VANI asks instead of guessing.

### Hinglish, specifically

Real code-switched speech is the hard part — not Hindi, and not English.
Custom phonetic folding lets a transcript like "Shizuka" reach a contact saved
as "Sizu". An on-device log of unmatched commands feeds rule fixes from actual
usage rather than guesswork; several supported phrasings came directly from it.

---

## Tech stack

| Layer | Technology |
| --- | --- |
| UI | Flutter (Android) |
| Native bridge | Kotlin — VoiceInteractionService, telephony, contacts, CameraManager |
| Fast path | FastIntentEngine (on-device rule matcher) |
| Conversational layer | Cloud LLM API |
| Speech-to-text | Google STT (en-IN) with custom phonetic folding |
| Speech output | Android native TTS (hi-IN / en-IN) |
| App control | Deep links and Android Intents |
| State | Riverpod |
| Local storage | SharedPreferences (on-device only, backup disabled) |

Minimum SDK 26. Targets Android 16 (API 36).

---

## Privacy

VANI is privacy-conscious by architecture, and honest about where the line
sits:

- **Intent understanding and personal data stay on the device.** Contact
  resolution, phonetic matching and command routing are all local.
- **Speech-to-text goes to Google (en-IN).** This is disclosed during
  onboarding. It is the one part of the pipeline that leaves the phone.
- **The conversational layer is a cloud API call**, used only for commands the
  on-device engine cannot route.
- **Android Auto Backup is disabled**, so local app data is never synced to
  Google Drive.
- **App actions are local** — deep links and intents act on apps you are
  already signed into.
- No account required. No analytics, no tracking servers.

We do not claim VANI is fully offline, and never will while STT and the
conversational layer are network calls.

---

## Example commands

```
"WhatsApp kholo"
"mummy ji ko phone lagao"
"raju bhai sa ko whatsapp karo, late ho jaunga"
"Surat railway station navigate karo"
"Blinkit pe doodh dhundho"
"camera chalu karo"
"torch band karo"
```

---

## Roadmap

- Play Store closed testing track — the current distribution blocker
- Voice-completed ordering through partners' official APIs
- More Indian languages beyond Hinglish
- On-device wake word

### Deliberately not pursued

- **Offline STT.** Vosk and Whisper-class models were tested and failed on
  code-switched Hinglish: English brand names inside Hindi sentences come back
  mangled ("WhatsApp" → "vahaatsaepp"). Revisit when a recogniser handles
  code-switching natively.
- **Accessibility-driven UI tapping** for ordering. Brittle against app
  layout changes; official partner APIs are the right path.

---

## Building

```bash
flutter pub get
flutter build apk --release
```

Release builds require a keystore configured in `android/key.properties`
(gitignored).

---

## About

Built by [Rahul Rajpurohit](https://github.com/rahuljraj) — solo, at night,
around running a family retail shop in Surat.

**Trikontech (OPC) Private Limited** · DPIIT recognised (DIPP239528) ·
[trikontech.in](https://trikontech.in)

Built with Claude Code. Every architecture and product decision is mine, and
everything ships only after device verification.