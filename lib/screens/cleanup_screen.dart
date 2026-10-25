import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/activity_provider.dart';
import '../providers/library_provider.dart';
import '../providers/scan_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common.dart';
import '../widgets/delete_flow.dart';
import 'cull_screen.dart';

class CleanupScreen extends StatelessWidget {
  final VoidCallback onOpenReview;
  const CleanupScreen({super.key, required this.onOpenReview});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final scan = context.watch<ScanProvider>();
    final lib = context.watch<LibraryProvider>();
    final act = context.watch<ActivityProvider>();
    final settings = context.watch<SettingsProvider>();

    final scanned = scan.result != null;
    final simGroups = scan.clusters.length;
    final blurN = scan.blurry.length;

    Widget tile({
      required IconData icon,
      required Color color,
      required String title,
      required String desc,
      required String status,
      required VoidCallback onTap,
    }) {
      return AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: pal.text)),
                  const SizedBox(height: 2),
                  Text(desc, style: TextStyle(fontSize: 13, height: 1.3, color: pal.sec)),
                  const SizedBox(height: 4),
                  Text(status,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: pal.accentText)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: pal.sec),
          ],
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Text(context.tr('Cleanup', 'Dọn dẹp'),
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: pal.text)),
          const SizedBox(height: 14),
          HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('Freed so far', 'Đã giải phóng'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xD9FFFFFF))),
                const SizedBox(height: 2),
                Text(fmtBytes(act.totalBytes),
                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1)),
                Text(context.tr('${act.totalCount} items moved to Recently Deleted',
                    '${act.totalCount} mục đã chuyển vào Đã xoá gần đây'),
                    style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          tile(
            icon: Icons.copy_all_rounded,
            color: AppColors.accent,
            title: context.tr('Similar & duplicates', 'Ảnh giống & trùng'),
            desc: context.tr('Groups of near-identical shots. Keep the best.',
                'Các nhóm ảnh gần giống nhau. Giữ tấm đẹp nhất.'),
            status: scanned
                ? context.tr('$simGroups groups', '$simGroups nhóm')
                : context.tr('Not scanned yet', 'Chưa quét'),
            onTap: onOpenReview,
          ),
          const SizedBox(height: 12),
          tile(
            icon: Icons.blur_on_rounded,
            color: const Color(0xFFBF5AF2),
            title: context.tr('Blurry photos', 'Ảnh mờ'),
            desc: context.tr('Soft or out-of-focus shots, sharpest-last.',
                'Ảnh mờ hoặc out nét, mờ nhất ở đầu.'),
            status: scanned
                ? context.tr('$blurN found', 'Tìm thấy $blurN')
                : context.tr('Not scanned yet', 'Chưa quét'),
            onTap: () {
              if (!scanned) {
                scan.scan(lib, settings);
              }
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const ToolScreen(kind: ToolKind.blurry)));
            },
          ),
          const SizedBox(height: 12),
          tile(
            icon: Icons.screenshot_rounded,
            color: const Color(0xFFFF8A3D),
            title: context.tr('Screenshots', 'Ảnh chụp màn hình'),
            desc: context.tr('Old screenshots you probably no longer need.',
                'Ảnh chụp màn hình cũ có thể không cần nữa.'),
            status: context.tr('${lib.screenshots.length} found', 'Tìm thấy ${lib.screenshots.length}'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const ToolScreen(kind: ToolKind.screenshots))),
          ),
          const SizedBox(height: 12),
          tile(
            icon: Icons.movie_rounded,
            color: const Color(0xFF30B067),
            title: context.tr('Large videos', 'Video dung lượng lớn'),
            desc: context.tr('Biggest videos first. Tap to keep one.',
                'Video lớn nhất ở đầu. Chạm để giữ lại.'),
            status: context.tr('${lib.videoCount} videos', '${lib.videoCount} video'),
            onTap: () {
              scan.loadLarge(lib);
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const ToolScreen(kind: ToolKind.large)));
            },
          ),
        ],
      ),
    );
  }
}

enum ToolKind { blurry, screenshots, large }

class ToolScreen extends StatefulWidget {
  final ToolKind kind;
  const ToolScreen({super.key, required this.kind});

  @override
  State<ToolScreen> createState() => _ToolScreenState();
}

class _ToolScreenState extends State<ToolScreen> {
  bool _busy = false;

  String _kindName() {
    switch (widget.kind) {
      case ToolKind.blurry:
        return 'blurry';
      case ToolKind.screenshots:
        return 'screenshots';
      case ToolKind.large:
        return 'large';
    }
  }

  @override
  void initState() {
    super.initState();
    // Start with a clean selection for this tool.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScanProvider>().toolMarked.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final scan = context.watch<ScanProvider>();
    final lib = context.watch<LibraryProvider>();

    late final List<AssetEntity> items;
    final extra = <String, String>{};
    var loading = false;
    String title;
    switch (widget.kind) {
      case ToolKind.blurry:
        title = context.tr('Blurry photos', 'Ảnh mờ');
        items = scan.blurry.map((b) => b.asset).toList();
        for (final b in scan.blurry) {
          extra[b.asset.id] = '◎ ${b.sharp.round()}';
        }
        loading = scan.scanning;
        break;
      case ToolKind.screenshots:
        title = context.tr('Screenshots', 'Ảnh chụp màn hình');
        items = lib.screenshots;
        break;
      case ToolKind.large:
        title = context.tr('Large videos', 'Video dung lượng lớn');
        final l = scan.large ?? const <LargeItem>[];
        items = l.map((x) => x.asset).toList();
        for (final x in l) {
          extra[x.asset.id] = fmtBytes(x.bytes);
        }
        loading = scan.loadingLarge || scan.large == null;
        break;
    }

    final sel = items.where((a) => scan.toolMarked.contains(a.id)).toList();
    final allOn = items.isNotEmpty && sel.length == items.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => scan.setTool(items.map((a) => a.id), !allOn),
              child: Text(allOn
                  ? context.tr('Deselect all', 'Bỏ chọn')
                  : context.tr('Select all', 'Chọn tất cả')),
            ),
        ],
      ),
      body: loading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(
                  child: Text(context.tr('Nothing found.', 'Không tìm thấy gì.'),
                      style: TextStyle(color: pal.sec)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final a = items[i];
                    final on = scan.toolMarked.contains(a.id);
                    return GestureDetector(
                      onTap: () => scan.toggleTool(a.id),
                      onLongPress: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => CullScreen(assets: items, initial: i))),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Opacity(opacity: on ? 0.55 : 1, child: PhotoThumb(asset: a, size: 300)),
                            if (extra[a.id] != null)
                              Positioned(left: 5, bottom: 5, child: Tag(extra[a.id]!)),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: on ? AppColors.danger : Colors.black38,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: on
                                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: PillButton(
            label: sel.isEmpty
                ? context.tr('Tap photos to mark them', 'Chạm ảnh để đánh dấu')
                : context.tr('Delete ${sel.length} items', 'Xoá ${sel.length} mục'),
            danger: sel.isNotEmpty,
            filled: sel.isNotEmpty,
            onTap: sel.isEmpty || _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await confirmAndDelete(context, assets: sel, kind: _kindName());
                    if (mounted) setState(() => _busy = false);
                  },
          ),
        ),
      ),
    );
  }
}
