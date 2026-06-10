package com.vani.vani

import android.os.Handler
import android.os.Looper
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import java.io.File

/**
 * "Hey VANI" keyword spotting via Vosk (Labs feature, default OFF).
 *
 * FOREGROUND-ONLY BY DESIGN: the engine runs only while the VANI activity
 * is resumed (Dart stops it on every pause), so it needs NO new permission —
 * RECORD_AUDIO is already granted for STT. Always-on background listening
 * would require FOREGROUND_SERVICE_MICROPHONE + a Play declaration; that is
 * a deliberate open decision, not an oversight (docs/wake-word-eval.md).
 *
 * Engine choice: grammar-constrained Vosk recognizer — it may only ever
 * hear the trigger phrases below or [unk], which keeps CPU low and
 * transcription work minimal. Battery and false-trigger rates are
 * ⏳ UNVERIFIED until measured on device.
 */
class VaniWakeWord(private val onWake: () -> Unit) : RecognitionListener {

    companion object {
        const val MODEL_DIR = "vosk-model-small-en-in-0.4"

        // "vani" may be out-of-vocabulary for the small en-IN model, so
        // spelled near-variants are included. Tune on device against the
        // false-trigger measurement in docs/wake-word-eval.md.
        private val TRIGGER_PHRASES = listOf(
            "hey vani", "hey vaani", "hey vanni", "a vani"
        )

        // Ignore re-triggers inside this window (TTS replies, echoes).
        private const val DEBOUNCE_MS = 3000L
    }

    @Volatile
    var running = false
        private set

    private var model: Model? = null
    private var speechService: SpeechService? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var lastTriggerAt = 0L

    /** @return null on success, or a reason code for Dart to surface. */
    fun start(modelBasePath: String): String? {
        if (running) return null
        val dir = File(modelBasePath, MODEL_DIR)
        if (!dir.exists() || !dir.isDirectory) return "model_missing"
        return try {
            val m = model ?: Model(dir.absolutePath).also { model = it }
            val grammar = (TRIGGER_PHRASES + "[unk]")
                .joinToString("\", \"", "[\"", "\"]")
            val recognizer = Recognizer(m, 16000.0f, grammar)
            val service = SpeechService(recognizer, 16000.0f)
            service.startListening(this)
            speechService = service
            running = true
            null
        } catch (e: UnsatisfiedLinkError) {
            "native_missing: ${e.message}"
        } catch (e: Exception) {
            "init_failed: ${e.message}"
        }
    }

    /** Releases the recognizer AND the microphone (full stop, no pause —
     *  Google STT needs the mic to itself). The loaded model is kept so
     *  restarts after each voice command are cheap. */
    fun stop() {
        try {
            speechService?.stop()
            speechService?.shutdown()
        } catch (_: Exception) {
        }
        speechService = null
        running = false
    }

    private fun maybeTrigger(hypothesis: String?) {
        if (hypothesis == null) return
        val now = System.currentTimeMillis()
        if (now - lastTriggerAt < DEBOUNCE_MS) return
        // Hypotheses are small JSON strings ({"partial": "..."}); a substring
        // check is enough and avoids parsing on every audio frame.
        val heard = hypothesis.lowercase()
        if (TRIGGER_PHRASES.any { heard.contains(it) }) {
            lastTriggerAt = now
            mainHandler.post { onWake() }
        }
    }

    override fun onPartialResult(hypothesis: String?) = maybeTrigger(hypothesis)
    override fun onResult(hypothesis: String?) = maybeTrigger(hypothesis)
    override fun onFinalResult(hypothesis: String?) = maybeTrigger(hypothesis)

    override fun onError(exception: Exception?) {
        // Mic conflict or recognizer failure — release everything; Dart
        // restarts the engine on the next app resume.
        stop()
    }

    override fun onTimeout() {
        // Continuous listening — vosk timeouts are not used here.
    }
}
