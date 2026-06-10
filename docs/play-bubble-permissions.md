# Play Console justifications — floating bubble permissions

Drafts for the two declarations the bubble feature requires. Submit these
ONLY when the bubble graduates out of Labs; while it ships default-OFF and
unreviewed, expect Play to evaluate the manifest anyway — both permissions
are declared as soon as this branch ships, so have these answers ready.

Status: ⏳ UNVERIFIED — Play approval for this combination is empirical.
Do not treat the bubble as shippable until a review passes (or pre-clear it
via the Play policy support form).

## 1. SYSTEM_ALERT_WINDOW ("Display over other apps")

**Core feature served:** quick-access launcher for a voice assistant.

> VANI is a voice assistant for users who prefer speaking (Hindi/Hinglish)
> over typing and navigating. The overlay permission powers exactly one
> surface: an optional, draggable launcher bubble the user can keep on
> screen so the assistant is one tap away while using other apps —
> comparable to a floating accessibility shortcut.
>
> - The bubble is OFF by default. It is enabled by an explicit in-app
>   toggle, preceded by an in-app explainer, and the user grants the
>   permission on the system settings screen themselves.
> - The overlay draws a single 56dp button. It never draws over other
>   apps' content beyond that button, never captures input outside its
>   own bounds, and never displays ads or third-party content.
> - Tapping it simply foregrounds the VANI app in listening mode.
> - It can be disabled at any time from the in-app toggle or by revoking
>   the permission; the app remains fully functional without it (a Quick
>   Settings tile provides the same shortcut).

## 2. FOREGROUND_SERVICE_SPECIAL_USE

**Subtype declared in manifest property:** user-toggled draggable launcher
bubble for the voice assistant.

> The foreground service exists solely to keep the user's opt-in floating
> launcher bubble attached to the WindowManager while the user is outside
> the app. No other foreground-service type matches a persistent overlay
> launcher (it performs no media, location, data-sync, or microphone work —
> the microphone is used only AFTER the user taps the bubble and the main
> activity opens in the foreground).
>
> - Runs only while the user-controlled toggle is on; stops immediately
>   when toggled off or when the overlay permission is revoked.
> - Shows the mandatory ongoing notification (IMPORTANCE_MIN) with
>   instructions to turn it off.
> - Does not restart on boot; it returns only when the user reopens VANI.

## Reviewer-facing demo script (attach as video when submitting)

1. Fresh install → bubble nowhere visible (default OFF).
2. VANI → Labs → "Floating bubble" → in-app explainer → system grant.
3. Bubble appears; drag it; open another app; tap bubble → VANI opens
   listening.
4. Labs → toggle off → bubble and notification disappear.
