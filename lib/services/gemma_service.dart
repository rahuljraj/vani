// lib/services/gemma_service.dart
//
// STUB — flutter_gemma is stripped from the beta build (gemmaEnabled=false)
// to keep the cold-install APK lean. This keeps the full GemmaService public
// surface so call sites (home_screen.dart) compile unchanged. Model methods
// are no-ops that log a warning and return false; nothing throws.
// Re-enabling Gemma in v1.1 = restore the flutter_gemma dependency and the
// real implementation from git history — but see the note on process().

import 'package:logger/logger.dart';
import '../models/vani_intent.dart';
import 'fast_intent_engine.dart';
import 'miss_log.dart';

class GemmaService {
  static GemmaService? _instance;
  static GemmaService get instance =>
      _instance ??= GemmaService._();
  GemmaService._();

  final _log = Logger();

  bool get isReady => false;
  bool get isLoading => false;

  Future<bool> isModelDownloaded() async {
    _log.w('GemmaService stub: no model in beta build');
    return false;
  }

  Future<bool> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    _log.w('GemmaService stub: downloadModel() is a no-op in beta build');
    return false;
  }

  Future<bool> initialize({
    void Function(double)? onProgress,
  }) async {
    _log.w('GemmaService stub: initialize() is a no-op in beta build');
    return false;
  }

  Future<VaniIntent> process(String userText) async {
    // LIVE BETA PATH — do not blind-revert in v1.1.
    _log.i('🎤 Heard: "$userText"');

    if (userText.trim().isEmpty) {
      _log.w('Empty transcript — STT returned nothing');
      return VaniIntent(
        type: IntentType.chat,
        app: AppTarget.none,
        parameters: {},
        speakText: 'Awaaz nahi aayi. Dobara bolein?',
        actionCode: 'none',
      );
    }

    final fast = FastIntentEngine.tryMatch(userText);
    if (fast != null) {
      _log.d('Fast match: ${fast.actionCode}');
      return fast;
    }

    _log.w('No fast match — model not available in beta build');
    // Fire-and-forget: never let logging block or break the voice path.
    MissLog.instance.record(userText);
    final heard = userText.trim();
    return VaniIntent(
      type: IntentType.chat,
      app: AppTarget.none,
      parameters: {},
      speakText: heard.isNotEmpty
          // STT worked; VANI just can't do this yet. Asking the user to repeat
          // sends them round a loop that can never succeed — they say it three
          // times, get the same reply, and conclude VANI is broken. Say what
          // is actually true instead. The utterance is in MissLog either way.
          ? 'Maine suna: "$heard" — ye main abhi nahi kar sakti.'
          // Nothing was transcribed — here repeating genuinely might work.
          : 'Kuch sunayi nahi diya, dobara bolein?',
      actionCode: 'none',
    );
  }

  Stream<String> streamResponse(String userText) async* {
    _log.w('GemmaService stub: streamResponse() has no model in beta build');
    yield 'AI ready nahi hai abhi.';
  }

  Future<void> dispose() async {}
}
