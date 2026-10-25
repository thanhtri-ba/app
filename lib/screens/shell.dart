import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';
import '../widgets/common.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().init();
    });
  }

  void goTab(int i) => setState(() => _tab = i);

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
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: goTab,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.grid_view_rounded), label: context.tr('Review', 'Duyệt')),
          NavigationDestination(
              icon: const Icon(Icons.auto_awesome), label: context.tr('Cleanup', 'Dọn dẹp')),
          NavigationDestination(
              icon: const Icon(Icons.photo_library_outlined), label: context.tr('Library', 'Thư viện')),
          NavigationDestination(
              icon: const Icon(Icons.pie_chart_outline), label: context.tr('Storage', 'Dung lượng')),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined), label: context.tr('Settings', 'Cài đặt')),
        ],
      ),
    );
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
