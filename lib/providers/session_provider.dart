import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FlowStage { loading, splash, onboarding, auth, permission, app }

class UserProfile {
  final String name;
  final String email;
  const UserProfile(this.name, this.email);

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// First-run flow + local profile.
///
/// There is no backend: signing in only stores a name/email on this device.
/// Passwords are validated for shape but never stored or sent anywhere.
class SessionProvider extends ChangeNotifier {
  FlowStage stage = FlowStage.loading;
  UserProfile? user;
  bool _introDone = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _introDone = p.getBool('introDone') ?? false;
    final n = p.getString('userName');
    final e = p.getString('userEmail');
    if (n != null && e != null) user = UserProfile(n, e);
    stage = _introDone ? FlowStage.app : FlowStage.splash;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('introDone', _introDone);
    if (user == null) {
      await p.remove('userName');
      await p.remove('userEmail');
    } else {
      await p.setString('userName', user!.name);
      await p.setString('userEmail', user!.email);
    }
  }

  void _go(FlowStage s) {
    stage = s;
    notifyListeners();
  }

  void startFromSplash() => _go(FlowStage.onboarding);
  void finishOnboarding() => _go(FlowStage.auth);

  void signIn(String name, String email) {
    user = UserProfile(name, email);
    _save();
    _go(FlowStage.permission);
  }

  void continueAsGuest() {
    user = null;
    _save();
    _go(FlowStage.permission);
  }

  void allowPhotos() {
    _introDone = true;
    _save();
    _go(FlowStage.app);
  }

  /// Back to the sign-in screen (from Settings).
  void signOut() {
    user = null;
    _save();
    _go(FlowStage.auth);
  }

  /// Settings -> "Replay intro".
  void replayIntro() => _go(FlowStage.splash);

  /// Settings -> "Sign in" for guests.
  void openAuth() => _go(FlowStage.auth);
}
