// lib/core/inference_config.dart

import 'secrets.dart';

class InferenceConfig {

  static String get hfToken => Secrets.hfToken;

  static const bool useTurboQuant = false;

  // ── Updated for Gemma 4 E2B ─────────────────────
  
  // Filename must match the download URL's actual filename
  static const String modelFileName = 'gemma_model.task.litertlm';

  // SD card path — place the model here to skip download
  static const String activeModelPath = '/sdcard/Download/gemma_model.task.litertlm';

  // New URL for the Gemma 4 E2B LiteRT-LM version
  static const String modelDownloadUrl = 
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  // Correct size for your 2.40 GB file
  static const double modelSizeBytes = 2.4 * 1024 * 1024 * 1024; 

  // ── Performance Settings for Gemma 4 ───────────
  
  // Gemma 4 supports up to 128k, but 8k is a safe, fast starting point for Vani
  static const int maxContextTokens = 8192; 

  static const int kvCacheSizeMb = 512; // Increased for the larger model

  static const int    maxNewTokens = 400;
  static const double temperature  = 0.7;
  static const int    topK         = 40;

  static const int responseTimeoutSeconds = 60; // GPU cold-start can take 30-50s on first query
}