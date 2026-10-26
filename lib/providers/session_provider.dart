import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState, OAuthProvider, User;

import '../services/auth_service.dart';

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

/// First-run flow + signed-in user.
///
/// Accounts are handled by Supabase Auth ([AuthService]). Without build-time keys the app still
/// works in guest mode. Passwords are never stored by the app.
class SessionProvider extends ChangeNotifier {
  FlowStage stage = FlowStage.loading;
  UserProfile? user;
  bool _introDone = false;

  /// True while a network auth call is running (disables buttons).
  bool busy = false;

  /// Set when the user opened a "reset password" e-mail link; the UI must ask for a new password.
  bool recoveryPending = false;

  StreamSubscription<AuthState>? _sub;

  bool get signedIn => user != null;
  bool get authAvailable => AuthConfig.configured && AuthService.ready;

  static UserProfile? _fromSupabase(User? u) {
    if (u == null) return null;
    final email = u.email ?? '';
    final meta = u.userMetadata;
    final raw = meta == null ? null : meta['name'] ?? meta['full_name'];
    final name = (raw is String && raw.trim().isNotEmpty)
        ? raw.trim()
        : (email.contains('@') ? email.split('@').first : 'User');
    return UserProfile(name, email);
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _introDone = p.getBool('introDone') ?? false;
    // Older builds stored a fake local profile. It was never a real account: drop it.
    if (p.containsKey('userName') || p.containsKey('userEmail')) {
      await p.remove('userName');
      await p.remove('userEmail');
    }
    user = _fromSupabase(AuthService.currentUser);
    _sub?.cancel();
    _sub = AuthService.changes.listen(_onAuth);
    stage = _introDone ? FlowStage.app : FlowStage.splash;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onAuth(AuthState s) {
    switch (s.event) {
      case AuthChangeEvent.passwordRecovery:
        user = _fromSupabase(s.session?.user);
        recoveryPending = true;
        notifyListeners();
        break;
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.userUpdated:
      case AuthChangeEvent.tokenRefreshed:
        final wasSignedOut = user == null;
        user = _fromSupabase(s.session?.user);
        // Returning from an OAuth page or an e-mail confirmation link.
        if (wasSignedOut && user != null && stage == FlowStage.auth) {
          _afterAuth();
        } else {
          notifyListeners();
        }
        break;
      case AuthChangeEvent.signedOut:
        user = null;
        notifyListeners();
        break;
      default:
        break;
    }
  }

  Future<void> _saveIntro() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('introDone', _introDone);
  }

  void _go(FlowStage s) {
    stage = s;
    notifyListeners();
  }

  /// After signing in (or choosing guest): straight back to the app if the intro was already
  /// completed, otherwise continue to the photo-permission step.
  void _afterAuth() => _go(_introDone ? FlowStage.app : FlowStage.permission);

  void startFromSplash() => _go(FlowStage.onboarding);
  void finishOnboarding() => _go(FlowStage.auth);

  Future<AuthResult> _run(Future<AuthResult> Function() job) async {
    if (busy) return const AuthResult(error: 'busy');
    busy = true;
    notifyListeners();
    try {
      return await job();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<AuthResult> signInEmail(String email, String password) async {
    final r = await _run(() => AuthService.signIn(email.trim(), password));
    if (r.ok) {
      user = _fromSupabase(AuthService.currentUser);
      _afterAuth();
    }
    return r;
  }

  Future<AuthResult> signUpEmail(String name, String email, String password) async {
    final r = await _run(() => AuthService.signUp(name.trim(), email.trim(), password));
    if (r.ok && !r.needsConfirmation) {
      user = _fromSupabase(AuthService.currentUser);
      _afterAuth();
    }
    return r;
  }

  Future<AuthResult> sendReset(String email) => _run(() => AuthService.sendReset(email.trim()));

  Future<AuthResult> signInWith(OAuthProvider provider) => _run(() => AuthService.oauth(provider));

  /// "Continue as guest" / leaving the sign-in screen without logging in.
  void continueAsGuest() => _afterAuth();

  void allowPhotos() {
    _introDone = true;
    _saveIntro();
    _go(FlowStage.app);
  }

  /// Signs out of the account and returns to the sign-in screen.
  Future<void> signOut() async {
    await AuthService.signOut();
    user = null;
    _go(FlowStage.auth);
  }

  Future<AuthResult> updateName(String name) async {
    final r = await _run(() => AuthService.updateName(name.trim()));
    if (r.ok) user = _fromSupabase(AuthService.currentUser);
    return r;
  }

  Future<AuthResult> changePassword(String password) async {
    final r = await _run(() => AuthService.changePassword(password));
    if (r.ok) recoveryPending = false;
    return r;
  }

  /// Called when the user dismisses the "new password" screen without finishing.
  void cancelRecovery() {
    recoveryPending = false;
    notifyListeners();
  }

  Future<AuthResult> deleteAccount() async {
    final r = await _run(AuthService.deleteAccount);
    if (r.ok) {
      user = null;
      _go(FlowStage.auth);
    }
    return r;
  }

  /// Settings -> "Replay intro".
  void replayIntro() => _go(FlowStage.splash);

  /// Settings -> "Sign in" for guests.
  void openAuth() => _go(FlowStage.auth);
}
