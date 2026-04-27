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

  bool   get isRecording => _isRecording;
  String get lastWords   => _lastWords;

  // ── Speech-to-Text (Hindi) ─────────────────────
  Future<bool> _ensureSttReady() async {
    if (_sttReady) return true;

    _sttReady = await _stt.initialize(
      onError:  (error)  => _log.e('STT error: ${error.errorMsg}'),
      onStatus: (status) => _log.d('STT status: $status'),
    );

    if (!_sttReady) _log.w('Speech recognition not available on this device');
    return _sttReady;
  }

  /// Start live Hindi speech recognition.
  /// [onResult] fires on every partial and final transcript update.
  /// Returns false if speech recognition is not available on this device.
  Future<bool> startSttListening({
    required void Function(String text) onResult,
  }) async {
    if (!await _ensureSttReady()) return false;

    // Stop any in-progress session before starting a new one.
    if (_stt.isListening) await _stt.stop();

    _lastWords = '';

    await _stt.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;
        onResult(_lastWords);
      },
      localeId:     'hi_IN',
      listenOptions: SpeechListenOptions(
        cancelOnError:  true,
        partialResults: true,
      ),
    );

    _log.d('STT listening (hi_IN)');
    return true;
  }

  /// Stop listening and return the final recognised text.
  /// Returns an empty string if recognition was never started or nothing was heard.
  Future<String> stopSttListening() async {
    if (_stt.isListening) await _stt.stop();
    _log.d('STT stopped. Result: "$_lastWords"');
    return _lastWords;
  }

  // ── Raw Audio Recording (kept for future audio passthrough) ────
  Future<bool> startRecording() async {
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        _log.w('No microphone permission');
        return false;
      }

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
      _log.d('Recording started');
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
      _log.d('Recording saved: $path');
      return path;
    } catch (e) {
      _log.e('Stop recording error: $e');
      _isRecording = false;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _recorder.cancel();
      _isRecording = false;
    } catch (e) {
      _log.e('Cancel error: $e');
    }
  }

  Future<void> dispose() async {
    if (_stt.isListening) await _stt.cancel();
    await _recorder.dispose();
  }
}
