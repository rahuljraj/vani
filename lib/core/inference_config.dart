// lib/core/inference_config.dart

class InferenceConfig {

  // HuggingFace token is optional — the model URL in modelDownloadUrl is public.
  // Pass at build time if you need it: flutter run --dart-define=HF_TOKEN=hf_xxx
  static const String hfToken =
      String.fromEnvironment('HF_TOKEN', defaultValue: '');

  static const bool useTurboQuant = false;

  // ── Active model: Gemma 3 1B (litertlm, ~557 MB) ─

  // Filename must match the download URL's actual filename
  static const String modelFileName = 'gemma_model.task';

  // SD card path — place the model here to skip download
  static const String activeModelPath = '/sdcard/Download/gemma_model.task';

  // Gemma 3 1B LiteRT-LM build (multi-prefill, q4, ekv2048)
  static const String modelDownloadUrl =
    'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task';

  static const double modelSizeBytes = 557 * 1024 * 1024;

  // ── Performance Settings for Gemma 3 1B ────────

  static const int maxContextTokens = 2048;

  static const int kvCacheSizeMb = 256;

  static const int    maxNewTokens = 200;
  static const double temperature  = 0.7;
  static const int    topK         = 40;

  static const int responseTimeoutSeconds = 30;
}