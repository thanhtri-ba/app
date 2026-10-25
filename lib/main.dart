import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/activity_provider.dart';
import 'providers/library_provider.dart';
import 'providers/meta_provider.dart';
import 'providers/scan_provider.dart';
import 'providers/session_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/vault_provider.dart';
import 'services/notification_service.dart';
import 'screens/intro/intro_flow.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const PhotoCleanerApp());
}

class PhotoCleanerApp extends StatelessWidget {
  const PhotoCleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => SessionProvider()..load()),
        ChangeNotifierProvider(create: (_) => MetaProvider()..load()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()..load()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => ScanProvider()..load()),
        ChangeNotifierProvider(create: (_) => VaultProvider()..load()),
      ],
      child: Builder(builder: (context) {
        final s = context.watch<SettingsProvider>();
        return MaterialApp(
          title: 'Photo Cleaner',
          debugShowCheckedModeBanner: false,
          themeMode: s.themeMode,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          // Keep layouts intact when the system font size is very large.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const _FlowGate(),
        );
      }),
    );
  }
}

/// Shows the intro flow on first launch, then the app.
class _FlowGate extends StatelessWidget {
  const _FlowGate();

  @override
  Widget build(BuildContext context) {
    final stage = context.select<SessionProvider, FlowStage>((s) => s.stage);
    switch (stage) {
      case FlowStage.loading:
        return Scaffold(backgroundColor: context.pal.bg);
      case FlowStage.app:
        return const Shell();
      default:
        return const IntroFlow();
    }
  }
}
