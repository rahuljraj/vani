// lib/screens/apps_screen.dart

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/connected_app.dart';
import '../services/permission_service.dart';

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {

  late List<ConnectedApp> _apps;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _apps = ConnectedApp.defaults;
    _checkInstalled();
  }

  Future<void> _checkInstalled() async {
    for (final app in _apps) {
      app.isInstalled = await PermissionService.instance
        .isAppInstalled(app.packageName);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaniColors.background,
      appBar: AppBar(
        backgroundColor:  VaniColors.background,
        elevation:        0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_rounded,
            color: VaniColors.textSecondary, size: 20),
        ),
        title: const Text(
          VaniStrings.connectedApps,
          style: TextStyle(
            color:      VaniColors.primary,
            fontSize:   18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: VaniColors.border),
        ),
      ),

      body: _loading
        ? const Center(
            child: CircularProgressIndicator(color: VaniColors.accent),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // Info card
              _infoCard(),
              const SizedBox(height: 20),

              // Active apps
              const _SectionLabel('CONNECTED'),
              ..._apps.where((a) => a.isEnabled).map(_buildTile),

              const SizedBox(height: 20),

              // Available apps
              const _SectionLabel('AVAILABLE'),
              ..._apps.where((a) => !a.isEnabled && !a.isComingSoon).map(_buildTile),

              const SizedBox(height: 20),

              // Coming soon
              const _SectionLabel('COMING SOON'),
              ..._apps.where((a) => a.isComingSoon).map(_buildTile),

              const SizedBox(height: 40),
            ],
          ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        VaniColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: VaniColors.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded,
            color: VaniColors.accent, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Sirf aap decide karte hain kaunsa app\n'
              'VANI use kar sakta hai.',
              style: TextStyle(
                color:    VaniColors.textSecondary,
                fontSize: 13,
                height:   1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(ConnectedApp app) {
    final canToggle = !app.isComingSoon;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        VaniColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: app.isEnabled
            ? app.color.withValues(alpha: 0.3)
            : VaniColors.border,
          width: app.isEnabled ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 4),

        // Emoji icon
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: app.color.withValues(alpha: 0.12),
          ),
          child: Center(
            child: Text(app.emoji,
              style: const TextStyle(fontSize: 22)),
          ),
        ),

        // Name + description
        title: Row(
          children: [
            Text(
              app.name,
              style: TextStyle(
                color:      app.isEnabled
                  ? VaniColors.primary
                  : VaniColors.textSecondary,
                fontSize:   15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (app.isComingSoon) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color:        VaniColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  VaniStrings.comingSoon,
                  style: const TextStyle(
                    color:    VaniColors.textHint,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
            if (!app.isInstalled && !app.isComingSoon) ...[
              const SizedBox(width: 8),
              const Icon(Icons.download_rounded,
                color: VaniColors.textHint, size: 14),
            ],
          ],
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            app.description,
            style: const TextStyle(
              color:    VaniColors.textHint,
              fontSize: 12,
            ),
          ),
        ),

        // Toggle switch
        trailing: Switch(
          value:     app.isEnabled,
          onChanged: canToggle ? (val) {
            setState(() => app.isEnabled = val);
          } : null,
          activeThumbColor: app.color,
          trackColor:    WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) {
              return app.color.withValues(alpha: 0.3);
            }
            return VaniColors.border;
          }),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color:       VaniColors.textHint,
          fontSize:    11,
          fontWeight:  FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
