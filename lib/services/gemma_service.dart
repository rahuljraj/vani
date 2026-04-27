// lib/services/gemma_service.dart

import 'dart:io';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../core/inference_config.dart';
import '../models/vani_intent.dart';
import 'fast_intent_engine.dart';

class GemmaService {

  static GemmaService? _instance;
  static GemmaService get instance =>
    _instance ??= GemmaService._();
  GemmaService._();

  final _log = Logger();
  InferenceModel? _model;
  bool _isReady   = false;
  bool _isLoading = false;

  bool get isReady   => _isReady;
  bool get isLoading => _isLoading;

  // ── Gemma 3 System Prompt ──────────────────────
  static const String _systemPrompt = '''
You are VANI — Voice AI Native Interface.
You are built for India. You understand Hindi, English, and Hinglish naturally.
You help users control their Android phone apps using voice.

When a user speaks, understand their intent and reply ONLY in this JSON format:

{
  "intent": "navigate|order_food|search_product|read_messages|send_message|set_reminder|find_nearby|play_media|chat",
  "app": "google_maps|blinkit|swiggy|zomato|whatsapp|youtube|amazon|none",
  "parameters": {
    "destination": "",
    "item": "",
    "quantity": "",
    "contact": "",
    "message": "",
    "query": "",
    "place_type": ""
  },
  "speak": "What you say to the user in Hindi/Hinglish (keep it short, 1 sentence)",
  "action": "specific_action_code"
}

EXAMPLES:

User: "Blinkit pe 2kg atta order karo"
{"intent":"order_food","app":"blinkit","parameters":{"item":"atta","quantity":"2kg"},"speak":"Blinkit pe 2kg atta dhundh raha hoon","action":"blinkit_search"}

User: "Phoenix Mall navigate karo"
{"intent":"navigate","app":"google_maps","parameters":{"destination":"Phoenix Mall"},"speak":"Phoenix Mall ka rasta dikha raha hoon","action":"maps_navigate"}

User: "Nearest petrol pump dikhao"
{"intent":"find_nearby","app":"google_maps","parameters":{"place_type":"petrol pump"},"speak":"Paas ka petrol pump dhundh raha hoon","action":"maps_nearby"}

User: "Swiggy pe biryani search karo"
{"intent":"order_food","app":"swiggy","parameters":{"item":"biryani"},"speak":"Swiggy pe biryani dhundh raha hoon","action":"swiggy_search"}

User: "Mom ko WhatsApp karo"
{"intent":"send_message","app":"whatsapp","parameters":{"contact":"Mom"},"speak":"Mom ka WhatsApp khol raha hoon","action":"whatsapp_open"}

User: "YouTube pe Arijit Singh songs chalao"
{"intent":"play_media","app":"youtube","parameters":{"query":"Arijit Singh songs"},"speak":"YouTube pe Arijit Singh songs dhundh raha hoon","action":"youtube_search"}

User: "Aaj kaisa din hai"
{"intent":"chat","app":"none","parameters":{},"speak":"Aaj ka din achha lagta hai! Kuch kaam karein?","action":"none"}

RULES:
- Reply in JSON only, no extra text
- speak must be Hindi/Hinglish, max 10 words
- If unclear, use intent "chat" and ask for clarification
- Never make up app names
- Parameters should only include relevant fields
''';

  // ── SD card path (push via ADB) ────────────────
  static const String _sdCardModelPath =
      '/sdcard/Download/gemma_model.task';

  // ── Local model file path (network download) ───
  Future<File> _modelFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/${InferenceConfig.modelFileName}');
  }

  // ── Find model: sdcard first, then docs dir ────
  Future<File?> _availableModelFile() async {
    final sdCard = File(_sdCardModelPath);
    if (sdCard.existsSync() && sdCard.lengthSync() > 1024 * 1024) {
      _log.i('Model found on SD card: $_sdCardModelPath');
      return sdCard;
    }
    final docsFile = await _modelFile();
    if (docsFile.existsSync() && docsFile.lengthSync() > 1024 * 1024) {
      _log.i('Model found in docs: ${docsFile.path}');
      return docsFile;
    }
    return null;
  }

  // ── Check if model is available ────────────────
  Future<bool> isModelDownloaded() async {
    final file = await _availableModelFile();
    return file != null;
  }

  // ── Download model from HuggingFace ────────────
  // Streams download to app documents dir with progress.
  // Skips if already fully downloaded.
  Future<bool> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    try {
      final file = await _modelFile();

      // Clean up any previous partial download
      if (file.existsSync()) await file.delete();

      _log.i('Downloading Gemma model from HuggingFace...');

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse(InferenceConfig.modelDownloadUrl),
      );
      // Follow HuggingFace → CDN redirects
      request.followRedirects = true;
      request.maxRedirects = 10;
      request.headers.set(HttpHeaders.authorizationHeader,
          'Bearer ${InferenceConfig.hfToken}');
      request.headers.set(HttpHeaders.userAgentHeader, 'DartHttpClient/1.0');
      final response = await request.close();

      if (response.statusCode != 200) {
        _log.e('HTTP ${response.statusCode}');
        return false;
      }

      final totalBytes = response.contentLength > 0
          ? response.contentLength
          : InferenceConfig.modelSizeBytes.toInt();
      var downloaded = 0;

      final sink = file.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress?.call((downloaded / totalBytes).clamp(0.0, 1.0));
      }
      await sink.close();
      client.close();

      _log.i('✅ Model downloaded (${downloaded ~/ (1024 * 1024)} MB)');
      return true;
    } catch (e) {
      _log.e('❌ Download failed: $e');
      return false;
    }
  }

  // ── Initialize Gemma ───────────────────────────
  // Checks /sdcard/Download/gemma_model.task first,
  // then falls back to app documents directory.
  Future<bool> initialize({
    void Function(double)? onProgress,
  }) async {
    if (_isReady)   return true;
    if (_isLoading) return false;

    _isLoading = true;
    _log.i('Initializing Gemma...');

    try {
      final file = await _availableModelFile();

      if (file == null) {
        _log.w('No model file found (sdcard or docs).');
        _isLoading = false;
        return false;
      }

      _log.i('Loading model from: ${file.path}');
      await FlutterGemmaPlugin.instance.modelManager
          .setModelPath(file.path);

      _model = await FlutterGemmaPlugin.instance.init(
        maxTokens:   InferenceConfig.maxContextTokens,
        temperature: InferenceConfig.temperature,
        topK:        InferenceConfig.topK,
        randomSeed:  42,
      );

      _isReady   = true;
      _isLoading = false;
      _log.i('✅ Gemma ready');
      return true;

    } catch (e) {
      _log.e('❌ Gemma init failed: $e');
      _isLoading = false;
      return false;
    }
  }

  // ── Process Voice Text → Intent ────────────────
  Future<VaniIntent> process(String userText) async {
    if (userText.trim().isEmpty) return VaniIntent.error();

    final fast = FastIntentEngine.tryMatch(userText);
    if (fast != null) {
      _log.d('FastIntentEngine matched: ${fast.actionCode}');
      return fast;
    }

    if (!_isReady) {
      _log.w('Model not ready yet');
      return VaniIntent(
        type:       IntentType.chat,
        app:        AppTarget.none,
        parameters: {},
        speakText:  'AI abhi load ho rahi hai. Thodi der mein dobara bolein.',
        actionCode: 'none',
      );
    }

    try {
      _log.d('Gemma processing: $userText');

      final prompt = '$_systemPrompt\n\nUser: $userText\nAssistant:';

      final buffer = StringBuffer();
      await for (final chunk in _model!.getResponseAsync(
        prompt: prompt,
        isChat: false,
      )) {
        buffer.write(chunk);
      }

      final raw    = buffer.toString();
      final intent = VaniIntent.fromRaw(raw);

      _log.d('Intent: $intent');
      return intent;

    } catch (e) {
      _log.e('Processing error: $e');
      return VaniIntent.error();
    }
  }

  // ── Stream response tokens ─────────────────────
  Stream<String> streamResponse(String userText) async* {
    if (!_isReady) {
      yield 'AI ready nahi hai abhi.';
      return;
    }

    try {
      final prompt = '$_systemPrompt\n\nUser: $userText\nAssistant:';
      await for (final chunk in _model!.getResponseAsync(
        prompt: prompt,
        isChat: false,
      )) {
        yield chunk;
      }
    } catch (e) {
      _log.e('Stream error: $e');
      yield 'Kuch gadbad hui.';
    }
  }

  // ── Dispose ────────────────────────────────────
  Future<void> dispose() async {
    await _model?.close();
    _model   = null;
    _isReady = false;
  }
}
