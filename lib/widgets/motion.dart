import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool _reduceMotion(BuildContext c) => MediaQuery.of(c).disableAnimations;

/// Fades and slides a child in once. Use [index] to stagger siblings.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final double dy;
  final Duration duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.dy = 18,
    this.duration = const Duration(milliseconds: 520),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 55 * math.min(widget.index, 10));
    _t = Timer(delay, () {
      if (!mounted) return;
      if (_reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _a.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - _a.value) * widget.dy), child: child),
      ),
    );
  }
}

/// Wraps a tappable child with a springy press-scale and optional haptic tick.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
    this.haptic = false,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: () {
        if (widget.haptic) HapticFeedback.selectionClick();
        widget.onTap!();
      },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Animates a number from its previous value to [value].
class CountUp extends StatelessWidget {
  final num value;
  final String Function(num v) format;
  final TextStyle? style;
  final Duration duration;

  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: _reduceMotion(context) ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(format(v), style: style, maxLines: 1),
    );
  }
}

/// Soft breathing glow used for "waiting" states.
class Pulse extends StatefulWidget {
  final Widget child;
  const Pulse({super.key, required this.child});

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(scale: 1 + 0.06 * t, child: Opacity(opacity: 0.78 + 0.22 * t, child: child));
      },
    );
  }
}

/// Cross-fades + slides a whole tab page; inactive pages stop ticking and taking touches.
class TabPage extends StatelessWidget {
  final bool active;
  final Widget child;
  const TabPage({super.key, required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    // TickerMode must sit INSIDE the animated wrappers: if it wrapped them, their own
    // fade-out ticker would be muted too and the old tab would never disappear.
    return IgnorePointer(
      ignoring: !active,
      child: AnimatedOpacity(
        opacity: active ? 1 : 0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: active ? Offset.zero : const Offset(0, 0.018),
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
          child: TickerMode(enabled: active, child: child),
        ),
      ),
    );
  }
}

/// Page route with a gentle fade + rise, used for tool screens.
Route<T> softRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) {
      final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(c),
          child: child,
        ),
      );
    },
  );
}

/// Wraps each item in a staggered [FadeSlideIn]. Change [tag] to replay the entrance.
List<Widget> stagger(List<Widget> items, {Object tag = 'p', int start = 0}) {
  return [
    for (var i = 0; i < items.length; i++)
      FadeSlideIn(key: ValueKey('$tag-$i'), index: start + i, child: items[i]),
  ];
}
