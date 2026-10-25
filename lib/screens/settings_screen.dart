import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.watch<SettingsProvider>();
    final lib = context.read<LibraryProvider>();

    Widget group(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: pal.text)),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        );

    const limits = [1000, 3000, 10000];
    final limitIdx = limits.contains(s.scanLimit) ? limits.indexOf(s.scanLimit) : 1;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Text(context.tr('Settings', 'Cài đặt'),
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: pal.text)),
          const SizedBox(height: 14),
          group(
            context.tr('Appearance', 'Giao diện'),
            SegControl(
              labels: [
                context.tr('System', 'Hệ thống'),
                context.tr('Light', 'Sáng'),
                context.tr('Dark', 'Tối'),
              ],
              index: s.themeMode.index,
              onChanged: (i) => s.setTheme(ThemeMode.values[i]),
            ),
          ),
          group(
            context.tr('Language', 'Ngôn ngữ'),
            SegControl(
              labels: const ['English', 'Tiếng Việt'],
              index: s.isVi ? 1 : 0,
              onChanged: (i) => s.setLang(i == 1 ? 'vi' : 'en'),
            ),
          ),
          group(
            context.tr('Photos to scan', 'Số ảnh cần quét'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegControl(
                  labels: const ['1,000', '3,000', '10,000'],
                  index: limitIdx,
                  onChanged: (i) => s.setScanLimit(limits[i]),
                ),
                const SizedBox(height: 8),
                Text(
                    context.tr('Newest photos first. Larger scans take longer.',
                        'Ảnh mới nhất trước. Quét nhiều ảnh sẽ lâu hơn.'),
                    style: TextStyle(fontSize: 12, color: pal.sec)),
              ],
            ),
          ),
          group(
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
          group(
            context.tr('Similarity', 'Độ giống nhau'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegControl(
                  labels: [
                    context.tr('Strict', 'Chặt'),
                    context.tr('Normal', 'Vừa'),
                    context.tr('Loose', 'Rộng'),
                  ],
                  index: s.simLevel,
                  onChanged: s.setSimLevel,
                ),
                const SizedBox(height: 8),
                Text(
                    context.tr('Looser groups more photos together. Re-scan after changing.',
                        'Rộng sẽ gom nhiều ảnh hơn. Quét lại sau khi đổi.'),
                    style: TextStyle(fontSize: 12, color: pal.sec)),
              ],
            ),
          ),
          group(
            context.tr('Photo access', 'Quyền truy cập ảnh'),
            Row(
              children: [
                Expanded(
                  child: Text(
                      lib.limited
                          ? context.tr('Selected photos only', 'Chỉ một số ảnh')
                          : context.tr('Full access', 'Toàn bộ thư viện'),
                      style: TextStyle(color: pal.sec)),
                ),
                TextButton(
                    onPressed: lib.openSettings, child: Text(context.tr('Open Settings', 'Mở Cài đặt'))),
              ],
            ),
          ),
          AppCard(
            child: Text(
              context.tr(
                  'Everything runs on this device. Deleted photos go to Recently Deleted (iOS) or the system trash (Android 11+) and can be restored. Cloud backup, client galleries and AI services need a backend and are not part of this build.',
                  'Mọi thứ chạy ngay trên máy. Ảnh xoá được chuyển vào Đã xoá gần đây (iOS) hoặc thùng rác hệ thống (Android 11+) và có thể khôi phục. Sao lưu đám mây, gallery cho khách và dịch vụ AI cần backend nên chưa nằm trong bản này.'),
              style: TextStyle(fontSize: 12, height: 1.45, color: pal.sec),
            ),
          ),
        ],
      ),
    );
  }
}
