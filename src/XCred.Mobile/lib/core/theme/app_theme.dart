import 'package:flutter/material.dart';

/// Dark violet theme matching docs/artifacts/flutter-mobile-mockup.html — kept minimal
/// here (seed-based ColorScheme) rather than porting every mockup token; screens can
/// pull specific accent shades from [violet] directly where the mockup's semantic
/// tokens (warning/danger/success) matter.
const Color violet = Color(0xFF7C3AED);

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: violet,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFF13111C),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
    ),
    appBarTheme: const AppBarTheme(centerTitle: false),
  );
}
