package com.vani.vani

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.service.voice.VoiceInteractionSession

/// Minimal session: VANI has its own UI, so instead of drawing an assistant
/// overlay we hand straight off to MainActivity with the auto-listen flag —
/// the same path the Quick Settings tile uses — then dismiss.
class VaniVoiceInteractionSession(context: Context) :
    VoiceInteractionSession(context) {

    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        android.util.Log.i("VANI_ASSIST", "onShow -> launching MainActivity")
        launchVani()
        hide()
    }

    override fun onHandleAssist(
        data: Bundle?,
        structure: android.app.assist.AssistStructure?,
        content: android.app.assist.AssistContent?
    ) {
        // VANI never reads the assisted app's screen content here.
        // Screen access happens only through the accessibility service,
        // with its own explicit user consent.
    }

    private fun launchVani() {
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(MainActivity.EXTRA_AUTO_LISTEN, true)
        }
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e("VANI_ASSIST", "launch failed: $e")
        }
    }
}