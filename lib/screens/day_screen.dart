import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';
import '../providers/meta_provider.dart';
import '../widgets/common.dart';
import '../widgets/delete_flow.dart';
import 'cull_screen.dart';

class DayScreen extends StatefulWidget {
  final String dayKey;
  const DayScreen({super.key, required this.dayKey});

  @override
  State<DayScreen> createState() => _DayScreenState();
}

enum _Filter { all, pick, reject, r3, unrated }

class _DayScreenState extends State<DayScreen> {
  _Filter _filter = _Filter.all;
  bool _sel = false;
  final Set<String> _ids = <String>{};
  bool _busy = false;

  List<AssetEntity> _dayAssets(LibraryProvider lib) {
    final l = List<AssetEntity>.of(lib.byDay[widget.dayKey] ?? const <AssetEntity>[]);
    l.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
    return l;
  }

  List<AssetEntity> _filtered(List<AssetEntity> all, MetaProvider m) {
    switch (_filter) {
      case _Filter.all:
        return all;
      case _Filter.pick:
        return all.where((a) => m.flag(a.id) == 'pick').toList();
      case _Filter.reject:
        return all.where((a) => m.flag(a.id) == 'reject').toList();
      case _Filter.r3:
        return all.where((a) => m.rating(a.id) >= 3).toList();
      case _Filter.unrated:
        return all.where((a) => !m.reviewed(a.id)).toList();
    }
  }

  void _toggle(String id) {
    setState(() {
      if (!_ids.remove(id)) _ids.add(id);
    });
  }

  Future<void> _rateSheet(MetaProvider meta) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.tr('Rate ${_ids.length} photos', 'Chấm sao ${_ids.length} ảnh'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var n = 1; n <= 5; n++)
                    GestureDetector(
                      onTap: () {
                        meta.setRating(_ids, n);
                        Navigator.pop(ctx);
                      },
                      child: Column(
                        children: [
                          const Icon(Icons.star_rounded, size: 40, color: AppColors.star),
                          Text('$n'),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  meta.setRating(_ids, 0);
                  Navigator.pop(ctx);
                },
                child: Text(ctx.tr('Clear rating', 'Xoá đánh giá')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _labelSheet(MetaProvider meta) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.tr('Colour label', 'Nhãn màu'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final e in labelColors.entries)
                    GestureDetector(
                      onTap: () {
                        meta.setLabel(_ids, e.key);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: e.value, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  meta.setLabel(_ids, null);
                  Navigator.pop(ctx);
                },
                child: Text(ctx.tr('Remove label', 'Bỏ nhãn')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteRejected(List<AssetEntity> all, MetaProvider meta) async {
    if (_busy) return;
    final rej = all.where((a) => meta.flag(a.id) == 'reject').toList();
    setState(() => _busy = true);
    await confirmAndDelete(context, assets: rej, kind: 'rejected');
    if (mounted) setState(() => _busy = false);
  }

  Widget _chip(String label, _Filter f) {
    final pal = context.pal;
    final on = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = f),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.accent : pal.card,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: pal.line),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : pal.text)),
        ),
      ),
    );
  }

  Widget _stat(String v, String k, Color c) {
    final pal = context.pal;
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
            Text(k, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pal.sec)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lib = context.watch<LibraryProvider>();
    final meta = context.watch<MetaProvider>();
    final all = _dayAssets(lib);
    final shown = _filtered(all, meta);
    final ids = all.map((a) => a.id);
    final picks = meta.countFlag(ids, 'pick');
    final rejects = meta.countFlag(ids, 'reject');
    final reviewed = meta.countReviewed(ids);
    final date = parseDayKey(widget.dayKey);

    final hist = List<int>.filled(24, 0);
    for (final a in all) {
      hist[a.createDateTime.hour]++;
    }
    var hMax = 1;
    var peak = 0;
    for (var h = 0; h < 24; h++) {
      if (hist[h] > hMax) {
        hMax = hist[h];
        peak = h;
      }
    }
    final prog = all.isEmpty ? 0.0 : reviewed / all.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('${date.day}/${date.month}/${date.year}'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _sel = !_sel;
              _ids.clear();
            }),
            child: Text(_sel ? context.tr('Done', 'Xong') : context.tr('Select', 'Chọn')),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _stat(fmtCount(all.length), context.tr('Shots', 'Ảnh'), pal.text),
                      const SizedBox(width: 8),
                      _stat('$picks', context.tr('Picks', 'Chọn'), pal.ok),
                      const SizedBox(width: 8),
                      _stat('$rejects', context.tr('Rejects', 'Loại'), pal.dangerText),
                      const SizedBox(width: 8),
                      _stat(fmtCount(all.length - reviewed), context.tr('Unrated', 'Chưa chấm'), pal.sec),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(context.tr('Culling progress', 'Tiến độ chọn ảnh'),
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700, color: pal.text)),
                            Text('${(prog * 100).round()}%',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800, color: pal.accentText)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: prog, minHeight: 8),
                        ),
                        const SizedBox(height: 6),
                        Text(
                            context.tr('$reviewed / ${all.length} reviewed',
                                '$reviewed / ${all.length} đã duyệt'),
                            style: TextStyle(fontSize: 12, color: pal.sec)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(context.tr('Shots per hour', 'Ảnh theo giờ'),
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700, color: pal.text)),
                            Text(
                                context.tr('Peak ${peak.toString().padLeft(2, '0')}:00 · ${hist[peak]}',
                                    'Cao điểm ${peak.toString().padLeft(2, '0')}:00 · ${hist[peak]}'),
                                style: TextStyle(fontSize: 12, color: pal.sec)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 64,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var h = 0; h < 24; h++)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                    child: FractionallySizedBox(
                                      heightFactor: (hist[h] / hMax).clamp(0.05, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: h == peak
                                              ? AppColors.accent
                                              : AppColors.accent.withOpacity(0.45),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 14,
                        child: PillButton(
                          label: context.tr('Start culling', 'Bắt đầu chọn ảnh'),
                          icon: Icons.bolt_rounded,
                          onTap: shown.isEmpty
                              ? null
                              : () => Navigator.of(context).push(MaterialPageRoute<void>(
                                  builder: (_) => CullScreen(assets: shown, initial: 0))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 11,
                        child: PillButton(
                          label: rejects == 0
                              ? context.tr('No rejects', 'Chưa có ảnh loại')
                              : context.tr('Delete $rejects rejected', 'Xoá $rejects ảnh loại'),
                          filled: false,
                          onTap: rejects == 0 || _busy ? null : () => _deleteRejected(all, meta),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip(context.tr('All', 'Tất cả'), _Filter.all),
                        _chip(context.tr('Picks', 'Đã chọn'), _Filter.pick),
                        _chip(context.tr('Rejected', 'Loại'), _Filter.reject),
                        _chip('★ 3+', _Filter.r3),
                        _chip(context.tr('Unrated', 'Chưa chấm'), _Filter.unrated),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, _sel ? 110 : 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, mainAxisSpacing: 4, crossAxisSpacing: 4),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final a = shown[i];
                  final f = meta.flag(a.id);
                  final r = meta.rating(a.id);
                  final l = meta.label(a.id);
                  final on = _ids.contains(a.id);
                  return GestureDetector(
                    onTap: () {
                      if (_sel) {
                        _toggle(a.id);
                      } else {
                        Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => CullScreen(assets: shown, initial: i)));
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _sel && on ? AppColors.accent : Colors.transparent, width: 3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Opacity(opacity: f == 'reject' ? 0.4 : 1, child: PhotoThumb(asset: a, size: 240)),
                            if (f != null)
                              Positioned(
                                left: 3,
                                top: 3,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: f == 'pick' ? AppColors.ok : AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                      f == 'pick' ? Icons.check_rounded : Icons.close_rounded,
                                      size: 11,
                                      color: Colors.white),
                                ),
                              ),
                            if (l != null)
                              Positioned(
                                right: 3,
                                top: 3,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: labelColors[l],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                ),
                              ),
                            if (r > 0)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  color: Colors.black45,
                                  padding: const EdgeInsets.symmetric(vertical: 1),
                                  child: Text('★' * r,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: AppColors.star,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ),
                            if (a.type == AssetType.video)
                              Positioned(
                                  right: 3, bottom: 3, child: Tag('▶ ${fmtDuration(a.duration)}')),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: shown.length,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _sel
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                decoration: BoxDecoration(
                  color: pal.card,
                  border: Border(top: BorderSide(color: pal.line)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            context.tr('${_ids.length} selected', '${_ids.length} đã chọn'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        TextButton(
                          onPressed: () => setState(() {
                            if (_ids.length == shown.length) {
                              _ids.clear();
                            } else {
                              _ids.addAll(shown.map((a) => a.id));
                            }
                          }),
                          child: Text(_ids.length == shown.length
                              ? context.tr('Deselect', 'Bỏ chọn')
                              : context.tr('Select all ${shown.length}', 'Chọn tất cả ${shown.length}')),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _BarBtn(
                            icon: Icons.star_rounded,
                            label: context.tr('Rate', 'Chấm sao'),
                            enabled: _ids.isNotEmpty,
                            onTap: () => _rateSheet(meta)),
                        _BarBtn(
                            icon: Icons.label_outline_rounded,
                            label: context.tr('Label', 'Nhãn'),
                            enabled: _ids.isNotEmpty,
                            onTap: () => _labelSheet(meta)),
                        _BarBtn(
                            icon: Icons.check_rounded,
                            label: context.tr('Pick', 'Chọn'),
                            enabled: _ids.isNotEmpty,
                            onTap: () => meta.setFlag(_ids, 'pick')),
                        _BarBtn(
                            icon: Icons.close_rounded,
                            label: context.tr('Reject', 'Loại'),
                            enabled: _ids.isNotEmpty,
                            color: pal.dangerText,
                            onTap: () => meta.setFlag(_ids, 'reject')),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final Color? color;
  final VoidCallback onTap;
  const _BarBtn(
      {required this.icon,
      required this.label,
      required this.enabled,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              Icon(icon, size: 26, color: color ?? pal.text),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color ?? pal.text)),
            ],
          ),
        ),
      ),
    );
  }
}
