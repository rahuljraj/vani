// lib/core/constants.dart

import 'package:flutter/material.dart';

class VaniColors {
  // Core palette
  static const background    = Color(0xFF000000);
  static const surface       = Color(0xFF0F0F0F);
  static const surfaceLight  = Color(0xFF1A1A1A);
  static const border        = Color(0xFF2A2A2A);

  // Brand
  static const primary       = Color(0xFFFFFFFF);
  static const accent        = Color(0xFF6C63FF); // Indigo glow
  static const accentGlow    = Color(0x336C63FF);

  // States
  static const listening     = Color(0xFFFF4444); // Red when recording
  static const thinking      = Color(0xFF6C63FF); // Purple when processing
  static const speaking      = Color(0xFF44FF88); // Green when speaking
  static const idle          = Color(0xFFFFFFFF); // White when idle

  // Text
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const textHint      = Color(0xFF555555);

  // App accent colors
  static const blinkit       = Color(0xFFFFCC00);
  static const swiggy        = Color(0xFFFC8019);
  static const zomato        = Color(0xFFE23744);
  static const whatsapp      = Color(0xFF25D366);
  static const maps          = Color(0xFF4285F4);
  static const youtube       = Color(0xFFFF0000);
  static const amazon        = Color(0xFFFF9900);
  static const phonePe       = Color(0xFF5F259F);
}

class VaniStrings {
  static const appName       = 'VANI';
  static const tagline       = 'Your phone. Your voice. Your AI.';
  static const wakeWord      = 'Hey VANI';
  static const holdToSpeak   = 'Hold to speak';
  static const listening     = 'Listening...';
  static const thinking      = 'Samajh raha hoon...';
  static const speaking      = 'Bol raha hoon...';
  static const modelLoading  = 'AI load ho rahi hai...';
  static const modelReady    = 'VANI ready hai';
  static const errorRetry    = 'Dobara bolein?';
  static const connectedApps = 'Connected Apps';
  static const comingSoon    = 'Jaldi Aayega';
}

class VaniPackages {
  static const blinkit   = 'com.blinkit.consumer';
  static const swiggy    = 'in.swiggy.android';
  static const zomato    = 'com.application.zomato';
  static const whatsapp  = 'com.whatsapp';
  static const maps      = 'com.google.android.apps.maps';
  static const youtube   = 'com.google.android.youtube';
  static const amazon    = 'in.amazon.mShop.android.shopping';
  static const flipkart  = 'com.flipkart.android';
  static const phonePe   = 'com.phonepe.app';
  static const gpay      = 'com.google.android.apps.nbu.paisa.user';
}

class VaniDurations {
  static const splashDelay        = Duration(seconds: 2);
  static const speechStartDelay   = Duration(milliseconds: 800);
  static const appOpenDelay       = Duration(milliseconds: 600);
  static const accessibilityDelay = Duration(milliseconds: 1200);
  static const pulseAnimation     = Duration(milliseconds: 1200);
  static const fadeAnimation      = Duration(milliseconds: 300);
}
