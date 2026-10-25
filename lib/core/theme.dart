import 'package:flutter/material.dart';

class AppColors {
  static const accent = Color(0xFF0071E3);
  static const accentDeep = Color(0xFF0057C2);
  static const ok = Color(0xFF1A7F37);
  static const okDark = Color(0xFF4CD964);
  static const danger = Color(0xFFD70015);
  static const dangerDark = Color(0xFFFF7A85);
  static const star = Color(0xFFFFC400);
}

/// Resolved palette for the current brightness.
class Pal {
  final bool dark;
  const Pal(this.dark);

  Color get bg => dark ? const Color(0xFF000000) : const Color(0xFFF2F5FB);
  Color get card => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get line => dark ? const Color(0x22FFFFFF) : const Color(0x14000000);
  Color get text => dark ? const Color(0xFFF5F5F7) : const Color(0xFF111114);
  Color get sec => dark ? const Color(0xFFA0A0AA) : const Color(0xFF6B6B76);
  Color get accentText => dark ? const Color(0xFF5EB0FF) : AppColors.accentDeep;
  Color get ok => dark ? AppColors.okDark : AppColors.ok;
  Color get dangerText => dark ? AppColors.dangerDark : AppColors.danger;
  Color get chip => dark ? const Color(0xFF2C2C2E) : const Color(0xFFE6EBF5);
}

extension PalX on BuildContext {
  Pal get pal => Pal(Theme.of(this).brightness == Brightness.dark);
}

ThemeData buildTheme(Brightness b) {
  final pal = Pal(b == Brightness.dark);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: b),
    scaffoldBackgroundColor: pal.bg,
  );
}
