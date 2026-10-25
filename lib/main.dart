import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/activity_provider.dart';
import 'providers/library_provider.dart';
import 'providers/meta_provider.dart';
import 'providers/scan_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PhotoCleanerApp());
}

class PhotoCleanerApp extends StatelessWidget {
  const PhotoCleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => MetaProvider()..load()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()..load()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => ScanProvider()),
      ],
      child: Builder(builder: (context) {
        final s = context.watch<SettingsProvider>();
        return MaterialApp(
          title: 'Photo Cleaner',
          debugShowCheckedModeBanner: false,
          themeMode: s.themeMode,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: const Shell(),
        );
      }),
    );
  }
}
