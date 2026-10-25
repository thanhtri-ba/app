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

/// Bottom space that scrollable content must leave free for the floating tab bar.
const double kTabBarSpace = 112;

/// Resolved palette for the current brightness.
/// Values mirror the CSS variables of the design prototype (Main.dc.html).
class Pal {
  final bool dark;
  const Pal(this.dark);

  Color get bg => dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  Color get card => dark ? const Color(0x12FFFFFF) : const Color(0x0A000000); // 7% / 4%
  Color get line => dark ? const Color(0x21FFFFFF) : const Color(0x1A000000); // 13% / 10%
  Color get text => dark ? const Color(0xFFF5F5F7) : const Color(0xFF111114);
  Color get sec => dark ? const Color(0xFFA0A0AA) : const Color(0xFF6A6A72);
  Color get accentText => dark ? const Color(0xFF5EB0FF) : const Color(0xFF0062C4);
  Color get ok => dark ? AppColors.okDark : AppColors.ok;
  Color get dangerText => dark ? AppColors.dangerDark : const Color(0xFFC4001A);
  Color get bar => dark ? const Color(0xC71C1C1E) : const Color(0xCCF6F6F8); // 78% / 80%
  Color get sheet => dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get segOn => dark ? const Color(0xFF3A3A3C) : const Color(0xFFFFFFFF);
  Color get pill => dark ? const Color(0x335EB0FF) : const Color(0x210071E3); // 20% / 13%
  Color get scrim => dark ? const Color(0x99000000) : const Color(0x59000000);
  Color get chip => dark ? const Color(0xFF2C2C2E) : const Color(0xFFE9ECF2);
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
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: Typography.material2021(platform: TargetPlatform.iOS).black.apply(
          bodyColor: pal.text,
          displayColor: pal.text,
        ),
  );
}

/// Large page title used by every tab (34 / 700 / -0.4 in the prototype).
class PageTitle extends StatelessWidget {
  final String text;
  const PageTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 34,
        height: 40 / 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: context.pal.text,
      ),
    );
  }
}

/// Soft blurred colour blobs behind the content (the prototype's `.glow`).
class GlowBackground extends StatelessWidget {
  final Widget child;
  const GlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final op = pal.dark ? 0.35 : 0.16;
    Widget blob(Color c, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [c.withOpacity(op), c.withOpacity(0)],
            ),
          ),
        );
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: pal.bg)),
        Positioned(left: -140, top: -120, child: IgnorePointer(child: blob(const Color(0xFF2F8BFF), 440))),
        Positioned(right: -170, top: 220, child: IgnorePointer(child: blob(const Color(0xFF8A5CFF), 420))),
        Positioned.fill(child: child),
      ],
    );
  }
}
