import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:light_compressor_v2/light_compressor_v2.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';
import '../providers/scan_provider.dart';
import '../scanner/video_view.dart';
import '../widgets/common.dart';
import '../widgets/delete_flow.dart';

/// Lists the biggest videos (real file sizes), lets the user preview them and re-encodes the
/// selected ones at a lower bitrate. Results are saved as NEW videos; originals are only moved
/// to Recently Deleted after an explicit confirmation.
class VideoCompressScreen extends StatefulWidget {
  const VideoCompressScreen({super.key});

  @override
  State<VideoCompressScreen> createState() => _VideoCompressScreenState();
}

class _VideoCompressScreenState extends State<VideoCompressScreen> {
  static const _qualities = [VideoQuality.high, VideoQuality.medium, VideoQuality.low];
  static const _minBytes = [0, 100 << 20, 500 << 20];

  int _q = 1; // 0 light, 1 balanced, 2 strong
  int _filter = 0;
  int _sort = 0;
  final Set<String> _sel = <String>{};

  bool _running = false;
  bool _cancel = false;
  int _index = 0;
  int _total = 0;
  int _fail = 0;
  double _p = 0; // 0..1 for the current video
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scan = context.read<ScanProvider>();
      if (scan.large == null) scan.loadLarge(context.read<LibraryProvider>());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<LargeItem> _view(ScanProvider scan) => viewVideos<LargeItem>(
        scan.large ?? const <LargeItem>[],
        bytes: (e) => e.bytes,
        seconds: (e) => e.asset.duration,
        date: (e) => e.asset.createDateTime,
        minBytes: _minBytes[_filter],
        sort: VideoSort.values[_sort],
      );

  Future<void> _run(List<LargeItem> chosen) async {
    final lib = context.read<LibraryProvider>();
    final scan = context.read<ScanProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final tr = context.trr;
    final lc = LightCompressor();
    setState(() {
      _running = true;
      _cancel = false;
      _index = 0;
      _fail = 0;
      _p = 0;
      _total = chosen.length;
    });
    _sub = lc.onProgressUpdated.listen((v) {
      if (mounted) setState(() => _p = (v / 100).clamp(0.0, 1.0));
    });

    final doneAssets = <AssetEntity>[];
    var oldTotal = 0;
    var newTotal = 0;
    for (var i = 0; i < chosen.length && !_cancel; i++) {
      final a = chosen[i].asset;
      if (mounted) {
        setState(() {
          _index = i + 1;
          _p = 0;
        });
      }
      File? out;
      try {
        final File? src = await a.originFile;
        if (src == null) {
          _fail++;
          continue;
        }
        final title = await a.titleAsync;
        final base = title.contains('.') ? title.substring(0, title.lastIndexOf('.')) : title;
        final name = '${base.isEmpty ? 'VID' : base}_c';
        // Output goes to an app-private folder; we import it into the gallery ourselves so
        // there is exactly one new asset and we control its title.
        final Result r = await lc.compressVideo(
          path: src.path,
          videoQuality: _qualities[_q],
          video: Video(videoName: '$name.mp4'),
          android: AndroidConfig(isSharedStorage: false),
          ios: IOSConfig(saveInGallery: false),
        );
        if (r is OnCancelled) break;
        if (r is! OnSuccess) {
          debugPrint('video compress failed: ${r is OnFailure ? r.message : r}');
          _fail++;
          continue;
        }
        out = File(r.destinationPath);
        if (!worthKeeping(r.originalSize, r.compressedSize)) {
          _fail++;
          continue;
        }
        final saved = await PhotoManager.editor.saveVideo(out, title: '$name.mp4');
        if (saved == null) {
          _fail++;
          continue;
        }
        doneAssets.add(a);
        oldTotal += r.originalSize;
        newTotal += r.compressedSize;
      } catch (e) {
        debugPrint('video compress error: $e');
        _fail++;
      } finally {
        // Only ever delete OUR temp output, never the source.
        try {
          if (out != null && await out.exists()) await out.delete();
        } catch (_) {}
      }
    }

    await _sub?.cancel();
    _sub = null;
    if (!mounted) return;
    final cancelled = _cancel;
    setState(() {
      _running = false;
      _cancel = false;
    });

    if (doneAssets.isEmpty) {
      messenger.showSnackBar(SnackBar(
          content: Text(cancelled
              ? tr('Cancelled.', 'Đã huỷ.')
              : tr('Nothing could be made smaller.', 'Không có video nào nén nhỏ hơn được.'))));
      return;
    }
    await lib.reload();
    if (!mounted) return;
    final saved = oldTotal - newTotal;
    final move = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('${doneAssets.length} compressed videos saved',
            'Đã lưu ${doneAssets.length} video nén')),
        content: Text(ctx.tr(
            'Together they are ${fmtBytes(saved)} smaller${_fail > 0 ? ' ($_fail skipped)' : ''}. Copies get today\'s date and lose location data. Check them in your gallery, then move the originals to Recently Deleted to actually free the space?',
            'Tổng cộng nhẹ hơn ${fmtBytes(saved)}${_fail > 0 ? ' (bỏ qua $_fail)' : ''}. Bản nén mang ngày hôm nay và không giữ vị trí. Hãy xem thử trong thư viện, rồi chuyển video gốc vào Đã xoá gần đây để thật sự giải phóng dung lượng?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('Keep originals', 'Giữ video gốc'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('Move originals', 'Chuyển video gốc'),
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (move == true && mounted) {
      await confirmAndDelete(context, assets: doneAssets, kind: 'videocompress', freedBytes: saved);
    }
    if (mounted) {
      setState(_sel.clear);
      // Refresh sizes: new copies exist / originals may be gone.
      scan.large = null;
      scan.loadLarge(lib);
    }
  }

  Future<void> _stop() async {
    setState(() => _cancel = true);
    try {
      await LightCompressor().cancelCompression();
    } catch (e) {
      debugPrint('cancel failed: $e');
    }
  }

  void _preview(LargeItem it) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PreviewSheet(item: it),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final scan = context.watch<ScanProvider>();
    final items = _view(scan);
    final chosen = items.where((e) => _sel.contains(e.asset.id)).toList();
    final loading = scan.loadingLarge || scan.large == null;
    final totalSel = chosen.fold<int>(0, (s, e) => s + e.bytes);

    return PopScope(
      canPop: !_running,
      child: Scaffold(
        appBar: AppBar(title: Text(context.tr('Compress videos', 'Nén video'))),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegControl(
                    labels: [
                      context.tr('Light', 'Nhẹ'),
                      context.tr('Balanced', 'Cân bằng'),
                      context.tr('Strong', 'Mạnh'),
                    ],
                    index: _q,
                    onChanged: _running ? (_) {} : (i) => setState(() => _q = i),
                  ),
                  const SizedBox(height: 8),
                  SegControl(
                    labels: [
                      context.tr('All', 'Tất cả'),
                      '≥ 100 MB',
                      '≥ 500 MB',
                    ],
                    index: _filter,
                    onChanged: _running ? (_) {} : (i) => setState(() => _filter = i),
                  ),
                  const SizedBox(height: 8),
                  SegControl(
                    labels: [
                      context.tr('Size', 'Dung lượng'),
                      context.tr('Length', 'Độ dài'),
                      context.tr('Newest', 'Mới nhất'),
                    ],
                    index: _sort,
                    onChanged: _running ? (_) {} : (i) => setState(() => _sort = i),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                        'Saved as new videos; originals stay until you confirm. Needs free space about the size of the largest selected video. Keep the app open while compressing.',
                        'Lưu thành video mới; bản gốc giữ lại đến khi bạn xác nhận. Cần dung lượng trống bằng khoảng video lớn nhất đã chọn. Giữ ứng dụng mở khi đang nén.'),
                    style: TextStyle(fontSize: 12, height: 17 / 12, color: pal.sec),
                  ),
                ],
              ),
            ),
            if (_running)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: _p <= 0 ? null : _p, minHeight: 6),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _cancel
                          ? context.tr('Cancelling…', 'Đang huỷ…')
                          : context.tr('Video $_index / $_total · ${(_p * 100).round()}%',
                              'Video $_index / $_total · ${(_p * 100).round()}%'),
                      style: TextStyle(fontSize: 12, color: pal.sec),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? Center(
                          child: Text(
                            context.tr('No videos match.', 'Không có video phù hợp.'),
                            style: TextStyle(color: pal.sec),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                          itemCount: items.length,
                          itemBuilder: (context, i) => _tile(items[i]),
                        ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: _running
                ? PillButton(label: context.tr('Cancel', 'Huỷ'), onTap: _cancel ? null : _stop)
                : PillButton(
                    label: chosen.isEmpty
                        ? context.tr('Tap videos to select', 'Chạm video để chọn')
                        : context.tr(
                            'Compress ${chosen.length} videos · ${fmtBytes(totalSel)}',
                            'Nén ${chosen.length} video · ${fmtBytes(totalSel)}'),
                    onTap: chosen.isEmpty ? null : () => _run(chosen),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _tile(LargeItem it) {
    final a = it.asset;
    final on = _sel.contains(a.id);
    return GestureDetector(
      onTap: _running
          ? null
          : () => setState(() {
                if (!_sel.remove(a.id)) _sel.add(a.id);
              }),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: on ? 0.55 : 1, child: PhotoThumb(asset: a, size: 300)),
            Positioned(left: 5, bottom: 5, child: Tag(fmtBytes(it.bytes))),
            Positioned(right: 5, bottom: 5, child: Tag(fmtDuration(a.duration))),
            Positioned(
              left: 5,
              top: 5,
              child: GestureDetector(
                onTap: _running ? null : () => _preview(it),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: on ? AppColors.accent : Colors.black38,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: on ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSheet extends StatefulWidget {
  final LargeItem item;
  const _PreviewSheet({required this.item});

  @override
  State<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<_PreviewSheet> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await widget.item.asset.originFile;
      if (f == null) throw StateError('no file');
      final c = VideoPlayerController.file(f);
      await c.initialize();
      await c.setLooping(true);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _c = c);
      await c.play();
    } catch (e) {
      debugPrint('preview failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = _c;
    final a = widget.item.asset;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
              child: AspectRatio(
                aspectRatio: c != null && c.value.isInitialized ? c.value.aspectRatio : 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _failed
                      ? Center(
                          child: Text(context.tr('Cannot play this video.', 'Không phát được video này.'),
                              style: TextStyle(color: pal.sec)))
                      : c == null
                          ? const Center(child: CircularProgressIndicator())
                          : GestureDetector(
                              onTap: () => setState(() {
                                c.value.isPlaying ? c.pause() : c.play();
                              }),
                              child: VideoPlayer(c),
                            ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${fmtBytes(widget.item.bytes)} · ${fmtDuration(a.duration)} · ${a.width}×${a.height}',
              style: TextStyle(fontSize: 13, color: pal.sec),
            ),
          ],
        ),
      ),
    );
  }
}
