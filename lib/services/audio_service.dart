// lib/services/audio_service.dart

import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

class AudioService {
  static AudioService? _instance;
  static AudioService get instance =>
    _instance ??= AudioService._();
  AudioService._();

  final _recorder = AudioRecorder();
  final _stt      = SpeechToText();
  final _log      = Logger();

  bool   _isRecording = false;
  bool   _sttReady    = false;
  String _lastWords   = '';
  void Function()? _autoStopCallback;

  bool   get isRecording => _isRecording;
  String get lastWords   => _lastWords;
  bool   get isListening => _stt.isListening;

  /// Start live Hindi STT.
  /// [onResult] fires on every partial/final transcript.
  /// [onAutoStop] fires when STT detects end-of-speech (after 2s silence).
  Future<bool> startSttListening({
    required void Function(String text) onResult,
    void Function()? onAutoStop,
  }) async {
    // Always fully cancel any prior session
    if (_stt.isListening) {
      await _stt.cancel();
    }

    // Force re-initialization every time — speech_to_text on OnePlus
    // gets into a stuck state after first session if reused
    _sttReady = await _stt.initialize(
      onError: (error) => _log.e('STT error: ${error.errorMsg} permanent=${error.permanent}'),
      onStatus: (status) {
        _log.d('STT status: $status');
        if ((status == 'done' || status == 'notListening')
            && _autoStopCallback != null) {
          _autoStopCallback?.call();
          _autoStopCallback = null;
        }
      },
    );

    if (!_sttReady) {
      _log.w('Speech recognition not available');
      return false;
    }

    _lastWords = '';
    _autoStopCallback = onAutoStop;

    await _stt.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;
        _log.d('STT partial: "$_lastWords" final=${result.finalResult}');
        onResult(_lastWords);
      },
      localeId: 'en_IN',
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );

    _log.d('STT listening started (en_IN, pauseFor=4s)');
    return true;
  }

  Future<String> stopSttListening() async {
    _autoStopCallback = null;
    if (_stt.isListening) await _stt.stop();
    _log.d('STT stopped. Result: "$_lastWords"');
    return _lastWords;
  }

  // ── Raw recording (kept for future audio→Gemma) ──
  Future<bool> startRecording() async {
    try {
      if (!await _recorder.hasPermission()) return false;
      final dir  = await getTemporaryDirectory();
      final path =
        '${dir.path}/vani_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        RecordConfig(
          encoder:     AudioEncoder.aacLc,
          bitRate:     128000,
          sampleRate:  16000,
          numChannels: 1,
        ),
        path: path,
      );
      _isRecording = true;
      return true;
    } catch (e) {
      _log.e('Start recording error: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;
      final path   = await _recorder.stop();
      _isRecording = false;
      return path;
    } catch (e) {
      _log.e('Stop recording error: $e');
      _isRecording = false;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try { await _recorder.cancel(); _isRecording = false; }
    catch (e) { _log.e('Cancel error: $e'); }
  }

  Future<void> dispose() async {
    if (_stt.isListening) await _stt.cancel();
    await _recorder.dispose();
  }
}
