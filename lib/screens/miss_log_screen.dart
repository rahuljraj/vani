// lib/screens/miss_log_screen.dart
//
// Viewer for MissLog — the utterances FastIntentEngine could not route.
// This screen exists so a beta tester can SHOW the founder what VANI
// missed. It reads the on-device log only. Nothing here uploads: the
// copy button puts text on the clipboard, and the tester decides what
// to do with it. Retrieval stays manual and user-initiated.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../services/miss_log.dart';

class MissLogScreen extends StatefulWidget {
  const MissLogScreen({super.key});

  @override
  State<MissLogScreen> createState() => _MissLogScreenState();
}

class _MissLogScreenState extends State<MissLogScreen> {

  List<MissEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await MissLog.instance.entries();
    if (mounted) {
      setState(() {
        _entries = list;
        _loading = false;
      });
    }
  }

  Future<void> _copy() async {
    final text = await MissLog.instance.asText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copied — ab kisi ko bhej sakte hain.'),
        backgroundColor: VaniColors.surfaceLight,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VaniColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: const Text(
          'Clear log?',
          style: TextStyle(
            color:      VaniColors.primary,
            fontSize:   17,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Saare unmatched commands delete ho jayenge. '
          'Yeh wapas nahi aayega.',
          style: TextStyle(
            color:    VaniColors.textSecondary,
            fontSize: 14,
            height:   1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Rehne do',
              style: TextStyle(color: VaniColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(
                color:      VaniColors.listening,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await MissLog.instance.clear();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaniColors.background,
      appBar: AppBar(
        backgroundColor: VaniColors.background,
        elevation:       0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_rounded,
            color: VaniColors.textSecondary, size: 20),
        ),
        title: const Text(
          'Missed Commands',
          style: TextStyle(
            color:      VaniColors.primary,
            fontSize:   18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_entries.isNotEmpty) ...[
            IconButton(
              onPressed: _copy,
              tooltip: 'Copy',
              icon: const Icon(Icons.copy_rounded,
                color: VaniColors.textSecondary, size: 20),
            ),
            IconButton(
              onPressed: _confirmClear,
              tooltip: 'Clear',
              icon: const Icon(Icons.delete_outline_rounded,
                color: VaniColors.textSecondary, size: 20),
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: VaniColors.border),
        ),
      ),

      body: _loading
        ? const Center(
            child: CircularProgressIndicator(color: VaniColors.accent),
          )
        : _entries.isEmpty
          ? _emptyState()
          : _list(),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
              color: VaniColors.speaking, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Abhi tak koi command miss nahi hui.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:    VaniColors.textSecondary,
                fontSize: 15,
                height:   1.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Jab VANI kisi baat ko samajh nahi paayega,\n'
              'woh yahan record hoga.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:    VaniColors.textHint,
                fontSize: 13,
                height:   1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    return Column(
      children: [
        _header(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: _entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _tile(_entries[i]),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    final n = _entries.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Text(
            n == 1 ? '1 missed command' : '$n missed commands',
            style: const TextStyle(
              color:       VaniColors.textHint,
              fontSize:    12,
              fontWeight:  FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          const Icon(Icons.lock_rounded,
            color: VaniColors.textHint, size: 13),
          const SizedBox(width: 5),
          const Text(
            'On-device',
            style: TextStyle(
              color:    VaniColors.textHint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(MissEntry e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        VaniColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VaniColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.utterance,
            style: const TextStyle(
              color:    VaniColors.primary,
              fontSize: 15,
              height:   1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatTime(e.at),
            style: const TextStyle(
              color:    VaniColors.textHint,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // YYYY-MM-DD HH:MM — matches the on-device timestamp, no locale deps.
  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}  '
           '${two(t.hour)}:${two(t.minute)}';
  }
}
