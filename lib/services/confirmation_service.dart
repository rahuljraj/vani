// lib/services/confirmation_service.dart
//
// One-shot spoken yes/no confirmation. Speaks a question, listens briefly,
// classifies the reply. UNCLEAR is treated as NO by callers — for actions
// like dialing, the safe failure is "don't act."

import 'dart:async';
import 'package:logger/logger.dart';
import 'audio_service.dart';
import 'tts_service.dart';

enum ConfirmResult { yes, no, unclear }

class ConfirmationService {
  static ConfirmationService? _instance;
  static ConfirmationService get instance =>
      _instance ??= ConfirmationService._();
  ConfirmationService._();

  final _log = Logger();

 static const _yesWords = {
    'haan', 'han', 'ha', 'haa', 'yes', 'yeah', 'ok', 'okay',
    'karo', 'kardo', 'theek', 'thik', 'bilkul', 'sahi', 'correct',
    'हाँ', 'हां', 'हा', 'करो', 'ठीक', 'बिल्कुल', 'सही', 'ओके',
  };
  static const _noWords = {
    'nahi', 'nahin', 'nhi', 'no', 'nope', 'naa', 'na', 'mat', 'cancel',
    'rehne', 'ruko', 'band', 'rukja', 'stop', 'badme', 'baad',
    'नहीं', 'नही', 'ना', 'मत', 'रुको', 'बंद', 'रहने', 'बाद',
  };

  /// Speak [question], listen ~6s for a short reply, classify it.
  Future<ConfirmResult> confirm(String question) async {
    await TtsService.instance.speak(question);
    // Small buffer so the mic doesn't catch the tail of our own TTS.
    await Future.delayed(const Duration(milliseconds: 300));

    final completer = Completer<String>();

    final started = await AudioService.instance.startSttListening(
      onResult: (text) {
        if (!completer.isCompleted) completer.complete(text);
      },
      onAutoStop: () async {
        if (completer.isCompleted) return;
        final text = await AudioService.instance.stopSttListening();
        if (!completer.isCompleted) completer.complete(text);
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 4),
    );

    if (!started) {
      _log.w('🎯 Confirm: STT unavailable → unclear');
      return ConfirmResult.unclear;
    }

    final heard = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => '',
    );

    final result = _classify(heard);
    _log.i('🎯 Confirm heard: "$heard" → $result');
    return result;
  }

  /// Speak [question], do one listen (same windows as confirm()), and return
  /// the raw transcript — '' on timeout or when STT is unavailable.
  Future<String> askOnce(String question) async {
    await TtsService.instance.speak(question);
    // Small buffer so the mic doesn't catch the tail of our own TTS.
    await Future.delayed(const Duration(milliseconds: 300));

    final completer = Completer<String>();

    final started = await AudioService.instance.startSttListening(
      onResult: (text) {
        if (!completer.isCompleted) completer.complete(text);
      },
      onAutoStop: () async {
        if (completer.isCompleted) return;
        final text = await AudioService.instance.stopSttListening();
        if (!completer.isCompleted) completer.complete(text);
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 4),
    );

    if (!started) {
      _log.w('🎯 askOnce: STT unavailable → empty transcript');
      return '';
    }

    final heard = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => '',
    );
    _log.i('🎯 askOnce heard: "$heard"');
    return heard;
  }

  /// Speak [announcement], then hold a short objection window and return the
  /// raw transcript — '' on silence/timeout/unavailable.
  /// Extend-on-speech: pure silence ends the session after ~1.2s (pauseFor),
  /// but once the user starts speaking the window stays open while speech
  /// continues, hard-capped at 8s (listenFor), so an utterance like
  /// "nahi Amitji ko" is never cut off mid-word. The transcript resolves
  /// only on the FINAL result (AudioService forwards finals only; partials
  /// never reach the completer), or on auto-stop's drained transcript.
  /// Use confirm()/askOnce() where an explicit answer is required.
  Future<String> objectionWindow(String announcement) async {
    await TtsService.instance.speak(announcement);
    // Small buffer so the mic doesn't catch the tail of our own TTS.
    await Future.delayed(const Duration(milliseconds: 300));

    final completer = Completer<String>();
    final sw = Stopwatch()..start();

    final started = await AudioService.instance.startSttListening(
      onResult: (text) {
        if (!completer.isCompleted) completer.complete(text);
      },
      onAutoStop: () async {
        if (completer.isCompleted) return;
        final text = await AudioService.instance.stopSttListening();
        if (!completer.isCompleted) completer.complete(text);
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(milliseconds: 2000),
    );

    if (!started) {
      _log.w('🎯 Objection window: STT unavailable → no objection');
      return '';
    }

    final heard = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => '',
    );
    _log.i('🎯 Objection window: heard "$heard" after ${sw.elapsedMilliseconds}ms');
    return heard;
  }

  /// True if [heard] contains any no-word — lets callers detect a spoken
  /// cancel inside a longer reply without duplicating the word set.
  bool containsNo(String heard) {
    final words = heard.toLowerCase().trim().split(RegExp(r'\s+'));
    return words.any(_noWords.contains);
  }

  /// True if [heard] contains any yes-word — mirror of containsNo, for
  /// classifying an objection-window transcript.
  bool containsYes(String heard) {
    final words = heard.toLowerCase().trim().split(RegExp(r'\s+'));
    return words.any(_yesWords.contains);
  }

  /// Removes every no-word from [heard], wherever it appears, so a redirect
  /// like "nahi mummy ko" yields the intended name for contact resolution.
  String stripNoWords(String heard) {
    return heard
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => !_noWords.contains(w.toLowerCase()))
        .join(' ');
  }

  ConfirmResult _classify(String heard) {
    final words = heard.toLowerCase().trim().split(RegExp(r'\s+'));
    if (words.every((w) => w.isEmpty)) return ConfirmResult.unclear;
    // NO wins over YES: "haan nahi nahi" means no.
    if (words.any(_noWords.contains)) return ConfirmResult.no;
    if (words.any(_yesWords.contains)) return ConfirmResult.yes;
    return ConfirmResult.unclear;
  }
}