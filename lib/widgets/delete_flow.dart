import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/activity_provider.dart';
import '../providers/library_provider.dart';
import '../providers/meta_provider.dart';
import '../providers/scan_provider.dart';
import '../providers/settings_provider.dart';
import 'celebration.dart';

/// Asks for confirmation, then moves the assets to the system trash.
/// Returns the number of photos actually deleted.
Future<int> confirmAndDelete(
  BuildContext context, {
  required List<AssetEntity> assets,
  required String kind,
  int? freedBytes,
}) async {
  if (assets.isEmpty) return 0;
  final lib = context.read<LibraryProvider>();
  final scan = context.read<ScanProvider>();
  final meta = context.read<MetaProvider>();
  final act = context.read<ActivityProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final vi = context.read<SettingsProvider>().isVi;

  final bytes = freedBytes ?? await lib.estimateBytesAll(assets);
  if (!context.mounted) return 0;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('Move ${assets.length} items to Recently Deleted?',
          'Chuyển ${assets.length} mục vào Đã xoá gần đây?')),
      content: Text(ctx.tr(
          'About ${fmtBytes(bytes)} will be freed. You can restore them from your Photos app for 30 days.',
          'Giải phóng khoảng ${fmtBytes(bytes)}. Bạn có thể khôi phục trong ứng dụng Ảnh trong 30 ngày.')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Cancel', 'Huỷ'))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.tr('Move', 'Chuyển'), style: const TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  if (ok != true) return 0;

  final deleted = await lib.deleteAssets(assets);
  if (deleted.isEmpty) return 0;
  scan.removeIds(deleted);
  meta.remove(deleted);
  final freed = deleted.length == assets.length
      ? bytes
      : (bytes * deleted.length / assets.length).round();
  final unlocked = await act.add(kind, deleted.length, freed);
  if (context.mounted) {
    await showCelebration(context,
        count: deleted.length, bytes: freed, newBadges: unlocked);
  } else {
    messenger.showSnackBar(SnackBar(
      content: Text(vi
          ? 'Đã chuyển ${deleted.length} mục · ${fmtBytes(freed)}'
          : 'Moved ${deleted.length} items · ${fmtBytes(freed)}'),
    ));
  }
  return deleted.length;
}
