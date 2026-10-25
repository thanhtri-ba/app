import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';
import '../widgets/common.dart';
import '../widgets/delete_flow.dart';

class _Job {
  final Uint8List bytes;
  final int maxSide;
  final int quality;
  const _Job(this.bytes, this.maxSide, this.quality);
}

/// Runs in a background isolate. Returns JPEG bytes, or null when the image cannot be decoded.
Uint8List? _compressJob(_Job j) {
  var im = img.decodeImage(j.bytes);
  if (im == null) return null;
  im = img.bakeOrientation(im);
  final longest = im.width > im.height ? im.width : im.height;
  if (longest > j.maxSide) {
    im = im.width >= im.height
        ? img.copyResize(im, width: j.maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(im, height: j.maxSide, interpolation: img.Interpolation.average);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: j.quality));
}

class _Preset {
  final int maxSide;
  final int quality;
  const _Preset(this.maxSide, this.quality);
}

const _presets = [_Preset(2560, 85), _Preset(1920, 75), _Preset(1280, 65)];

/// Re-encodes large photos at a smaller size and saves them as new copies.
/// Originals are only removed (to Recently Deleted) if the user confirms afterwards.
class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  int _q = 1; // 0 light, 1 balanced, 2 strong
  final Set<String> _sel = <String>{};
  bool _running = false;
  int _done = 0;
  int _total = 0;
  int _fail = 0;

  List<AssetEntity> _candidates(LibraryProvider lib) {
    final photos = lib.assets.where((a) => a.type == AssetType.image && !lib.screenshots.any((s) => s.id == a.id));
    final list = photos.take(3000).toList();
    list.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return list.take(60).toList();
  }

  Future<void> _run(List<AssetEntity> chosen) async {
    final lib = context.read<LibraryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final tr = context.trr;
    final preset = _presets[_q];
    setState(() {
      _running = true;
      _done = 0;
      _fail = 0;
      _total = chosen.length;
    });

    final doneAssets = <AssetEntity>[];
    var oldTotal = 0;
    var newTotal = 0;
    for (final a in chosen) {
      try {
        File? f = await a.originFile;
        Uint8List? out;
        var oldLen = 0;
        if (f != null) {
          final src = await f.readAsBytes();
          oldLen = src.length;
          out = await compute(_compressJob, _Job(src, preset.maxSide, preset.quality));
        }
        if (out == null) {
          // Formats the Dart decoder cannot read (e.g. HEIC): try the converted file.
          f = await a.file;
          if (f != null) {
            final src = await f.readAsBytes();
            oldLen = oldLen == 0 ? src.length : oldLen;
            out = await compute(_compressJob, _Job(src, preset.maxSide, preset.quality));
          }
        }
        // Only keep results that are really smaller.
        if (out == null || oldLen == 0 || out.length >= oldLen * 0.9) {
          _fail++;
        } else {
          final title = await a.titleAsync;
          final base = title.contains('.') ? title.substring(0, title.lastIndexOf('.')) : title;
          final saved = await PhotoManager.editor
              .saveImage(out, filename: '${base.isEmpty ? 'IMG' : base}_c.jpg', title: '${base}_c');
          if (saved != null) {
            doneAssets.add(a);
            oldTotal += oldLen;
            newTotal += out.length;
          } else {
            _fail++;
          }
        }
      } catch (e) {
        debugPrint('compress failed: $e');
        _fail++;
      }
      if (!mounted) return;
      setState(() => _done++);
    }

    if (!mounted) return;
    setState(() => _running = false);
    if (doneAssets.isEmpty) {
      messenger.showSnackBar(SnackBar(
          content: Text(tr('Nothing could be made smaller.', 'Không có ảnh nào nén nhỏ hơn được.'))));
      return;
    }
    await lib.reload();
    if (!mounted) return;
    final saved = oldTotal - newTotal;
    final move = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('${doneAssets.length} compressed copies saved', 'Đã lưu ${doneAssets.length} bản nén')),
        content: Text(ctx.tr(
            'Each copy is smaller by ${fmtBytes(saved ~/ doneAssets.length)} on average (${fmtBytes(saved)} in total). Location data is removed from copies. Move the originals to Recently Deleted to actually free the space?',
            'Mỗi bản nhỏ hơn trung bình ${fmtBytes(saved ~/ doneAssets.length)} (tổng ${fmtBytes(saved)}). Dữ liệu vị trí không được giữ trong bản nén. Chuyển ảnh gốc vào Đã xoá gần đây để thật sự giải phóng dung lượng?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Keep originals', 'Giữ ảnh gốc'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('Move originals', 'Chuyển ảnh gốc'), style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (move == true && mounted) {
      await confirmAndDelete(context, assets: doneAssets, kind: 'compress', freedBytes: saved);
    }
    if (mounted) setState(_sel.clear);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lib = context.watch<LibraryProvider>();
    final items = _candidates(lib);
    final chosen = items.where((a) => _sel.contains(a.id)).toList();
    final labels = [
      context.tr('Light', 'Nhẹ'),
      context.tr('Balanced', 'Cân bằng'),
      context.tr('Strong', 'Mạnh'),
    ];
    final p = _presets[_q];

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Compress photos', 'Nén ảnh'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegControl(labels: labels, index: _q, onChanged: _running ? (_) {} : (i) => setState(() => _q = i)),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                      'Longest side ${p.maxSide}px, JPEG quality ${p.quality}. Biggest photos first. Saved as new copies; originals stay until you confirm.',
                      'Cạnh dài tối đa ${p.maxSide}px, chất lượng JPEG ${p.quality}. Ảnh lớn nhất trước. Lưu thành bản sao mới; ảnh gốc giữ lại đến khi bạn xác nhận.'),
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
                    child: LinearProgressIndicator(value: _total == 0 ? null : _done / _total, minHeight: 6),
                  ),
                  const SizedBox(height: 4),
                  Text(context.tr('Compressing $_done / $_total', 'Đang nén $_done / $_total'),
                      style: TextStyle(fontSize: 12, color: pal.sec)),
                ],
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text(context.tr('No photos found.', 'Không có ảnh.'), style: TextStyle(color: pal.sec)))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final a = items[i];
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
                              Positioned(
                                  left: 5,
                                  bottom: 5,
                                  child: Tag('${(a.width * a.height / 1e6).toStringAsFixed(1)} MP')),
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
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: PillButton(
            label: chosen.isEmpty
                ? context.tr('Tap photos to select', 'Chạm ảnh để chọn')
                : context.tr('Compress ${chosen.length} photos', 'Nén ${chosen.length} ảnh'),
            onTap: chosen.isEmpty || _running ? null : () => _run(chosen),
          ),
        ),
      ),
    );
  }
}
