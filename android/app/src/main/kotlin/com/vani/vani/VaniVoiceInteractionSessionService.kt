package com.vani.vani

import android.os.Bundle
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService

class VaniVoiceInteractionSessionService : VoiceInteractionSessionService() {

    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        android.util.Log.i("VANI_ASSIST", "onNewSession")
        return VaniVoiceInteractionSession(this)
    }
}