// lib/services/audio_service.dart

import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

import '../core/stt_config.dart';
import 'whisper_stt_service.dart';

class AudioService {
  static AudioService? _instance;
  static AudioService get instance =>
    _instance ??= AudioService._();
  AudioService._();

  final _recorder = AudioRecorder();
  final _stt      = SpeechToText();
  final _log      = Logger();

  bool   _isRecording      = false;
  bool   _sttReady         = false;
  String _lastWords        = '';
  bool   _gotFinalResult   = false;
  void Function()? _autoStopCallback;

  // Local Whisper session state — true while the current mic session is
  // running through the offline pipeline instead of the online recognizer.
  bool _whisperSession = false;
  void Function(String text)? _whisperOnResult;

  bool   get isRecording => _isRecording;
  String get lastWords   => _lastWords;
  bool   get isListening =>
      _whisperSession ? WhisperSttService.instance.isRecording
                      : _stt.isListening;

  /// Start STT. Prefers the fully offline Whisper pipeline (works in
  /// airplane mode); falls back to the online en_IN recognizer only
  /// while the Whisper model isn't on the device yet.
  /// [onResult] fires with the transcript (Whisper: once, on stop).
  /// [onAutoStop] fires when end-of-speech is detected (~2s silence).
  Future<bool> startSttListening({
    required void Function(String text) onResult,
    void Function()? onAutoStop,
  }) async {
    if (SttConfig.useLocalWhisper && WhisperSttService.instance.isReady) {
      _whisperOnResult = onResult;
      final ok = await WhisperSttService.instance
          .startListening(onAutoStop: onAutoStop);
      _whisperSession = ok;
      if (ok) {
        _log.d('STT listening started (local Whisper, offline)');
        return true;
      }
      // Whisper mic failed to start — fall through to the online path
      _whisperOnResult = null;
      _log.w('Whisper start failed — falling back to online STT');
    }

    // ── Legacy online recognizer (fallback only) ──
    // Always fully cancel any prior session
    if (_stt.isListening) {
      await _stt.cancel();
    }

    // Clear callback BEFORE init — prevents stale callback firing
    // during init's own 'done' status events from prior session
    _autoStopCallback = null;
    _lastWords = '';
    _gotFinalResult = false;

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

    // NOW set the callback — after init is complete, so stray status
    // events during init don't trigger the new callback
    _autoStopCallback = onAutoStop;

    await _stt.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;
        _log.d('STT partial: "$_lastWords" final=${result.finalResult}');
        if (result.finalResult) {
          _gotFinalResult = true;
          onResult(_lastWords);
        }
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

  /// Stop STT and return the final transcript.
  /// Whisper path: stops the recorder and decodes locally (~1-2s).
  /// Online path: waits up to 1200ms for the final result after stop().
  /// Returns empty string if nothing usable was captured this session
  /// (prevents stale text from triggering a duplicate command).
  Future<String> stopSttListening() async {
    if (_whisperSession) {
      _whisperSession = false;
      final text = await WhisperSttService.instance.stopAndTranscribe();
      if (text.isNotEmpty) _whisperOnResult?.call(text);
      _whisperOnResult = null;
      return text;
    }

    await _stt.stop();

    // Wait briefly for STT to deliver the final result.
    // Google STT typically delivers final ~200-500ms after stop().
    final deadline = DateTime.now().add(const Duration(milliseconds: 1200));
    while (!_gotFinalResult && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Critical: clear callback so any 'done' status from cancel() in
    // the next startSttListening doesn't fire stale processing
    _autoStopCallback = null;

    // If we never got a final result, the text we have is stale
    // (probably from a previous session). Return empty to prevent
    // double-fire.
    if (!_gotFinalResult) {
      _log.d('STT stopped. No final result this session — returning empty (was: "$_lastWords")');
      _lastWords = '';
      return '';
    }

    final result = _lastWords;
    _log.d('STT stopped. Result: "$result" final=true');

    // Clear for next session
    _lastWords = '';
    _gotFinalResult = false;
    return result;
  }

  /// Abort the current session without transcribing (tap-cancel).
  Future<void> cancelSttListening() async {
    if (_whisperSession) {
      _whisperSession  = false;
      _whisperOnResult = null;
      await WhisperSttService.instance.cancel();
      return;
    }
    await stopSttListening();
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
    await WhisperSttService.instance.dispose();
    await _recorder.dispose();
  }
}