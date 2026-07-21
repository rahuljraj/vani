package com.vani.vani

import android.service.voice.VoiceInteractionService

/// Registration point for the system assistant slot. Presence of this
/// service (declared with BIND_VOICE_INTERACTION + the XML config) is what
/// makes VANI selectable as the device's digital assistant. An
/// ACTION_ASSIST intent-filter alone is NOT sufficient — verified on
/// ColorOS, Jul 22 2026.
class VaniVoiceInteractionService : VoiceInteractionService() {

    override fun onReady() {
        super.onReady()
        android.util.Log.i("VANI_ASSIST", "VoiceInteractionService ready")
    }
}