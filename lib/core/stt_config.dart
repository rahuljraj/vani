// lib/core/stt_config.dart

import 'package:whisper_ggml/whisper_ggml.dart';

/// Local (offline) speech-to-text config — whisper.cpp (GGML) on-device.
///
/// Once the model file is on the device, the entire mic → text pipeline
/// runs locally: works in airplane mode, nothing leaves the phone.
class SttConfig {
  /// Master switch: true = on-device Whisper STT.
  /// The app falls back to the online en_IN recognizer ONLY while the
  /// Whisper model isn't on the device yet (first-launch download window).
 static const bool useLocalWhisper = false;

  /// Multilingual `base` (~148 MB) handles Hinglish well on mid-range
  /// phones (~1-2s decode for a short command in release mode).
  /// `WhisperModel.small` (~488 MB) is more accurate but ~3x slower.
  static const WhisperModel whisperModel = WhisperModel.base;
  static const int modelSizeMb = 148;

  /// Side-load path (same pattern as the Gemma model) — place the file
  /// here to skip the one-time download entirely:
  /// https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
  static const String sdCardModelPath = '/sdcard/Download/ggml-base.bin';

  /// 'en' keeps Hinglish in Latin script — same behavior as the old
  /// online en_IN STT, which is what FastIntentEngine's matchers expect.
  /// 'hi' would output Devanagari and break every matcher.
  static const String language = 'en';

  // ── Recording / VAD (hold-to-talk with silence auto-stop) ──

  /// whisper.cpp's native sample rate — record at exactly this.
  static const int sampleRate = 16000;

  /// How often we sample mic amplitude for the silence detector.
  static const Duration vadInterval = Duration(milliseconds: 200);

  /// dBFS above this counts as speech. Typical phone mics idle around
  /// -45 dBFS and speech peaks above -25 dBFS.
  static const double speechThresholdDb = -33.0;

  /// Auto-stop after this much silence once the user has spoken
  /// (mirrors the old `pauseFor` behavior).
  static const Duration silenceTimeout = Duration(seconds: 2);

  /// User never spoke — give up and return to idle.
  static const Duration noSpeechTimeout = Duration(seconds: 6);

  /// Hard cap on one utterance (mirrors the old `listenFor`).
  static const Duration maxUtterance = Duration(seconds: 15);
}
