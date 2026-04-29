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
  InferenceChat? _chat;
  
  bool _isReady = false;
  bool _isLoading = false;

  bool get isReady => _isReady;
  bool get isLoading => _isLoading;

  static const String _systemPrompt = '''
You are VANI, an Android Voice AI. 
Reply ONLY with a valid JSON object. No conversational text before or after the JSON.

JSON SCHEMA:
{
  "intent": "navigate|order_food|search_product|read_messages|send_message|find_nearby|play_media|chat",
  "app": "google_maps|blinkit|swiggy|zomato|whatsapp|youtube|amazon|none",
  "parameters": {
    "destination": "string",
    "item": "string",
    "quantity": "string",
    "contact": "string",
    "message": "string",
    "query": "string",
    "place_type": "string"
  },
  "speak": "Hindi/Hinglish response, max 10 words",
  "action": "action_code"
}

RULES:
1. "intent": Must match schema. Default to "chat".
2. "app": Must match schema. Default to "none".
3. "parameters": Fill relevant fields only. Empty string for others.
4. "speak": Use natural Hinglish (e.g., "Blinkit pe milk mangao").
5. "action": Internal code (e.g., "maps_navigate", "whatsapp_send", "none").
6. Output MUST start with { and end with }. No markdown blocks.

EXAMPLES:
User: "Airport jaana hai"
{"intent":"navigate","app":"google_maps","parameters":{"destination":"airport"},"speak":"Airport ka rasta dikha raha hoon","action":"maps_navigate"}

User: "Blinkit pe 2kg sugar"
{"intent":"order_food","app":"blinkit","parameters":{"item":"sugar","quantity":"2kg"},"speak":"Blinkit pe sugar add kar raha hoon","action":"blinkit_search"}
''';

  static const String _sdCardModelPath =
      '/sdcard/Download/gemma_model.task';

  Future<File> _modelFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/${InferenceConfig.modelFileName}');
  }

  Future<File?> _availableModelFile() async {
    final sdCard = File(_sdCardModelPath);
    if (sdCard.existsSync() && sdCard.lengthSync() > 1024 * 1024) {
      _log.i('Model on SD card: ${sdCard.lengthSync() ~/ (1024 * 1024)} MB');
      return sdCard;
    }
    final docsFile = await _modelFile();
    if (docsFile.existsSync() && docsFile.lengthSync() > 1024 * 1024) {
      _log.i('Model in docs: ${docsFile.path}');
      return docsFile;
    }
    _log.w('No model file found');
    return null;
  }

  Future<bool> isModelDownloaded() async {
    final file = await _availableModelFile();
    return file != null;
  }

  Future<bool> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    try {
      final file = await _modelFile();
      if (file.existsSync()) await file.delete();

      _log.i('Downloading from HuggingFace...');

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse(InferenceConfig.modelDownloadUrl),
      );
      request.followRedirects = true;
      request.maxRedirects = 10;
      
      if (InferenceConfig.hfToken.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${InferenceConfig.hfToken}',
        );
      }
      request.headers.set(HttpHeaders.userAgentHeader, 'VANI/1.0');
      
      final response = await request.close();

      if (response.statusCode != 200) {
        _log.e('HTTP ${response.statusCode}');
        client.close();
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

      _log.i('Downloaded ${downloaded ~/ (1024 * 1024)} MB');
      return true;
    } catch (e) {
      _log.e('Download failed: $e');
      return false;
    }
  }

  // ── Initialize — CORRECT flutter_gemma 0.5.x API ──
  Future<bool> initialize({
    void Function(double)? onProgress,
  }) async {
    if (_isReady) return true;
    if (_isLoading) return false;

    _isLoading = true;
    _log.i('Initializing Gemma...');

    try {
      final file = await _availableModelFile();
      if (file == null) {
        _log.e('No model file found');
        _isLoading = false;
        return false;
      }

      _log.i('Setting model path: ${file.path}');
      // Explicitly await the installation process
      final installer = FlutterGemma.installModel(modelType: ModelType.gemmaIt)
          .fromFile(file.path);
      await installer.install();

      _log.i('Creating model...');
      final activeModel = await FlutterGemma.getActiveModel(
        maxTokens: InferenceConfig.maxContextTokens,
      );

      if (activeModel == null) {
        _log.e('Failed to get active model: getActiveModel returned null');
        _isLoading = false;
        return false;
      }

      _log.i('Creating chat...');
      final activeChat = await activeModel.createChat(
        temperature: InferenceConfig.temperature,
        randomSeed: 42,
        topK: InferenceConfig.topK,
      );

      _model = activeModel;
      _chat = activeChat;
      _isReady = true;
      _isLoading = false;
      _log.i('✅ Gemma ready!');
      return true;

    } catch (e, stack) {
      _log.e('Init failed: $e');
      _log.e('Stack: $stack');
      _isLoading = false;
      _isReady = false;
      return false;
    }
  }

  // ── Process Voice Text → Intent ────────────────
  Future<VaniIntent> process(String userText) async {
    if (userText.trim().isEmpty) return VaniIntent.error();

    final fast = FastIntentEngine.tryMatch(userText);
    if (fast != null) {
      _log.d('Fast match: ${fast.actionCode}');
      return fast;
    }

    final chat = _chat;
    if (!_isReady || chat == null) {
      _log.w('Model not ready');
      return VaniIntent(
        type: IntentType.chat,
        app: AppTarget.none,
        parameters: {},
        speakText: 'AI load ho rahi hai. Thodi der mein dobara bolein.',
        actionCode: 'none',
      );
    }

    try {
      _log.d('Gemma: $userText');

      final prompt = '$_systemPrompt\n\nUser: $userText\nAssistant:';

      await chat.addQueryChunk(
        Message.text(text: prompt, isUser: true),
      );

      final response = await chat.generateChatResponse();
      _log.d('Response: $response');

      String text = '';
      if (response is TextResponse) {
        text = response.token;
      }

      return VaniIntent.fromRaw(text);

    } catch (e, stack) {
      _log.e('Processing error: $e\n$stack');
      return VaniIntent.error();
    }
  }

  Stream<String> streamResponse(String userText) async* {
    final chat = _chat;
    if (!_isReady || chat == null) {
      yield 'AI ready nahi hai abhi.';
      return;
    }

    try {
      final prompt = '$_systemPrompt\n\nUser: $userText\nAssistant:';

      await chat.addQueryChunk(
        Message.text(text: prompt, isUser: true),
      );

      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          yield response.token;
        }
      }
    } catch (e, stack) {
      _log.e('Stream error: $e\n$stack');
      yield 'Kuch gadbad hui.';
    }
  }

  Future<void> dispose() async {
    _chat = null;
    try {
      await _model?.close();
    } catch (_) {}
    _model = null;
    _isReady = false;
  }
}