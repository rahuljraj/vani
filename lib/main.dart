// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/app_registry.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Started, not awaited — this was blocking the first frame for ~2.2s.
  // Callers that need the registry await ensureLoaded() at point of use.
  AppRegistry.instance.ensureLoaded();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

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