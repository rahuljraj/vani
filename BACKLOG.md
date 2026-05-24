
## End of session — May 19, 2026, 2:35 AM

### Wins tonight
- ? Blinkit opens NATIVELY (com.grofers.customerapp + grofers:// scheme verified via ADB)
- ? Double-fire STT bug fixed
- ? Generic _searchInApp matcher + AppDeepLinks registry shipped
- ? STT normalization expanded (blanket/blink gate/linkin ? blinkit)
- ? Verb variants expanded (dhundho/dhundh/dhoondho all caught)

### Tomorrow morning checklist (before recording demo)
1. flutter run on fresh phone state
2. Test "Blinkit pe atta dhundho" — speak "Blinkit" CLEARLY
3. If still mishearing, try "Grocery khol do" or "Atta order karo"
4. Verify Zomato + Swiggy schemes (ADB tests pending)
5. Record demo with the commands that work

### Still in v0.3 backlog
- IntentDisambiguator: Flipkart ? Amazon bug
- More STT normalization (Spotify variants, Flipkart variants)
- Multi-turn dialogue
- Andrej Wiki SQLite layer

## v0.2.3+ — STT phonetic edge cases (May 23, 11:10 PM)

Discovered after v0.2.2 ships:
- Severe mishears unreachable by Dice (lord?Claude scores 0.15)
- Short queries cause false positives (gp?ChatGPT)  
- Near-identical app names collide (Google Pay?Google Play)

Combined fix in v0.3: min-length guard + best-match-across-stages + Soundex fallback.

## v0.3 architecture priority — IntentDisambiguator over-injects app names

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
2. Remove disambiguator entirely — fuzzy + substring matching now strong enough
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
