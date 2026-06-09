// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/feature_flags.dart';
import 'services/app_registry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Labs feature flags (all default OFF) — load before any service looks at them.
  await FeatureFlags.init();

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
