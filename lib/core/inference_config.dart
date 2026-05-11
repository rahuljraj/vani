// lib/core/inference_config.dart

class InferenceConfig {

  // HuggingFace token is optional — the model URL in modelDownloadUrl is public.
  // Pass at build time if you need it: flutter run --dart-define=HF_TOKEN=hf_xxx
  static const String hfToken =
      String.fromEnvironment('HF_TOKEN', defaultValue: '');

  static const bool useTurboQuant = false;

  // ── Updated for Gemma 4 E2B ─────────────────────
  
  // Filename must match the download URL's actual filename
  static const String modelFileName = 'gemma_model.litertlm';

  // SD card path — place the model here to skip download
  static const String activeModelPath = '/sdcard/Download/gemma_model.litertlm';

  // New URL for the Gemma 4 E2B LiteRT-LM version
  static const String modelDownloadUrl = 
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  // Actual file size of gemma-4-E2B-it.litertlm — used as fallback when
  // the HTTP response omits Content-Length so progress % stays sane.
  static const double modelSizeBytes = 2590.0 * 1024 * 1024;

  // ── Performance Settings for Gemma 4 ───────────
  
  static const int maxContextTokens = 2048;

  static const int kvCacheSizeMb = 512; // Increased for the larger model

  static const int    maxNewTokens = 400;
  static const double temperature  = 0.7;
  static const int    topK         = 40;

  static const int responseTimeoutSeconds = 30;
}