import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

extension TrX on BuildContext {
  /// Use inside build(): rebuilds when the language changes.
  String tr(String en, String vi) =>
      Provider.of<SettingsProvider>(this).isVi ? vi : en;

  /// Use inside callbacks / async code.
  String trr(String en, String vi) =>
      Provider.of<SettingsProvider>(this, listen: false).isVi ? vi : en;
}
