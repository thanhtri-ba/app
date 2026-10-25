import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/meta_provider.dart';
import '../services/thumb_cache.dart';
import '../widgets/common.dart';

/// Full-screen viewer with culling controls: rate, pick / reject, colour label.
class CullScreen extends StatefulWidget {
  final List<AssetEntity> assets;
  final int initial;
  const CullScreen({super.key, required this.assets, this.initial = 0});

  @override
  State<CullScreen> createState() => _CullScreenState();
}

class _CullScreenState extends State<CullScreen> {
  late final PageController _pc;
  late int _i;
  bool _auto = true;
  bool _info = false;

  @override
  void initState() {
    super.initState();
    _i = widget.initial.clamp(0, widget.assets.length - 1);
    _pc = PageController(initialPage: _i);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  AssetEntity get _cur => widget.assets[_i];

  void _advance() {
    if (_auto && _i < widget.assets.length - 1) {
      _pc.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  void _go(int d) {
    final t = _i + d;
    if (t < 0 || t >= widget.assets.length) return;
    _pc.animateToPage(t, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final meta = context.watch<MetaProvider>();
    final a = _cur;
    final flag = meta.flag(a.id);
    final rating = meta.rating(a.id);
    final label = meta.label(a.id);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('${_i + 1} / ${widget.assets.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(fmtDateTime(a.createDateTime),
                            style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _info = !_info),
                    icon: Icon(Icons.info_outline_rounded,
                        color: _info ? AppColors.accent : Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pc,
                    itemCount: widget.assets.length,
                    onPageChanged: (i) => setState(() => _i = i),
                    itemBuilder: (context, i) => _Page(asset: widget.assets[i]),
                  ),
                  Positioned(
                    left: 12,
                    top: 8,
                    child: Row(
                      children: [
                        if (flag != null)
                          Tag(
                            flag == 'pick'
                                ? context.tr('PICK', 'ĐÃ CHỌN')
                                : context.tr('REJECT', 'LOẠI'),
                            color: flag == 'pick' ? AppColors.ok : AppColors.danger,
                          ),
                        if (rating > 0) ...[
                          const SizedBox(width: 6),
                          Tag('★' * rating, color: const Color(0xAA000000)),
                        ],
                        if (label != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: labelColors[label],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_info)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${a.type == AssetType.video ? context.tr('Video', 'Video') : context.tr('Photo', 'Ảnh')}'
                          ' · ${a.width} × ${a.height}'
                          '${a.type == AssetType.video ? ' · ${fmtDuration(a.duration)}' : ''}'
                          '\n${fmtDateTime(a.createDateTime)}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var n = 1; n <= 5; n++)
                    IconButton(
                      onPressed: () {
                        final was = meta.rating(a.id) == n;
                        meta.setRating([a.id], was ? 0 : n);
                        if (!was) _advance();
                      },
                      icon: Icon(Icons.star_rounded,
                          size: 34, color: n <= rating ? AppColors.star : Colors.white38),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final e in labelColors.entries)
                  GestureDetector(
                    onTap: () => meta.toggleLabel(a.id, e.key),
                    child: Container(
                      width: 26,
                      height: 26,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: e.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: label == e.key ? Colors.white : Colors.transparent, width: 3),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _go(-1),
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 32),
                  ),
                  Expanded(
                    child: _Action(
                      color: AppColors.danger,
                      icon: Icons.close_rounded,
                      label: context.tr('Reject', 'Loại'),
                      active: flag == 'reject',
                      onTap: () {
                        final was = flag == 'reject';
                        meta.toggleFlag([a.id], 'reject');
                        if (!was) _advance();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Action(
                      color: AppColors.ok,
                      icon: Icons.check_rounded,
                      label: context.tr('Pick', 'Chọn'),
                      active: flag == 'pick',
                      onTap: () {
                        final was = flag == 'pick';
                        meta.toggleFlag([a.id], 'pick');
                        if (!was) _advance();
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () => _go(1),
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 32),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Switch(value: _auto, onChanged: (v) => setState(() => _auto = v)),
                  Text(context.tr('Auto-advance', 'Tự chuyển ảnh'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Action(
      {required this.color,
      required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: active ? color : color.withOpacity(0.22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatefulWidget {
  final AssetEntity asset;
  const _Page({required this.asset});

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  late Future<Uint8List?> _f;

  @override
  void initState() {
    super.initState();
    _f = ThumbCache.load(widget.asset, 1400);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _f,
      builder: (context, snap) {
        final d = snap.data;
        if (d == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(child: Image.memory(d, fit: BoxFit.contain, gaplessPlayback: true)),
        );
      },
    );
  }
}
