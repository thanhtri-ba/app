import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  String lang = 'en';
  int scanLimit = 3000;
  int blurLevel = 1; // 0 low, 1 medium, 2 high sensitivity
  int simLevel = 1; // 0 strict, 1 normal, 2 loose

  bool get isVi => lang == 'vi';

  /// Laplacian-variance threshold: photos below it are flagged as blurry.
  double get blurThreshold => const [35.0, 60.0, 100.0][blurLevel];

  /// Max Hamming distance (of 64) for two photos to count as similar.
  int get hashThreshold => const [4, 7, 11][simLevel];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[(p.getInt('theme') ?? 0).clamp(0, 2)];
    lang = p.getString('lang') ?? 'en';
    scanLimit = p.getInt('scanLimit') ?? 3000;
    blurLevel = (p.getInt('blurLevel') ?? 1).clamp(0, 2);
    simLevel = (p.getInt('simLevel') ?? 1).clamp(0, 2);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('theme', themeMode.index);
    await p.setString('lang', lang);
    await p.setInt('scanLimit', scanLimit);
    await p.setInt('blurLevel', blurLevel);
    await p.setInt('simLevel', simLevel);
  }

  void setTheme(ThemeMode m) {
    themeMode = m;
    notifyListeners();
    _save();
  }

  void setLang(String l) {
    lang = l;
    notifyListeners();
    _save();
  }

  void setScanLimit(int n) {
    scanLimit = n;
    notifyListeners();
    _save();
  }

  void setBlurLevel(int n) {
    blurLevel = n;
    notifyListeners();
    _save();
  }

  void setSimLevel(int n) {
    simLevel = n;
    notifyListeners();
    _save();
  }
}
