// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../services/gemma_service.dart';
import '../services/actions/action_router.dart';

enum VaniState { idle, listening, thinking, speaking, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {

  final _router = ActionRouter();

  VaniState _state            = VaniState.idle;
  String    _transcript       = '';
  String    _response         = '';
  bool      _modelReady       = false;
  bool      _modelError       = false;
  bool      _isDownloading    = false;
  double    _downloadProgress = 0.0;
  String    _loadingStep      = '';

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  late AnimationController _glowCtrl;
  late Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initModel();
  }

  void _setupAnimations() {
    _pulseCtrl = AnimationController(
      duration: VaniDurations.pulseAnimation,
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18)
      .animate(CurvedAnimation(
        parent: _pulseCtrl,
        curve: Curves.easeInOut,
      ));

    _glowCtrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.3, end: 0.8)
      .animate(CurvedAnimation(
        parent: _glowCtrl,
        curve: Curves.easeInOut,
      ));
  }

  Future<void> _initModel() async {
    if (mounted) setState(() { _modelError = false; _loadingStep = 'Shuru ho rahi hai...'; });

    // Check sdcard or docs directory for model
    final modelAvailable = await GemmaService.instance.isModelDownloaded();
    if (!modelAvailable) {
      // Model not on device yet — try network download
      if (mounted) setState(() { _isDownloading = true; _loadingStep = 'Model download ho rahi hai...'; });

      final ok = await GemmaService.instance.downloadModel(
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );

      if (mounted) setState(() => _isDownloading = false);
      if (!ok) {
        if (mounted) setState(() { _modelError = true; _loadingStep = ''; });
        return;
      }
    }

    if (mounted) setState(() => _loadingStep = 'Model load ho raha hai... please wait');

    final ok = await GemmaService.instance.initialize();
    if (mounted) {
      setState(() {
        _modelReady  = ok;
        _modelError  = !ok;
        _loadingStep = '';
      });
      if (ok) await TtsService.instance.speak('VANI ready hai. Bataiye kya karein?');
    }
  }

  Future<void> _retryModel() async {
    await GemmaService.instance.dispose();
    await _initModel();
  }

  // ── Recording ───────────────────────────────────
  Future<void> _startListening() async {
    if (_state == VaniState.thinking) return;
    await TtsService.instance.stop();

    final ok = await AudioService.instance.startSttListening(
      onResult: (text) {
        if (mounted && text.isNotEmpty) {
          setState(() => _transcript = text);
        }
      },
    );

    if (ok) setState(() {
      _state      = VaniState.listening;
      _transcript = '';
      _response   = '';
    });
  }

  Future<void> _stopAndProcess() async {
    if (_state != VaniState.listening) return;

    final text = await AudioService.instance.stopSttListening();

    if (text.trim().isEmpty) {
      setState(() => _state = VaniState.idle);
      return;
    }

    await processText(text);
  }

  Future<void> _cancelListening() async {
    await AudioService.instance.stopSttListening();
    setState(() => _state = VaniState.idle);
  }

  // ── Process Text (called from text input) ───────
  Future<void> processText(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _state      = VaniState.thinking;
      _transcript = text;
      _response   = '';
    });

    final intent = await GemmaService.instance.process(text);

    if (!mounted) return;

    setState(() {
      _state    = VaniState.speaking;
      _response = intent.speakText;
    });

    await _router.execute(intent);

    if (mounted) setState(() => _state = VaniState.idle);
  }

  Color get _buttonColor {
    switch (_state) {
      case VaniState.listening: return VaniColors.listening;
      case VaniState.thinking:  return VaniColors.thinking;
      case VaniState.speaking:  return VaniColors.speaking;
      default:                  return VaniColors.primary;
    }
  }

  String get _statusText {
    if (_isDownloading) {
      final pct = (_downloadProgress * 100).toStringAsFixed(0);
      return 'AI download ho rahi hai... $pct%';
    }
    if (_modelError) return 'Error — Retry karein';
    if (_loadingStep.isNotEmpty) return _loadingStep;
    switch (_state) {
      case VaniState.listening: return VaniStrings.listening;
      case VaniState.thinking:  return VaniStrings.thinking;
      case VaniState.speaking:  return VaniStrings.speaking;
      default:
        return _modelReady ? VaniStrings.holdToSpeak : VaniStrings.modelLoading;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaniColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Spacer(),
            _buildTranscript(),
            _buildResponse(),
            const Spacer(),
            _buildMicButton(),
            const SizedBox(height: 12),
            _buildStatusText(),
            if (_modelError) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _retryModel,
                child: const Text(
                  'Dobara try karein',
                  style: TextStyle(color: VaniColors.accent, fontSize: 13),
                ),
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 4),
              const Text(
                'Sirf pehli baar — 555 MB',
                style: TextStyle(color: VaniColors.textHint, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    minHeight: 4,
                    backgroundColor: VaniColors.surfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(VaniColors.accent),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildTextInput(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // VANI logo
          Row(children: [
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _modelReady
                    ? VaniColors.speaking
                    : VaniColors.textHint,
                  boxShadow: _modelReady ? [
                    BoxShadow(
                      color:       VaniColors.speaking.withValues(alpha: _glowAnim.value),
                      blurRadius:  8,
                      spreadRadius: 2,
                    ),
                  ] : [],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              VaniStrings.appName,
              style: TextStyle(
                color:       VaniColors.primary,
                fontSize:    22,
                fontWeight:  FontWeight.w800,
                letterSpacing: 6,
              ),
            ),
          ]),

          // Apps button
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/apps'),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        VaniColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VaniColors.border),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: VaniColors.textSecondary,
                size:  20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Transcript ──────────────────────────────────
  Widget _buildTranscript() {
    if (_transcript.isEmpty) return const SizedBox(height: 20);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        _transcript,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color:    VaniColors.textSecondary,
          fontSize: 15,
          height:   1.5,
        ),
      ),
    );
  }

  // ── AI Response ─────────────────────────────────
  Widget _buildResponse() {
    if (_response.isEmpty) return const SizedBox(height: 20);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color:        VaniColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VaniColors.accent.withValues(alpha: 0.3)),
        ),
        child: Text(
          _response,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color:      VaniColors.primary,
            fontSize:   16,
            fontWeight: FontWeight.w500,
            height:     1.4,
          ),
        ),
      ),
    );
  }

  // ── Mic Button ──────────────────────────────────
  Widget _buildMicButton() {
    final isListening = _state == VaniState.listening;
    final isThinking  = _state == VaniState.thinking;

    return GestureDetector(
      onTapDown:   isThinking ? null : (_) => _startListening(),
      onTapUp:     isThinking ? null : (_) => _stopAndProcess(),
      onTapCancel: isThinking ? null : ()  => _cancelListening(),
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) {
          final scale = isListening ? _pulseAnim.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _buttonColor,
            boxShadow: [
              BoxShadow(
                color:       _buttonColor.withValues(
                  alpha: isListening ? 0.5 : 0.25
                ),
                blurRadius:  isListening ? 40 : 20,
                spreadRadius: isListening ? 10 : 4,
              ),
            ],
          ),
          child: isThinking
            ? const Center(
                child: SizedBox(
                  width: 32, height: 32,
                  child: CircularProgressIndicator(
                    color:       VaniColors.background,
                    strokeWidth: 3,
                  ),
                ),
              )
            : Icon(
                isListening ? Icons.stop_rounded : Icons.mic_rounded,
                size:  44,
                color: isListening
                  ? VaniColors.primary
                  : VaniColors.background,
              ),
        ),
      ),
    );
  }

  // ── Status Text ─────────────────────────────────
  Widget _buildStatusText() {
    return Text(
      _statusText,
      style: TextStyle(
        color:    _state == VaniState.listening
          ? VaniColors.listening
          : VaniColors.textSecondary,
        fontSize: 13,
      ),
    );
  }

  // ── Text Input (MVP fallback) ────────────────────
  // Remove in Phase 2 when audio→Gemma 4 is wired up
  Widget _buildTextInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: const TextStyle(color: VaniColors.primary, fontSize: 14),
              decoration: InputDecoration(
                hintText:      'Ya yahan type karein...',
                hintStyle:     const TextStyle(color: VaniColors.textHint, fontSize: 14),
                filled:        true,
                fillColor:     VaniColors.surfaceLight,
                border:        OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:   const BorderSide(color: VaniColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:   const BorderSide(color: VaniColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:   const BorderSide(color: VaniColors.accent),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12,
                ),
              ),
              onSubmitted: processText,
              textInputAction: TextInputAction.send,
            ),
          ),
        ],
      ),
    );
  }
}
