// lib/services/intent_service.dart
//
// LIVE INTENT ROUTER. Was gemma_service.dart until Aug 2026 — renamed because
// the old name hid what this file actually does.
//
// process() IS THE SHIPPED COMMAND PATH. Every utterance from home_screen
// enters here and is resolved by FastIntentEngine.tryMatch(). It also writes
// unmatched utterances to MissLog, which is where the real verb-gap data
// comes from. No model is involved anywhere in the beta build.
//
// ⚠️ The model methods below (isModelDownloaded / downloadModel / initialize /
// streamResponse) are no-op stubs, kept ONLY so home_screen.dart compiles
// unchanged while InferenceConfig.gemmaEnabled == false.
//
// ⚠️ RE-ENABLING AN LLM FALLBACK LATER MEANS ADDING A BRANCH INSIDE process(),
// AFTER the FastIntentEngine call and BEFORE the MissLog write. It does NOT
// mean restoring the old gemma_service.dart from git history. That file has no
// FastIntentEngine call and no MissLog write, and would delete both with no
// compile error.

import 'package:logger/logger.dart';
import '../models/vani_intent.dart';
import 'fast_intent_engine.dart';
import 'miss_log.dart';

class IntentService {
  static IntentService? _instance;
  static IntentService get instance =>
      _instance ??= IntentService._();
  IntentService._();

  final _log = Logger();

  bool get isReady => false;
  bool get isLoading => false;

  Future<bool> isModelDownloaded() async {
    _log.w('IntentService stub: no model in beta build');
    return false;
  }

  Future<bool> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    _log.w('IntentService stub: downloadModel() is a no-op in beta build');
    return false;
  }

  Future<bool> initialize({
    void Function(double)? onProgress,
  }) async {
    _log.w('IntentService stub: initialize() is a no-op in beta build');
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
    _log.w('IntentService stub: streamResponse() has no model in beta build');
    yield 'AI ready nahi hai abhi.';
  }

  Future<void> dispose() async {}
}
