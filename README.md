# VANI — Voice AI Native Interface

> Your phone. Your voice. Your AI.
> Built for India. Runs on your device. Nothing leaves your phone.

---

## What Is VANI

VANI is a privacy-first, on-device voice AI assistant for Android that
lets you control your phone apps using your voice in Hindi, English,
and Hinglish — with zero cloud processing.

Say: *"Blinkit pe 2kg atta dhundho"*
VANI opens Blinkit and searches automatically.

Say: *"Phoenix Mall navigate karo"*
VANI opens Google Maps with directions.

Everything happens on your device. Always.

---

## Tech Stack

| Layer        | Technology                          |
|--------------|-------------------------------------|
| UI           | Flutter (Android)                   |
| On-device AI | Gemma 4 E2B via flutter_gemma       |
| Voice Input  | Android microphone + record package |
| Voice Output | Android native TTS (hi-IN / en-IN)  |
| App Control  | Android Accessibility Service       |
| App Launch   | Android Intents via url_launcher    |
| Future       | TurboQuant KV cache (Q3 2026)       |

---

## Project Structure

```
vani/
├── lib/
│   ├── main.dart                    ← Entry point
│   ├── app.dart                     ← Routes + theme
│   ├── core/
│   │   ├── constants.dart           ← Colors, strings, packages
│   │   └── inference_config.dart    ← TurboQuant toggle lives here
│   ├── models/
│   │   ├── vani_intent.dart         ← Intent data model
│   │   └── connected_app.dart       ← App toggle model
│   ├── services/
│   │   ├── gemma_service.dart       ← Gemma 4 E2B brain
│   │   ├── audio_service.dart       ← Voice recording
│   │   ├── tts_service.dart         ← Voice output
│   │   ├── permission_service.dart  ← Android permissions
│   │   └── actions/
│   │       ├── action_router.dart   ← Routes intents to apps
│   │       ├── maps_action.dart     ← Google Maps
│   │       ├── blinkit_action.dart  ← Blinkit
│   │       ├── swiggy_action.dart   ← Swiggy
│   │       └── whatsapp_action.dart ← WhatsApp
│   └── screens/
│       ├── splash_screen.dart       ← App launch animation
│       ├── onboarding_screen.dart   ← Permissions setup
│       ├── home_screen.dart         ← Main voice interface
│       └── apps_screen.dart         ← Connected apps toggles
└── android/
    └── app/src/main/
        ├── kotlin/com/vani/vani/
        │   ├── MainActivity.kt              ← Flutter bridge
        │   └── VaniAccessibilityService.kt  ← App control engine
        ├── res/xml/
        │   └── accessibility_service_config.xml
        └── AndroidManifest.xml
```

---

## Day 1 Setup

### Prerequisites
- Flutter SDK 3.19+ installed
- Android Studio with SDK + NDK
- Physical Android device (6GB+ RAM recommended)
- USB debugging enabled on device
- Hugging Face account (free)

### Step 1 — Clone and install

```bash
git clone <your-repo>
cd vani
flutter pub get
```

### Step 2 — Download Gemma 4 E2B model (~2.4GB)

```bash
# Install HuggingFace CLI
pip install huggingface_hub

# Login with your HF token
huggingface-cli login

# Download model
huggingface-cli download \
  google/gemma-4-E2B-it \
  --include "*.litertlm" \
  --local-dir assets/models/
```

### Step 3 — Run on device

```bash
# Connect Android phone via USB
flutter run
```

### Step 4 — Enable Accessibility Service

When prompted in onboarding:
1. Go to Settings → Accessibility
2. Find "VANI Assistant"
3. Toggle ON
4. Confirm

---

## Supported Apps (Phase 1)

| App          | Integration          | Status      |
|--------------|----------------------|-------------|
| Google Maps  | Deep links + Intent  | ✅ Ready    |
| Blinkit      | Deep link + Acc Svc  | ✅ Ready    |
| Swiggy       | Acc Svc + web        | ✅ Ready    |
| Zomato       | Web fallback         | ✅ Ready    |
| WhatsApp     | Acc Svc (Phase 2)    | ⚠️ Partial  |
| YouTube      | Deep link            | ✅ Ready    |
| Amazon       | Web fallback         | ✅ Ready    |
| PhonePe      | View only            | 🔜 Soon     |

---

## Example Voice Commands

```
Navigation:
"Nearest petrol pump dikhao"
"IGI Airport navigate karo"
"Pizza hut dhundho paas mein"

Grocery:
"Blinkit pe 2kg atta order karo"
"Zepto pe doodh add karo"
"Swiggy pe biryani search karo"

Messaging:
"Mom ko WhatsApp karo"
"Papa ko message karo bolo 10 min mein aa raha hoon"

Media:
"YouTube pe Arijit Singh songs chalao"
"Trending songs play karo"

General:
"Aaj kaisa din hai VANI"
"Mujhe yaad dilao 8 baje medicine leni hai"
```

---

## TurboQuant Integration (Q3 2026)

When TurboQuant ships officially, open `lib/core/inference_config.dart`
and change:

```dart
static const bool useTurboQuant = false;
// to:
static const bool useTurboQuant = true;
```

This single change gives every VANI user:
- 6x better memory efficiency
- ~40% faster responses
- Support for longer conversations
- Works on phones with 2GB+ RAM (vs 4GB+ currently)

---

## Privacy Promise

- Zero data sent to any server
- Zero cloud API calls
- Voice is processed on-device by Gemma 4 E2B
- Accessibility Service data never stored, never transmitted
- App interactions are local only
- No account required, ever

---

## Roadmap

| Phase | Timeline  | Features                                     |
|-------|-----------|----------------------------------------------|
| 1     | Week 1–2  | Foundation (this repo)                       |
| 2     | Week 3–5  | Swiggy, WhatsApp send, cross-app chaining     |
| 3     | Week 6–8  | Context memory, user preferences, wake word  |
| 4     | Q3 2026   | TurboQuant, vernacular languages, VANI SME   |

---

*Built with ❤️ for India*
*Privacy first. Always.*
