// lib/core/inference_config.dart
// ─────────────────────────────────────────────────
// Central config for all AI inference settings.
// TurboQuant toggle lives here — flip one bool
// when official release ships Q3 2026 and the
// entire app gets 6x memory efficiency instantly.
// ─────────────────────────────────────────────────

import 'secrets.dart';

class InferenceConfig {

  // ── Auth Token (from gitignored secrets.dart) ──
  // Never hardcode tokens in source — always use Secrets file
  static String get hfToken => Secrets.hfToken;

  // ── TurboQuant Toggle ──────────────────────────
  // FALSE now (not production-ready yet)
  // TRUE  when llama.cpp/LiteRT ships TQ support Q3 2026
  static const bool useTurboQuant = false;

  // ── Active Model ───────────────────────────────
  // MediaPipe Task format (.task) — Gemma 3 1B int4 quantized
  static const String modelFileName =
    'Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task';

  // Path on phone after ADB push or first download
  static const String activeModelPath =
    '/sdcard/Download/gemma_model.task';

  // Download URL (used only if model not already on device)
  static const String modelDownloadUrl =
    'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/'
    'Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task';

  // Approximate size for progress display
  static const double modelSizeBytes = 555.0 * 1024 * 1024;

  // Future model variants
  static const String modelE2B = 'gemma-4-E2B-it';
  static const String modelE4B = 'gemma-4-E4B-it';

  // ── Context Window ─────────────────────────────
  // With TurboQuant: 6x more context for same RAM
  static const int maxContextTokens =
    useTurboQuant ? 8192 : 2048;

  // ── KV Cache ───────────────────────────────────
  static const int kvCacheSizeMb =
    useTurboQuant ? 48 : 256;

  // ── Generation Parameters ──────────────────────
  static const int    maxNewTokens = 400;
  static const double temperature  = 0.7;
  static const int    topK         = 40;

  // ── Response Timeout ───────────────────────────
  static const int responseTimeoutSeconds = 15;

  // ── Device RAM-based Model Selection ───────────
  static String modelForDevice(int availableRamMb) {
    if (useTurboQuant) {
      // TurboQuant: E4B fits where E2B used to
      return availableRamMb >= 3000 ? modelE4B : modelE2B;
    } else {
      // Standard: E4B needs 6GB+
      return availableRamMb >= 6000 ? modelE4B : modelE2B;
    }
  }
}