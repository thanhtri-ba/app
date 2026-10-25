import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';
import '../providers/scan_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'cleanup_screen.dart';
import 'library_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'storage_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.scanRequests.addListener(_onScanRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<LibraryProvider>().init();
      if (!mounted) return;
      _applyNotifications();
      // App was launched from the notification's "Quick scan" action.
      if (NotificationService.instance.scanRequests.value > 0) _onScanRequest();
    });
  }

  @override
  void dispose() {
    NotificationService.instance.scanRequests.removeListener(_onScanRequest);
    super.dispose();
  }

  void _onScanRequest() {
    if (!mounted) return;
    final lib = context.read<LibraryProvider>();
    if (lib.state != LibState.ready) return;
    setState(() => _tab = 0);
    context.read<ScanProvider>().scan(lib, context.read<SettingsProvider>());
  }

  /// Re-applies reminder + status-bar settings (called at start and when they change).
  void _applyNotifications() {
    final st = context.read<SettingsProvider>();
    final svc = NotificationService.instance;
    svc.setReminder(
      st.remind,
      title: st.isVi ? 'Đến lúc dọn ảnh' : 'Time for a photo cleanup',
      body: st.isVi
          ? 'Mở Photo Cleaner để tìm ảnh trùng và ảnh mờ.'
          : 'Open Photo Cleaner to find duplicates and blurry shots.',
    );
    if (!st.statusBar) svc.hideStatus();
  }

  void goTab(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final pal = context.pal;

    if (lib.state == LibState.denied) return const _PermissionScreen();
    if (lib.state == LibState.unknown ||
        (lib.state == LibState.loading && lib.assets.isEmpty)) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(context.tr('Loading your library...', 'Đang tải thư viện...'),
                  style: TextStyle(color: pal.sec)),
              if (lib.total > 0) ...[
                const SizedBox(height: 6),
                Text('${lib.loaded} / ${lib.total}', style: TextStyle(color: pal.sec)),
              ],
            ],
          ),
        ),
      );
    }

    final pages = <Widget>[
      ReviewScreen(onOpenCleanup: () => goTab(1)),
      CleanupScreen(onOpenReview: () => goTab(0)),
      const LibraryScreen(),
      const StorageScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: pal.bg,
      extendBody: true,
      body: Stack(
        children: [
          GlowBackground(
            child: Stack(
              children: [
                for (var i = 0; i < pages.length; i++)
                  Positioned.fill(child: TabPage(active: i == _tab, child: pages[i])),
              ],
            ),
          ),
          const _StatusUpdater(),
          Positioned(
            left: 16,
            right: 16,
            bottom: 22,
            child: _FloatingTabBar(index: _tab, onTap: goTab),
          ),
        ],
      ),
    );
  }
}

/// Floating glass pill tab bar (68px high, 34px radius) with a sliding highlight.
class _FloatingTabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _FloatingTabBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    // (inactive icon, label, active icon)
    final items = <(IconData, String, IconData)>[
      (Icons.view_carousel_outlined, context.tr('Review', 'Duyệt'), Icons.view_carousel_rounded),
      (Icons.auto_awesome_outlined, context.tr('Cleanup', 'Dọn dẹp'), Icons.auto_awesome),
      (Icons.photo_outlined, context.tr('Library', 'Thư viện'), Icons.photo_rounded),
      (Icons.pie_chart_outline_rounded, context.tr('Storage', 'Dung lượng'), Icons.pie_chart_rounded),
      (Icons.settings_outlined, context.tr('Settings', 'Cài đặt'), Icons.settings_rounded),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: 68,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: pal.bar,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: pal.line),
            boxShadow: const [
              BoxShadow(color: Color(0x2E000000), blurRadius: 30, offset: Offset(0, 10)),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth / items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    left: w * index,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: Container(
                      decoration: BoxDecoration(
                        color: pal.pill,
                        borderRadius: BorderRadius.circular(29),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: i == index,
                            label: items[i].$2,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onTap(i),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    scale: i == index ? 1.14 : 1,
                                    duration: const Duration(milliseconds: 320),
                                    curve: Curves.easeOutBack,
                                    child: Icon(i == index ? items[i].$3 : items[i].$1,
                                        size: 24, color: i == index ? pal.accentText : pal.sec),
                                  ),
                                  const SizedBox(height: 2),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 220),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: i == index ? FontWeight.w700 : FontWeight.w600,
                                      color: i == index ? pal.accentText : pal.sec,
                                    ),
                                    child: Text(items[i].$2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Keeps the always-visible status notification in sync with the latest scan.
class _StatusUpdater extends StatefulWidget {
  const _StatusUpdater();

  @override
  State<_StatusUpdater> createState() => _StatusUpdaterState();
}

class _StatusUpdaterState extends State<_StatusUpdater> {
  String _last = '';

  @override
  Widget build(BuildContext context) {
    final on = context.select<SettingsProvider, bool>((s) => s.statusBar);
    final vi = context.select<SettingsProvider, bool>((s) => s.isVi);
    final groups = context.select<ScanProvider, int>((s) => s.clusters.length);
    final blur = context.select<ScanProvider, int>((s) => s.blurry.length);
    final scanned = context.select<ScanProvider, bool>((s) => s.result != null);
    final freeable = context.select<ScanProvider, int>((s) {
      var sum = 0;
      for (final c in s.clusters) {
        for (var i = 0; i < c.items.length; i++) {
          if (i != c.best) sum += (c.items[i].width * c.items[i].height * 0.35).round();
        }
      }
      for (final b in s.blurry) {
        sum += (b.asset.width * b.asset.height * 0.35).round();
      }
      return sum;
    });

    final title = vi ? 'Photo Cleaner' : 'Photo Cleaner';
    final body = !scanned
        ? (vi ? 'Chưa quét. Chạm Quét nhanh để tìm ảnh thừa.' : 'Not scanned yet. Tap Quick scan to find clutter.')
        : (vi
            ? '$groups nhóm giống · $blur ảnh mờ · có thể giải phóng ~${fmtBytes(freeable)}'
            : '$groups similar groups · $blur blurry · ~${fmtBytes(freeable)} can be freed');
    final action = vi ? 'Quét nhanh' : 'Quick scan';
    final key = '$on|$title|$body';
    if (key != _last) {
      _last = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final svc = NotificationService.instance;
        if (on) {
          svc.showStatus(title: title, body: body, actionLabel: action);
        } else {
          svc.hideStatus();
        }
      });
    }
    return const SizedBox.shrink();
  }
}

class _PermissionScreen extends StatelessWidget {
  const _PermissionScreen();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lib = context.read<LibraryProvider>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(48),
                ),
                child: const Icon(Icons.photo_library_outlined, size: 46, color: AppColors.accent),
              ),
              const SizedBox(height: 24),
              Text(context.tr('Allow access to your photos', 'Cho phép truy cập ảnh'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: pal.text)),
              const SizedBox(height: 10),
              Text(
                context.tr(
                    'Photo Cleaner analyses your photos on this device. Nothing is uploaded, and nothing is deleted until you confirm.',
                    'Photo Cleaner phân tích ảnh ngay trên máy. Không có gì được tải lên, và không có gì bị xoá cho đến khi bạn xác nhận.'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.4, color: pal.sec),
              ),
              const SizedBox(height: 28),
              PillButton(label: context.tr('Allow access', 'Cho phép'), onTap: lib.init),
              const SizedBox(height: 10),
              PillButton(
                  label: context.tr('Open Settings', 'Mở Cài đặt'),
                  filled: false,
                  onTap: lib.openSettings),
            ],
          ),
        ),
      ),
    );
  }
}
