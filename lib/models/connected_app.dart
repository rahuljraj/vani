// lib/models/connected_app.dart

import 'package:flutter/material.dart';
import '../core/constants.dart';

class ConnectedApp {
  final String  id;
  final String  name;
  final String  emoji;
  final String  description;
  final String  packageName;
  final Color   color;
  bool isEnabled;
  bool isInstalled;
  bool isComingSoon;
  DateTime? lastUsed;
  int queryCount;

  ConnectedApp({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.packageName,
    required this.color,
    this.isEnabled    = false,
    this.isInstalled  = false,
    this.isComingSoon = false,
    this.lastUsed,
    this.queryCount   = 0,
  });

  // Default apps list
  static List<ConnectedApp> get defaults => [
    ConnectedApp(
      id:          'google_maps',
      name:        'Google Maps',
      emoji:       '🗺️',
      description: 'Navigate anywhere by voice',
      packageName: VaniPackages.maps,
      color:       VaniColors.maps,
      isEnabled:   true,
    ),
    ConnectedApp(
      id:          'blinkit',
      name:        'Blinkit',
      emoji:       '📦',
      description: 'Order groceries by voice',
      packageName: VaniPackages.blinkit,
      color:       VaniColors.blinkit,
      isEnabled:   true,
    ),
    ConnectedApp(
      id:          'swiggy',
      name:        'Swiggy',
      emoji:       '🛵',
      description: 'Order food by voice',
      packageName: VaniPackages.swiggy,
      color:       VaniColors.swiggy,
      isEnabled:   false,
    ),
    ConnectedApp(
      id:          'zomato',
      name:        'Zomato',
      emoji:       '🍽️',
      description: 'Order food by voice',
      packageName: VaniPackages.zomato,
      color:       VaniColors.zomato,
      isEnabled:   false,
    ),
    ConnectedApp(
      id:          'whatsapp',
      name:        'WhatsApp',
      emoji:       '💬',
      description: 'Read & reply to messages',
      packageName: VaniPackages.whatsapp,
      color:       VaniColors.whatsapp,
      isEnabled:   false,
    ),
    ConnectedApp(
      id:          'youtube',
      name:        'YouTube',
      emoji:       '▶️',
      description: 'Search & play videos',
      packageName: VaniPackages.youtube,
      color:       VaniColors.youtube,
      isEnabled:   false,
    ),
    ConnectedApp(
      id:          'amazon',
      name:        'Amazon',
      emoji:       '🛍️',
      description: 'Search & shop',
      packageName: VaniPackages.amazon,
      color:       VaniColors.amazon,
      isEnabled:   false,
    ),
    ConnectedApp(
      id:          'phonePe',
      name:        'PhonePe',
      emoji:       '💰',
      description: 'Check balance (view only)',
      packageName: VaniPackages.phonePe,
      color:       VaniColors.phonePe,
      isEnabled:   false,
      isComingSoon: true,
    ),
  ];
}
