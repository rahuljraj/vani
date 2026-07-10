// lib/services/tts_service.dart

import 'package:flutter_tts/flutter_tts.dart';
import 'package:logger/logger.dart';

class TtsService {
  static TtsService? _instance;
  static TtsService get instance =>
    _instance ??= TtsService._();
  TtsService._();

  final _tts = FlutterTts();
  final _log = Logger();
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    try {
      // Try Hindi India first
      final hiAvailable = await _tts.isLanguageAvailable('hi-IN');
      if (hiAvailable == true) {
        await _tts.setLanguage('hi-IN');
        _log.i('TTS: Hindi hi-IN active');
      } else {
        // Fall back to Indian English
        await _tts.setLanguage('en-IN');
        _log.i('TTS: English en-IN active');
      }

      await _tts.setSpeechRate(0.85); // Slightly slower, clearer
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.05);      // Slightly warmer tone
      await _tts.awaitSpeakCompletion(true);

      _tts.setStartHandler(()      => _isSpeaking = true);
      _tts.setCompletionHandler(() => _isSpeaking = false);
      _tts.setCancelHandler(()    => _isSpeaking = false);
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _log.e('TTS error: $msg');
      });

    } catch (e) {
      _log.e('TTS init error: $e');
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await stop();
      await _tts.speak(text);
    } catch (e) {
      _log.e('TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      if (_isSpeaking) {
        await _tts.stop();
        _isSpeaking = false;
      }
    } catch (e) {
      _log.e('TTS stop error: $e');
    }
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
