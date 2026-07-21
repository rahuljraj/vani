package com.vani.vani

import android.speech.RecognitionService

/// Stub. The voice-interaction XML config REQUIRES a recognitionService
/// pointing at a component in this package, but VANI does its own STT in
/// the Dart layer. This exists to satisfy the platform requirement and
/// deliberately does nothing.
class VaniRecognitionService : RecognitionService() {
    override fun onStartListening(intent: android.content.Intent?, listener: Callback?) {}
    override fun onCancel(listener: Callback?) {}
    override fun onStopListening(listener: Callback?) {}
}