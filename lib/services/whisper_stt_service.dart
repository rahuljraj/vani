// lib/services/whisper_stt_service.dart

import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import '../core/stt_config.dart';

/// Fully offline speech-to-text — whisper.cpp (GGML) running on-device.
///
/// Flow (Wispr-Flow style): hold to talk → release (or 2s of silence)
/// → local Whisper transcription → text. Zero network after the model
/// is on the device — works in airplane mode.
///
/// Model setup mirrors GemmaService: internal copy → side-loaded
/// /sdcard/Download file → one-time HuggingFace download.
class WhisperSttService {
  static WhisperSttService? _instance;
  static WhisperSttService get instance =>
      _instance ??= WhisperSttService._();
  WhisperSttService._();

  final _log      = Logger();
  final _whisper  = WhisperController();
  final _recorder = AudioRecorder();

  bool _isReady     = false;
  bool _isRecording = false;

  StreamSubscription<Amplitude>? _ampSub;
  Timer?   _maxUtteranceTimer;
  String?  _wavPath;
  bool     _heardSpeech = false;
  bool     _vadActive     = false;
  DateTime _lastSpeechAt  = DateTime.now();
  DateTime _recordStartAt = DateTime.now();
  void Function()? _onAutoStop;

  bool get isReady     => _isReady;
  bool get isRecording => _isRecording;

  // ── Model management ────────────────────────────

  Future<String> _modelPath() => _whisper.getPath(SttConfig.whisperModel);

  Future<bool> isModelDownloaded() async {
    final local = File(await _modelPath());
    if (local.existsSync() && local.lengthSync() > 1024 * 1024) return true;
    final sd = File(SttConfig.sdCardModelPath);
    return sd.existsSync() && sd.lengthSync() > 1024 * 1024;
  }

  /// Ensure the Whisper model is on internal storage.
  /// After this returns true, STT needs no network at all.
  Future<bool> initialize() async {
    if (_isReady) return true;
    try {
      final dest = File(await _modelPath());

      if (!dest.existsSync() || dest.lengthSync() < 1024 * 1024) {
        final sd = File(SttConfig.sdCardModelPath);
        if (sd.existsSync() && sd.lengthSync() > 1024 * 1024) {
          _log.i('Whisper model on SD card — copying to ${dest.path}');
          await dest.parent.create(recursive: true);
          await sd.copy(dest.path);
        } else {
          _log.i('Whisper model missing — one-time download '
                 '(~${SttConfig.modelSizeMb} MB)');
          await _whisper.downloadModel(SttConfig.whisperModel);
        }
      }

      if (!dest.existsSync() || dest.lengthSync() < 1024 * 1024) {
        _log.w('Whisper model still missing after setup');
        return false;
      }

      _isReady = true;
      _log.i('Whisper STT ready (${SttConfig.whisperModel.modelName}, '
             '${dest.lengthSync() ~/ (1024 * 1024)} MB) — fully offline');
      return true;
    } catch (e) {
      _log.e('Whisper init failed: $e');
      return false;
    }
  }

  // ── Recording + silence auto-stop ───────────────

  /// Start recording 16kHz mono WAV with an amplitude-based silence
  /// detector. [onAutoStop] fires once when the user stops speaking
  /// (or never speaks, or hits the utterance cap) — the caller then
  /// calls [stopAndTranscribe].
  Future<bool> startListening({void Function()? onAutoStop}) async {
    if (!_isReady) return false;
    if (_isRecording) await cancel();

    try {
      if (!await _recorder.hasPermission()) {
        _log.w('Mic permission missing');
        return false;
      }

      final dir = await getTemporaryDirectory();
      _wavPath =
          '${dir.path}/vani_stt_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder:     AudioEncoder.wav,
          sampleRate:  SttConfig.sampleRate,
          numChannels: 1,
        ),
        path: _wavPath!,
      );

      _isRecording   = true;
      _onAutoStop    = onAutoStop;
      _heardSpeech   = false;
      _recordStartAt = DateTime.now();
      _lastSpeechAt  = _recordStartAt;

    // Defensive VAD wiring: the record package's amplitude stream is
      // single-subscription and throws on this device when the recorder
      // is reused. VAD (silence auto-stop + speech gate) is an
      // optimisation — never let it break the actual recording/decode.
      await _ampSub?.cancel();
      _ampSub = null;
      _vadActive = false;
      try {
        _ampSub = _recorder
            .onAmplitudeChanged(SttConfig.vadInterval)
            .listen(_onAmplitude);
        _vadActive = true;
      } catch (e) {
        _log.w('VAD unavailable, decode gated by length only: $e');
      }
      _maxUtteranceTimer = Timer(SttConfig.maxUtterance, _fireAutoStop);

      _log.d('Whisper recording started (16kHz mono WAV)');
      return true;
    } catch (e) {
      _log.e('Whisper record start failed: $e');
      await cancel();
      return false;
    }
  }

  void _onAmplitude(Amplitude amp) {
    if (!_isRecording) return;
    final now = DateTime.now();

    if (amp.current > SttConfig.speechThresholdDb) {
      _heardSpeech  = true;
      _lastSpeechAt = now;
      return;
    }

    if (_heardSpeech) {
      if (now.difference(_lastSpeechAt) >= SttConfig.silenceTimeout) {
        _fireAutoStop();
      }
    } else if (now.difference(_recordStartAt) >= SttConfig.noSpeechTimeout) {
      _fireAutoStop();
    }
  }

  void _fireAutoStop() {
    final cb = _onAutoStop;
    _onAutoStop = null;
    _stopVad();
    cb?.call();
  }

  /// Stop recording and transcribe locally.
  /// Returns '' on silence or failure — never stale text.
  Future<String> stopAndTranscribe() async {
    if (!_isRecording) return '';
    _stopVad();
    _onAutoStop  = null;
    _isRecording = false;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      _log.e('Recorder stop failed: $e');
    }
    path ??= _wavPath;
    _wavPath = null;
    if (path == null) return '';

    final wav = File(path);
    try {
      // < ~0.3s of 16kHz PCM16 — nothing usable was captured
      if (!wav.existsSync() || wav.lengthSync() < 9600) {
        _log.d('Whisper: recording too short, skipping decode');
        return '';
      }
      
      // Only trust the speech gate when VAD actually ran. With VAD down,
      // the length check above already filters empty captures — decode
      // and let Whisper judge, rather than assuming silence.
      if (_vadActive && !_heardSpeech) {
        _log.d('Whisper: no speech detected this session, skipping decode');
        return '';
      }

      final sw = Stopwatch()..start();
      final result = await _whisper.transcribe(
        model:     SttConfig.whisperModel,
        audioPath: path,
        lang:      SttConfig.language,
      );
      final text = _clean(result?.transcription.text ?? '');
      _log.d('Whisper decoded in ${sw.elapsedMilliseconds}ms: "$text"');
      return text;
    } catch (e) {
      _log.e('Whisper transcribe failed: $e');
      return '';
    } finally {
      try { wav.deleteSync(); } catch (_) {}
    }
  }

  /// Whisper emits non-speech annotations and sentence punctuation that
  /// the intent matchers don't expect ("[BLANK_AUDIO]", "WhatsApp kholo.").
  String _clean(String raw) {
    var text = raw
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    text = text.replaceAll(RegExp(r'[.!?,;:]+$'), '').trim();
    return text;
  }

  /// Abort the session without transcribing.
  Future<void> cancel() async {
    _stopVad();
    _onAutoStop  = null;
    _isRecording = false;
    try { await _recorder.cancel(); } catch (_) {}
    if (_wavPath != null) {
      try { File(_wavPath!).deleteSync(); } catch (_) {}
      _wavPath = null;
    }
  }

  void _stopVad() {
    _ampSub?.cancel();
    _ampSub = null;
    _maxUtteranceTimer?.cancel();
    _maxUtteranceTimer = null;
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
