
## End of session � May 19, 2026, 2:35 AM

### Wins tonight
- ? Blinkit opens NATIVELY (com.grofers.customerapp + grofers:// scheme verified via ADB)
- ? Double-fire STT bug fixed
- ? Generic _searchInApp matcher + AppDeepLinks registry shipped
- ? STT normalization expanded (blanket/blink gate/linkin ? blinkit)
- ? Verb variants expanded (dhundho/dhundh/dhoondho all caught)

### Tomorrow morning checklist (before recording demo)
1. flutter run on fresh phone state
2. Test "Blinkit pe atta dhundho" � speak "Blinkit" CLEARLY
3. If still mishearing, try "Grocery khol do" or "Atta order karo"
4. Verify Zomato + Swiggy schemes (ADB tests pending)
5. Record demo with the commands that work

### Still in v0.3 backlog
- IntentDisambiguator: Flipkart ? Amazon bug
- More STT normalization (Spotify variants, Flipkart variants)
- Multi-turn dialogue
- Andrej Wiki SQLite layer

## v0.2.3+ � STT phonetic edge cases (May 23, 11:10 PM)

Discovered after v0.2.2 ships:
- Severe mishears unreachable by Dice (lord?Claude scores 0.15)
- Short queries cause false positives (gp?ChatGPT)  
- Near-identical app names collide (Google Pay?Google Play)

Combined fix in v0.3: min-length guard + best-match-across-stages + Soundex fallback.

## v0.3 architecture priority � IntentDisambiguator over-injects app names

**Bug discovered May 24, ~2:30 AM:**
'Chat GPT open karo' (correctly heard by STT) gets re-routed to WhatsApp:

- STT: 'chat gpt open karo' ?
- Normalize: 'chat gpt open karo' ?
- **IntentDisambiguator: rewrites to 'whatsapp chat gpt open karo'** ? bug
- _openApp extracts: 'whatsapp chat gpt'
- Fuzzy ranking: WhatsApp=0.67, ChatGPT=0.60
- Result: opens WhatsApp instead of ChatGPT

**Same class as existing 'Flipkart ? Amazon' bug:**
IntentDisambiguator uses keyword hints ('chat', 'phone', 'shopping') to
inject preferred app names into the query. When user already said the
app name, this REPLACES correct routing with wrong routing.

**Architectural fix options (decide with clear head):**
1. Disambiguator only fires when no installed-app name is mentioned in query
2. Remove disambiguator entirely � fuzzy + substring matching now strong enough
3. Disambiguator returns a HINT parameter, doesn't rewrite query text

Recommend option 1 or 3. Option 2 might lose useful disambiguation for
ambiguous cases like 'kuch order karna hai'.

**Regression test surface:** Run all v0.2 / v0.2.1 / v0.2.2 test cases:
- Claude / cloud / Claude application kholo
- ChatGPT / chatpt / chat gpt
- WhatsApp open karo (legit)
- Blinkit pe atta dhundho
- Swiggy pe pav bhaji dhundho
- LinkedIn open karo

## v0.3 PLAN � Fix IntentDisambiguator (designed May 24, ~3:00 AM, execute tomorrow)

**File:** lib/services/intent_disambiguator.dart (90 lines)
**Bug location:** lines 56-69 (scoring) � disambiguator doesn't know which apps are installed; injects 'whatsapp' for queries containing 'chat' (context word) even when user said 'chat gpt'.

### Fix (8 lines added at start of resolve()):

\\\dart
static String? resolve(String transcript) {
  final t = transcript.toLowerCase();
  final tNormalized = t.replaceAll(RegExp(r'[\s._\-]+'), '');
  
  // NEW: If any installed app's name (or its space-stripped form) appears 
  // in the transcript, skip disambiguation entirely. Let _openApp's exact/
  // fuzzy matching handle it naturally.
  for (final app in AppRegistry.instance.apps) {
    final name = app.displayName.toLowerCase();
    final nameNorm = name.replaceAll(RegExp(r'[\s._\-]+'), '');
    if (name.length >= 4 && 
        (t.contains(name) || tNormalized.contains(nameNorm))) {
      return null;  // _openApp handles it
    }
  }
  
  // ... existing scoring loop unchanged below ...
}
\\\

### Why this works:
- 'chat gpt open karo' ? tNormalized = 'chatgptopenkaro' ? contains 'chatgpt' ? return null ? _openApp finds ChatGPT
- 'flipkart pe phone' ? contains 'flipkart' ? return null ? _openApp finds Flipkart
- 'biryani mangwa do' ? no installed-app name in query ? existing scoring runs ? returns 'swiggy' (correct)
- 'pizza order karo' ? no app name ? existing scoring runs ? returns 'swiggy' or 'zomato' (correct)

### Test cases for tomorrow (regression suite):
**Must work (new behavior):**
1. 'chat gpt open karo' ? ChatGPT (was: WhatsApp)
2. 'chatgpt kholo' ? ChatGPT
3. 'flipkart pe phone dhundho' ? Flipkart (was: Amazon)

**Must continue working (regression):**
4. 'cloud open karo' ? Claude (fuzzy match, no disambiguator involvement)
5. 'linkedin open karo' ? LinkedIn
6. 'blinkit pe atta dhundho' ? Blinkit search
7. 'swiggy pe pav bhaji' ? Swiggy search
8. 'youtube pe hanuman chalisa lagao' ? YouTube search
9. 'biryani mangwa do' ? Swiggy (disambiguator still fires when no app name present)
10. 'pizza order karo' ? Swiggy or Zomato (ambiguity check)

### Estimated time tomorrow: 45-60 minutes
- 5 min: read disambiguator.dart once more
- 15 min: apply 8-line fix, hot reload
- 30 min: voice-test all 10 cases above
- 5 min: commit + push

<<<<<<< HEAD
## Future feature set session — June 10, 2026 (cloud, branch feat/share-bubble-wakeword)

Three Labs features behind flags (ALL default OFF — app identical to main
with toggles off): share-target ("ye raju ko bhejo", disabled activity-alias
→ wa.me drafts, never auto-send), floating bubble (overlay + special-use
FGS, reuses tile's EXTRA_AUTO_LISTEN, Play drafts written), in-app "Hey
VANI" wake word (native Vosk KWS, foreground-only, no new permissions).
flutter analyze CLEAN (real toolchain in cloud). NOT verified: any device
behavior + Kotlin compile (no Android SDK there) — run
docs/future-device-checklist.md section 0 first. Offline STT stays parked;
note: wake word's native vosk-android dep is the better future path for it
than vosk_flutter. Open decisions: Porcupine $, FGS_MICROPHONE for
always-on, model bundling, FileProvider fallback.
=======
## v1.1 implementation session — June 9, 2026 (cloud, no device)

### Shipped on branch claude/friendly-hypatia-qd9kxp
- Reliability pass: ActionRouter top-level guard — every route now ends in
  right action OR spoken graceful fail. Honest corrections when contact/number
  unresolved (Call + WhatsApp). Maps action fully guarded with 3-stage fallback.
- ROOT-CAUSE FIX: `https` was missing from manifest <queries> — canLaunchUrl()
  could silently return false on Android 11+ for wa.me drafts + every web
  fallback. Likely the WhatsApp draft flakiness.
- Grocery-no-app path: dead grofers:// → verified https app-link for Blinkit;
  Zepto + BigBasket https templates added (UNVERIFIED — probe first);
  app_search_deeplink now launches PINNED into the package (launchUrlInPackage)
  and resolves the missing URI in the single-app case (was: opened app plain).
- Explicit-Zomato degraded honestly: "Zomato khol raha hoon — X wahan khud
  dhundhna". Dead zomato:// template removed; web search only when app missing.
- Onboarding: privacy overclaim fixed (STT-online disclosed), accessibility
  prominent disclosure added (Play policy), first-use example commands.
- Play audit: docs/play-paperwork.md — MANAGE_EXTERNAL_STORAGE flagged as the
  one submission blocker (model side-load); unused FOREGROUND_SERVICE +
  RECEIVE_BOOT_COMPLETED removed from manifest; declaration drafts written.
- Release signing scaffolded (key.properties pattern, falls back to debug);
  version bumped to 1.1.0+2. docs/release-signing.md.
- Fixed wrong Blinkit package in VaniPackages (com.blinkit.consumer →
  com.grofers.customerapp) — apps screen installed-check was broken.
- Offline STT (Vosk): full recipe in docs/offline-stt-vosk.md — deliberately
  NOT wired in from a machine that can't compile-check; one device evening.

### Before merge (device session — docs/v1.1-device-checklist.md)
1. flutter pub get && flutter analyze  (cloud session had no Flutter!)
2. ADB-probe Zepto + BigBasket app-links; flip UNVERIFIED comments
3. Zomato dumpsys deep-link hunt (optional — honest copy ships either way)
4. 3x reliability script: Call / WhatsApp draft / Navigate
5. Fresh-install onboarding walkthrough
>>>>>>> main
