# Future feature set — device & Play verification checklist

Branch: `feat/share-bubble-wakeword`. Built in a cloud session: `flutter
analyze` is CLEAN and the Vosk/JNA Maven artifacts were confirmed to exist,
but **no Android SDK was available there** — Kotlin was parse-checked only,
and nothing below has touched a real phone. All three features ship behind
Labs toggles, default OFF; with the toggles off the app must behave exactly
like main.

## 0. Build gate (do FIRST — validates what the cloud session couldn't)

```powershell
flutter pub get
flutter analyze          # was clean in the cloud session
flutter build apk --debug
```

`build apk` is the real native gate: vosk-android/jna dependency resolution,
VaniBubbleService/VaniWakeWord/MainActivity compilation, manifest merge
(activity-alias, special-use FGS property). If vosk resolution ever fails,
the dep lines are isolated at the bottom of `android/app/build.gradle`.

Then the no-regression smoke: install, leave all Labs toggles OFF, run the
v1.0 five: Blinkit search, Swiggy search, call, WhatsApp draft, navigate +
QS tile instant-listen. Must be indistinguishable from main.

## 1. Share target (lowest risk — verify first)

- [ ] Toggles OFF → VANI absent from every share sheet (Chrome, Photos)
- [ ] Labs → "Share karke bhejo" ON → VANI appears in share sheet
      (alias flip needs no reinstall; launcher icon must NOT duplicate)
- [ ] Chrome → share a URL → VANI → speak "raju ko bhejo" → wa.me DRAFT
      opens in Raju's chat with the link — user taps send
- [ ] Unknown name → honest retry ×3 → typed fallback works
- [ ] Photos → share 1 image → VANI → speak name → WhatsApp opens with the
      image in its picker + TTS says to pick the contact there
      **⏳ THE risky bit: URI re-grant.** If WhatsApp shows a permission
      error/black thumbnail, the fallback plan is copying the stream to a
      VANI FileProvider before forwarding — file an issue, don't hack it
      at 2am.
- [ ] Share 3 images (SEND_MULTIPLE) → same flow
- [ ] Toggle OFF → gone from share sheet again
- [ ] `adb shell pm clear com.vani.vani` → cold start → alias auto-resyncs
      to OFF (open VANI once, then check the share sheet)

Simulate without a second app:

```powershell
adb -s 6d6d9eef shell am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT "https://example.com" -n com.vani.vani/.ShareTargetAlias
```

## 2. Floating bubble

- [ ] Labs ON → in-app explainer shows BEFORE the system overlay screen
- [ ] Grant "Display over other apps" → return → toggle ON → bubble appears
      (`adb shell appops get com.vani.vani SYSTEM_ALERT_WINDOW` → allow)
- [ ] Drag works; position survives stop/start
- [ ] Bubble over another app → tap → VANI opens ALREADY LISTENING
      (reuses the tile's EXTRA_AUTO_LISTEN — same logcat 🎤 flow)
- [ ] Notification present while on (IMPORTANCE_MIN), gone when off
- [ ] Toggle OFF → bubble + notification vanish
- [ ] Reboot → bubble absent (by design) → open VANI → bubble returns
- [ ] **⏳ OxygenOS survival (multi-day):** toggle ON, don't open VANI for
      24–48h of normal use. Does the FGS survive doze/battery management?
      Note kills in logcat (`VaniBubbleService`). If killed: document
      whether "Don't optimize" for VANI fixes it — that's user guidance,
      not code.
- [ ] **⏳ Play review:** approval for SYSTEM_ALERT_WINDOW +
      FOREGROUND_SERVICE_SPECIAL_USE is empirical. Submission drafts +
      reviewer demo script: docs/play-bubble-permissions.md. Do NOT
      graduate the bubble out of Labs before a review passes.

## 3. Wake word ("Hey VANI", in-app)

- [ ] Download + unzip vosk-model-small-en-in-0.4, then:
      `adb push vosk-model-small-en-in-0.4 /data/data/com.vani.vani/files/wake/`
      (path also shown in the Labs dialog; `run-as com.vani.vani` if push
      to /data is blocked — or use the Labs dialog's exact path)
- [ ] Labs ON (mic perm flow if needed) → snack "Hey VANI active"
- [ ] Say "Hey VANI" → mic goes red (same as tapping) → full command works
      ("blinkit pe doodh dhundho")
- [ ] After the command completes → "Hey VANI" works AGAIN (mic handoff
      restarted KWS — the make-or-break integration detail)
- [ ] QS tile launch while wake word on → no mic conflict, STT still works
- [ ] Background the app → KWS stops (no mic indicator); resume → returns
- [ ] **⏳ Accuracy / false triggers / battery:** run the full procedure in
      docs/wake-word-eval.md (20× trigger test, 30-min false-trigger soak,
      batterystats on/off comparison). Tune TRIGGER_PHRASES if "vani" is
      out-of-vocabulary.

## 4. Offline STT (Vosk) — parked, deliberately

Not wired: the vosk_flutter plugin API couldn't be compile-verified (recipe
lives in docs/offline-stt-vosk.md on the v1.1 branch). NOTE THE SYNERGY:
this branch already adds the NATIVE vosk-android dependency for KWS — once
the wake word is verified on device, offline STT should reuse the same
native path (full-vocab model, results over the channel) instead of the
unverified Flutter plugin. That supersedes the v1.1-branch recipe's
dependency choice.

## Merge-order note

This branch is off `main` and does NOT include the v1.1 reliability branch
(`claude/friendly-hypatia-qd9kxp`). Both touch AndroidManifest.xml and
home_screen.dart — merge v1.1 first (it's the release train), then rebase
this branch and re-run section 0. The v1.1 branch also REMOVED the unused
FOREGROUND_SERVICE permission; this branch's bubble needs it back — on
rebase, keep `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE`.

## Open decisions (founder calls, surfaced not guessed)

1. **Porcupine (~$6k/yr):** only if Vosk's measured false-trigger rate is
   unacceptable. Not added.
2. **FOREGROUND_SERVICE_MICROPHONE:** required for true always-on wake word
   (screen off / other apps). New Play-sensitive permission → your call.
3. **Wake model distribution:** bundle 36MB in APK vs first-enable download.
   Current adb-push is dev-only.
4. **Media share fallback:** if URI re-grant fails on device, approve the
   FileProvider copy approach (small native addition).
