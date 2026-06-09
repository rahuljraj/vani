// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../services/gemma_service.dart';
import '../services/permission_service.dart';
import '../services/actions/action_router.dart';
import '../models/vani_intent.dart';
import '../services/app_deep_links.dart';

enum VaniState { idle, listening, thinking, speaking, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  final _router   = ActionRouter();
  final _textCtrl = TextEditingController();

  VaniState _state            = VaniState.idle;
  String    _transcript       = '';
  String    _response         = '';
  bool      _modelReady       = false;
  bool      _autoListened     = false;   // QS tile launch started the mic
  bool      _modelError       = false;
  String    _modelErrorReason = '';
  bool      _isDownloading    = false;
  double    _downloadProgress = 0.0;
  String    _loadingStep      = '';
  VaniIntent? _pendingChoice;   // set when VANI needs the user to pick an app

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  late AnimationController _glowCtrl;
  late Animation<double>   _glowAnim;

 @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _initModel();
    _checkAutoListen();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Warm tile-tap: app resumes with the native flag already set.
    if (state == AppLifecycleState.resumed) _checkAutoListen();
  }

  /// Opened via the Quick Settings tile → jump straight to listening.
  /// Native sets a one-shot flag; we consume it here.
  Future<void> _checkAutoListen() async {
    final pending = await PermissionService.instance.consumeAutoListen();
    if (!pending || !mounted) return;
    if (_state == VaniState.listening || _state == VaniState.thinking) return;
    _autoListened = true;                // suppress the model-ready greeting
    _startListening();                   // mic on now — no wait for Gemma
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

  void _failWith(String reason) {
    if (!mounted) return;
    setState(() {
      _modelError       = true;
      _modelErrorReason = reason;
      _loadingStep      = '';
      _isDownloading    = false;
    });
  }

  Future<void> _initModel() async {
    if (mounted) setState(() {
      _modelError       = false;
      _modelErrorReason = '';
      _loadingStep      = 'Shuru ho rahi hai...';
    });

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
        _failWith(
          'Model download fail ho gaya.\n'
          'Internet check karein, ya model file ko\n'
          '/sdcard/Download/gemma_model.litertlm pe daalein.',
        );
        return;
      }
    }

    // MANAGE_EXTERNAL_STORAGE is required on Android 11+ to copy the model
    // file from /sdcard/Download/ to internal storage on first launch.
    if (!await PermissionService.instance.hasAllFilesAccess) {
      if (mounted) setState(() => _loadingStep = 'Storage access chahiye — "Allow" karein');
      final granted = await PermissionService.instance.requestAllFilesAccess();
      if (!granted) {
        _failWith(
          'Storage permission nahi mila.\n'
          'Settings → Apps → VANI → Permissions\n'
          'mein "All files access" allow karein.',
        );
        return;
      }
    }

    if (mounted) setState(() {
      _loadingStep = 'Model load ho raha hai... (pehli baar thoda time lagega)';
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final ok = await GemmaService.instance.initialize(
      onProgress: (p) {
        if (mounted) setState(() => _downloadProgress = p);
      },
    );
    if (mounted) setState(() => _isDownloading = false);
    if (!ok) {
      _failWith(
        'Model load fail ho gaya.\n'
        'File corrupt ho sakti hai, ya phone mein\n'
        'kaafi RAM/storage nahi hai (6GB+ chahiye).',
      );
      return;
    }
    if (mounted) {
      setState(() {
        _modelReady       = true;
        _modelError       = false;
        _modelErrorReason = '';
        _loadingStep      = '';
      });
      // Don't greet over a tile-launched listening/command session.
      if (!_autoListened && _state == VaniState.idle) {
        await TtsService.instance.speak('VANI ready hai. Bataiye kya karein?');
      }
    }
  }

  Future<void> _retryModel() async {
    await GemmaService.instance.dispose();
    await _initModel();
  }

  // ── Recording ───────────────────────────────────
  Future<void> _startListening() async {
  if (_state == VaniState.thinking) return;
  // Intentionally NOT gated on _modelReady: STT (online) + FastIntentEngine
  // handle ~90% of commands with no model. If a command falls through to
  // Gemma before it's loaded, GemmaService.process() returns a graceful
  // "AI load ho rahi hai" reply — no crash, no hang.
  await TtsService.instance.stop();

  final ok = await AudioService.instance.startSttListening(
    onResult: (text) {
      if (mounted && text.isNotEmpty) {
        setState(() => _transcript = text);
      }
    },
    // Auto-fire stop+process when STT detects 2s silence
    onAutoStop: () {
      if (_state == VaniState.listening) _stopAndProcess();
    },
  );

  if (ok && mounted) setState(() {
    _state      = VaniState.listening;
    _transcript = '';
    _response   = '';
  });
}

  Future<void> _stopAndProcess() async {
    if (_state != VaniState.listening) return;

    final text = await AudioService.instance.stopSttListening();

    if (text.trim().isEmpty) {
      if (mounted) setState(() => _state = VaniState.idle);
      return;
    }

    await processText(text);
  }

  Future<void> _cancelListening() async {
    await AudioService.instance.stopSttListening();
    if (mounted) setState(() => _state = VaniState.idle);
  }

  // ── Process Text (called from text input) ───────
  Future<void> processText(String text) async {
    if (text.trim().isEmpty) return;
    _textCtrl.clear();

    setState(() {
      _state         = VaniState.thinking;
      _transcript    = text;
      _response      = '';
      _pendingChoice = null;   // dismiss any stale choice on a new command
    });

    final intent = await GemmaService.instance.process(text);

    if (!mounted) return;

    // VANI needs the user to pick an app → show buttons, don't act yet.
    if (intent.actionCode == 'disambiguate') {
      setState(() {
        _state         = VaniState.idle;
        _response      = intent.speakText;
        _pendingChoice = intent;
      });
      await TtsService.instance.speak(intent.speakText);
      return;
    }

    setState(() {
      _state    = VaniState.speaking;
      _response = intent.speakText;
    });

    await _router.execute(intent);

    if (mounted) setState(() => _state = VaniState.idle);
  }

 void _onChoice(String label) {
    final intent = _pendingChoice;
    final item = intent?.parameters['item'] ?? '';
    setState(() => _pendingChoice = null);

    // Grocery choices carry aligned package names → search by package directly,
    // since "zepto pe doodh" has no dedicated matcher (only _blinkit does).
    if (intent?.parameters['kind'] == 'grocery') {
      final names = (intent?.parameters['candidates'] ?? '').split(',');
      final pkgs  = (intent?.parameters['pkgs'] ?? '').split(',');
      final i = names.indexOf(label);
      if (i >= 0 && i < pkgs.length) {
        final uri = AppDeepLinks.searchUri(pkgs[i], item);
        _router.execute(VaniIntent(
          type: IntentType.orderFood,
          app: AppTarget.none,
          parameters: {
            'package': pkgs[i],
            'name': label,
            if (item.isNotEmpty) 'query': item,
            if (uri != null) 'uri': uri.toString(),
          },
          speakText: item.isEmpty ? '$label khol raha hoon'
                                  : '$label pe $item dhundh raha hoon',
          actionCode: 'app_search_deeplink',
        ));
        return;
      }
    }

    // Food/other choices → re-dispatch as text through the engine.
    processText(item.isEmpty ? label : '$label pe $item');
  }

  Widget _buildChoices() {
    final intent = _pendingChoice;
    if (intent == null) return const SizedBox.shrink();
    final candidates = (intent.parameters['candidates'] ?? '')
        .split(',')
        .where((c) => c.isNotEmpty)
        .toList();
    if (candidates.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: candidates.map((c) {
          final label = c[0].toUpperCase() + c.substring(1);
          return ElevatedButton(
            onPressed: () => _onChoice(c),
            style: ElevatedButton.styleFrom(
              backgroundColor: VaniColors.surfaceLight,
              foregroundColor: VaniColors.primary,
              side: const BorderSide(color: VaniColors.accent),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(label, style: const TextStyle(fontSize: 16)),
          );
        }).toList(),
      ),
    );
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
    // An active voice interaction always wins — even while Gemma loads
    // in the background after a tile launch.
    switch (_state) {
      case VaniState.listening: return VaniStrings.listening;
      case VaniState.thinking:  return VaniStrings.thinking;
      case VaniState.speaking:  return VaniStrings.speaking;
      case VaniState.idle:
      case VaniState.error:
        break;
    }
    if (_isDownloading) {
      final pct = (_downloadProgress * 100).toStringAsFixed(0);
      final label = _loadingStep.isNotEmpty
          ? _loadingStep
          : 'AI download ho rahi hai...';
      return '$label $pct%';
    }
    if (_modelError) return 'Error — Retry karein';
    if (_loadingStep.isNotEmpty) return _loadingStep;
    return _modelReady ? VaniStrings.holdToSpeak : VaniStrings.modelLoading;
  }

 @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _textCtrl.dispose();
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
             _buildChoices(),
            const Spacer(),
            _buildMicButton(),
            const SizedBox(height: 12),
            _buildStatusText(),
            if (_modelError) ...[
              const SizedBox(height: 8),
              if (_modelErrorReason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _modelErrorReason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color:    VaniColors.textHint,
                      fontSize: 12,
                      height:   1.4,
                    ),
                  ),
                ),
              TextButton(
                onPressed: _retryModel,
                child: const Text(
                  'Dobara try karein',
                  style: TextStyle(color: VaniColors.accent, fontSize: 13),
                ),
              ),
            ],
             if (_isDownloading && _state == VaniState.idle) ...[
              const SizedBox(height: 4),
              const Text(
                'Sirf pehli baar — 557 MB',
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

          // Labs + Apps buttons
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/labs'),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        VaniColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VaniColors.border),
                ),
                child: const Icon(
                  Icons.science_outlined,
                  color: VaniColors.textSecondary,
                  size:  20,
                ),
              ),
            ),
            const SizedBox(width: 10),
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
          ]),
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
    final disabled    = isThinking || !_modelReady;

    return GestureDetector(
     onTapDown:   disabled ? null : (_) => _startListening(),
     onTapUp:     disabled ? null : (_) => _stopAndProcess(),
     onTapCancel: disabled ? null : ()  => _cancelListening(),
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
              controller: _textCtrl,
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