import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'account_screen.dart';
import 'vault_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.watch<SettingsProvider>();
    final lib = context.read<LibraryProvider>();
    final session = context.watch<SessionProvider>();
    final user = session.user;

    const limits = [1000, 3000, 10000, 1000000];
    final limitIdx = limits.contains(s.scanLimit) ? limits.indexOf(s.scanLimit) : 1;
    final isDark = s.themeMode == ThemeMode.dark ||
        (s.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    Widget divider() => Divider(height: 1, thickness: 1, color: pal.line);

    Widget block(String title, Widget child, {String? note}) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: pal.text)),
              const SizedBox(height: 10),
              child,
              if (note != null) ...[
                const SizedBox(height: 8),
                Text(note, style: TextStyle(fontSize: 12, color: pal.sec)),
              ],
            ],
          ),
        );

    Widget infoRow(String label, Widget trailing, {VoidCallback? onTap}) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: pal.text)),
                trailing,
              ],
            ),
          ),
        );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, kTabBarSpace),
        children: stagger([
          PageTitle(context.tr('Settings', 'Cài đặt')),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3A93FF), Color(0xFF7B4DD6)],
                        ),
                      ),
                      child: Text(user?.initials ?? '?',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? context.tr('Guest', 'Khách'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700, color: pal.text)),
                          Text(
                              user?.email ??
                                  context.tr('Sign in to use one account everywhere', 'Đăng nhập để dùng một tài khoản mọi nơi'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, color: pal.sec)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pal.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(context.tr('FREE', 'MIỄN PHÍ'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: pal.sec)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (user == null)
                  PillButton(
                      label: context.tr('Sign in', 'Đăng nhập'),
                      filled: false,
                      onTap: session.openAuth)
                else ...[
                  PillButton(
                      label: context.tr('Manage account', 'Quản lý tài khoản'),
                      filled: false,
                      onTap: () => Navigator.of(context).push(softRoute<void>(const AccountScreen()))),
                  const SizedBox(height: 10),
                  PillButton(
                      label: context.tr('Log out', 'Đăng xuất'),
                      filled: false,
                      onTap: session.signOut),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoRow(
                  context.tr('Dark mode', 'Chế độ tối'),
                  _IosSwitch(
                    value: isDark,
                    onChanged: (v) => s.setTheme(v ? ThemeMode.dark : ThemeMode.light),
                  ),
                ),
                divider(),
                block(
                  context.tr('Language', 'Ngôn ngữ'),
                  SegControl(
                    labels: const ['English', 'Tiếng Việt'],
                    index: s.isVi ? 1 : 0,
                    onChanged: (i) => s.setLang(i == 1 ? 'vi' : 'en'),
                  ),
                ),
                divider(),
                block(
                  context.tr('Photos to scan', 'Số ảnh cần quét'),
                  SegControl(
                    labels: ['1,000', '3,000', '10,000', context.tr('All', 'Tất cả')],
                    index: limitIdx,
                    onChanged: (i) => s.setScanLimit(limits[i]),
                  ),
                  note: context.tr(
                      'Newest photos first. The first big scan takes longer; later scans only analyse new photos.',
                      'Ảnh mới nhất trước. Lần quét lớn đầu tiên lâu hơn; các lần sau chỉ phân tích ảnh mới.'),
                ),
                divider(),
                block(
                  context.tr('Blur sensitivity', 'Độ nhạy ảnh mờ'),
                  SegControl(
                    labels: [
                      context.tr('Low', 'Thấp'),
                      context.tr('Medium', 'Vừa'),
                      context.tr('High', 'Cao'),
                    ],
                    index: s.blurLevel,
                    onChanged: s.setBlurLevel,
                  ),
                ),
                divider(),
                block(
                  context.tr('Similarity', 'Độ giống nhau'),
                  SegControl(
                    labels: [
                      context.tr('Strict', 'Chặt'),
                      context.tr('Normal', 'Vừa'),
                      context.tr('Loose', 'Rộng'),
                    ],
                    index: s.simLevel,
                    onChanged: s.setSimLevel,
                  ),
                  note: context.tr('Looser groups more photos together. Re-scan after changing.',
                      'Rộng sẽ gom nhiều ảnh hơn. Quét lại sau khi đổi.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                infoRow(
                  context.tr('Photo access', 'Quyền truy cập ảnh'),
                  Text(
                      lib.limited
                          ? context.tr('Selected photos', 'Một số ảnh')
                          : context.tr('Full access', 'Toàn bộ'),
                      style: TextStyle(fontSize: 17, color: pal.sec)),
                ),
                divider(),
                infoRow(
                  context.tr('Recently Deleted', 'Đã xoá gần đây'),
                  Text(context.tr('30 days', '30 ngày'),
                      style: TextStyle(fontSize: 17, color: pal.sec)),
                ),
                divider(),
                infoRow(
                  context.tr('Open system Settings', 'Mở Cài đặt hệ thống'),
                  Icon(Icons.chevron_right_rounded, color: pal.sec),
                  onTap: lib.openSettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoRow(
                  context.tr('Private vault', 'Két riêng tư'),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 20, color: pal.sec),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded, color: pal.sec),
                    ],
                  ),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const VaultScreen())),
                ),
                divider(),
                block(
                  context.tr('Scan reminder', 'Nhắc quét định kỳ'),
                  SegControl(
                    labels: [
                      context.tr('Off', 'Tắt'),
                      context.tr('Daily', 'Hằng ngày'),
                      context.tr('Weekly', 'Hằng tuần'),
                    ],
                    index: s.remind,
                    onChanged: (i) async {
                      s.setRemind(i);
                      final svc = NotificationService.instance;
                      if (i != 0) await svc.requestPermission();
                      await svc.setReminder(
                        i,
                        title: s.isVi ? 'Đến lúc dọn ảnh' : 'Time for a photo cleanup',
                        body: s.isVi
                            ? 'Mở Photo Cleaner để tìm ảnh trùng và ảnh mờ.'
                            : 'Open Photo Cleaner to find duplicates and blurry shots.',
                      );
                    },
                  ),
                ),
                if (NotificationService.instance.isAndroid) ...[
                  divider(),
                  infoRow(
                    context.tr('Status bar notification', 'Thanh trạng thái thường trực'),
                    _IosSwitch(
                      value: s.statusBar,
                      onChanged: (v) async {
                        if (v) await NotificationService.instance.requestPermission();
                        s.setStatusBar(v);
                      },
                    ),
                  ),
                ],
                divider(),
                infoRow(
                  context.tr('Preview a notification', 'Xem thử thông báo'),
                  Icon(Icons.notifications_none_rounded, color: pal.accentText),
                  onTap: () async {
                    final svc = NotificationService.instance;
                    await svc.requestPermission();
                    await svc.preview(
                      title: s.isVi ? 'Photo Cleaner' : 'Photo Cleaner',
                      body: s.isVi
                          ? 'Có ảnh trùng và ảnh mờ đang chờ bạn dọn.'
                          : 'Duplicates and blurry shots are waiting for you.',
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
            child: Text(
              context.tr(
                  'Everything runs on this device. Deleted photos go to Recently Deleted (iOS) or the system trash (Android 11+) and can be restored. Cloud backup, client galleries and AI services need a backend and are not part of this build.',
                  'Mọi thứ chạy ngay trên máy. Ảnh xoá được chuyển vào Đã xoá gần đây (iOS) hoặc thùng rác hệ thống (Android 11+) và có thể khôi phục. Sao lưu đám mây, gallery cho khách và dịch vụ AI cần backend nên chưa nằm trong bản này.'),
              style: TextStyle(fontSize: 13, height: 18 / 13, color: pal.sec),
            ),
          ),
          const SizedBox(height: 20),
          PillButton(
            label: context.tr('Replay intro', 'Xem lại phần giới thiệu'),
            filled: false,
            onTap: session.replayIntro,
          ),
        ], tag: 'p'),
      ),
    );
  }
}

/// 52x32 switch with a 28px knob, matching the prototype.
class _IosSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _IosSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 52,
          height: 32,
          decoration: BoxDecoration(
            color: value ? AppColors.accent : pal.line,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 5, offset: Offset(0, 2))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
