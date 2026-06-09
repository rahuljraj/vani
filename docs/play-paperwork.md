# Play Store Paperwork — v1.1 Permission Audit

Audited June 2026 against `android/app/src/main/AndroidManifest.xml`.

## Permission inventory

| Permission | Used by | Play status | Action |
|---|---|---|---|
| `RECORD_AUDIO` | STT mic capture (push-to-talk only) | Standard runtime perm | Keep |
| `INTERNET` | Online STT (en_IN), optional model download | Normal | Keep |
| `VIBRATE` | Haptics | Normal | Keep |
| `READ_CONTACTS` | Spoken name → number for Call/WhatsApp. Resolution is fully on-device; contacts never leave the phone | Runtime perm + data-safety entry | Keep |
| `READ_EXTERNAL_STORAGE` (maxSdk 32) | Legacy model read on Android ≤12 | Normal | Keep |
| `MANAGE_EXTERNAL_STORAGE` | **Only** to read the side-loaded Gemma model from `/sdcard/Download/` and copy it to app-private storage on first launch (`gemma_service.dart`) | ⚠️ **BLOCKER for Play.** All-files access is rejected unless the app is a file manager etc. | **Decision needed before submission** (below) |
| `BIND_ACCESSIBILITY_SERVICE` | `VaniAccessibilityService` — app control by voice | Requires Play declaration form + in-app prominent disclosure | Keep. Disclosure now lives in onboarding step 3 (see below) |
| `QUERY_ALL_PACKAGES` | `InstalledAppsScanner` — "open any installed app by name" is the core feature | Requires Play declaration form | Keep, declare (text below) |
| ~~`FOREGROUND_SERVICE`~~ | Nothing yet | — | **Removed in this audit.** Re-add with the Gemma keep-warm service (Phase 2) |
| ~~`RECEIVE_BOOT_COMPLETED`~~ | Nothing yet | — | **Removed in this audit** |

## MANAGE_EXTERNAL_STORAGE — the one real blocker

Current flow: model is side-loaded to `/sdcard/Download/gemma_model.task`,
app copies it to app-private storage on first launch, inference runs from
the private copy. All-files access is needed only for that first read.

Options for a Play build (decision gated on model-config owner — the model
path config in `inference_config.dart` is deliberate, do not change casually):

1. **In-app download to `getExternalFilesDir()` / `getApplicationDocumentsDirectory()`**
   (app-private, zero permissions). The download path already exists in
   `gemma_service.dart` and already targets the private dir — the sdcard read
   is only a dev-convenience shortcut. For the Play build, dropping the two
   `/sdcard/` probe paths + this permission is sufficient. ~557 MB download
   on first run.
2. **Storage Access Framework picker** ("model file chuniye") — one-time
   `ACTION_OPEN_DOCUMENT`, no permission at all, keeps side-loading possible.
3. Ship with MANAGE_EXTERNAL_STORAGE and argue the exemption — **will be
   rejected**; not a real option.

Recommendation: 1 for the Play track, keep the sdcard shortcut in debug
builds only (flavor- or `kDebugMode`-gated).

## Play Console declaration drafts

**Accessibility declaration:**
> VANI is a voice assistant. The AccessibilityService is used exclusively to
> perform the user's spoken commands — opening apps and activating in-app
> search/navigation on the user's explicit instruction. VANI does not read,
> collect, store, or share screen content. No data from the service leaves
> the device.

**QUERY_ALL_PACKAGES declaration:**
> Core functionality: VANI launches any app installed on the device by voice
> ("X kholo"). Matching a spoken app name to a launchable package requires
> enumerating installed launchable apps. The list is processed on-device only.

**Data safety form (summary):**
- Mic audio: collected, processed ephemerally; speech-to-text uses the
  Android system recognizer (Google, en_IN) — disclose "Audio → shared with
  third party for processing" until offline STT ships.
- Contacts: accessed on-device for name→number resolution; not collected,
  not shared.
- No analytics, no ads, no accounts, no tracking SDKs.

**In-app prominent disclosure:** onboarding step 3 (accessibility) states
purpose + "screen content kabhi store ya share nahi karta" before opening
settings; step 1 disclosed the online-STT exception. Keep these strings in
sync with this document.
