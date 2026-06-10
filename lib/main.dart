// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/feature_flags.dart';
import 'services/app_registry.dart';
import 'services/bubble_service.dart';
import 'services/share_target_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Labs feature flags (all default OFF) — load before any service looks at them.
  await FeatureFlags.init();
  // Component enabled-state survives app-data clears; flags don't. Re-align
  // the share-sheet alias with the flag on every cold start.
  await ShareTargetService.instance.syncNativeState();
  // Bubble left on by the user → bring it back (it doesn't survive reboots
  // on its own; no boot receiver by design).
  if (FeatureFlags.floatingBubble.value) {
    await BubbleService.instance.startIfPermitted();
  }

  await FlutterGemma.initialize();

  await AppRegistry.instance.loadInstalledApps();

  // Lock to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Full screen immersive
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  Brightness.light,
      systemNavigationBarColor: Colors.black,
    ),
  );

  runApp(
    const ProviderScope(
      child: VaniApp(),
    ),
  );
}
