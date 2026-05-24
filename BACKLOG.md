
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
