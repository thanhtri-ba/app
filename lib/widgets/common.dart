import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../core/theme.dart';
import '../services/thumb_cache.dart';
import 'motion.dart';

const Map<String, Color> labelColors = {
  'red': Color(0xFFFF453A),
  'yellow': Color(0xFFFFC400),
  'green': Color(0xFF30D158),
  'blue': Color(0xFF0A84FF),
  'purple': Color(0xFFBF5AF2),
};

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final EdgeInsets margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pal.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap, scale: 0.975, haptic: true, child: box);
  }
}

class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(22)});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F8BFF), Color(0xFF0057C2), Color(0xFF5B3FD6)],
          stops: [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x990057C2),
            blurRadius: 36,
            spreadRadius: -14,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: IgnorePointer(
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white), child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class SegControl extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const SegControl({super.key, required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? pal.segOn : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: i == index
                        ? const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: i == index ? pal.text : pal.sec,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool danger;
  final IconData? icon;

  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.danger = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final enabled = onTap != null;
    final fg = filled ? Colors.white : pal.accentText;
    final List<Color>? grad = !filled
        ? null
        : (danger
            ? const [Color(0xFFEE2A3D), Color(0xFFC4001A)]
            : const [Color(0xFF2A86F5), Color(0xFF0062CF)]);
    final shadow = !filled
        ? null
        : [
            BoxShadow(
              color: (danger ? const Color(0xA6D70015) : const Color(0xB30062CF)),
              blurRadius: 22,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ];
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: Pressable(
        onTap: onTap,
        scale: 0.98,
        haptic: true,
        child: Container(
          height: 52,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: filled ? null : pal.card,
            gradient: grad == null
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: grad),
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: pal.line),
            boxShadow: shadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square-ish thumbnail that fills its parent.
class PhotoThumb extends StatefulWidget {
  final AssetEntity asset;
  final int size;
  final BoxFit fit;

  const PhotoThumb({super.key, required this.asset, this.size = 300, this.fit = BoxFit.cover});

  @override
  State<PhotoThumb> createState() => _PhotoThumbState();
}

class _PhotoThumbState extends State<PhotoThumb> {
  Future<Uint8List?>? _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<Uint8List?> _load() => ThumbCache.load(widget.asset, widget.size);

  @override
  void didUpdateWidget(PhotoThumb old) {
    super.didUpdateWidget(old);
    if (old.asset.id != widget.asset.id || old.size != widget.size) _f = _load();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final cached = ThumbCache.peek(widget.asset, widget.size);
    if (cached != null) {
      return Image.memory(cached, fit: widget.fit, gaplessPlayback: true,
          width: double.infinity, height: double.infinity);
    }
    return FutureBuilder<Uint8List?>(
      future: _f,
      builder: (context, snap) {
        final d = snap.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: d == null
              ? Container(key: const ValueKey('ph'), color: pal.chip)
              : Image.memory(d,
                  key: const ValueKey('img'),
                  fit: widget.fit,
                  gaplessPlayback: true,
                  width: double.infinity,
                  height: double.infinity),
        );
      },
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, {super.key, this.color = const Color(0x8C000000)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}
