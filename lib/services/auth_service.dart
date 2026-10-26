import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Build-time configuration. Pass with:
///   flutter run --dart-define-from-file=env.json
/// The anon key is public by design (row level security protects the data), but it still
/// stays out of source control.
class AuthConfig {
  AuthConfig._();
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Deep link that brings the user back to the app after e-mail links and OAuth.
  static const String redirect = 'photocleaner://login-callback/';

  static bool get configured => url.isNotEmpty && anonKey.isNotEmpty;
}

/// Result of an auth call. [error] is a raw message for [friendlyAuthError]; null means success.
class AuthResult {
  final String? error;

  /// Sign-up succeeded but the user must open the confirmation e-mail first.
  final bool needsConfirmation;
  const AuthResult({this.error, this.needsConfirmation = false});
  bool get ok => error == null;
}

/// Session tokens live in Keychain / Android Keystore-backed storage, not plain preferences.
class _SecureLocalStorage extends LocalStorage {
  _SecureLocalStorage();

  static final FlutterSecureStorage _store =
      FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: false));

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _store.containsKey(key: supabasePersistSessionKey);

  @override
  Future<String?> accessToken() => _store.read(key: supabasePersistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(key: supabasePersistSessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _store.delete(key: supabasePersistSessionKey);
}

/// Thin wrapper around Supabase Auth. Every method is safe to call when the app was built
/// without keys: it simply reports "not configured".
class AuthService {
  AuthService._();

  static bool _ready = false;
  static bool get ready => _ready;

  static Future<void> init() async {
    if (!AuthConfig.configured) return;
    try {
      await Supabase.initialize(
        url: AuthConfig.url,
        anonKey: AuthConfig.anonKey,
        authOptions: FlutterAuthClientOptions(localStorage: _SecureLocalStorage()),
      );
      _ready = true;
    } catch (e) {
      debugPrint('supabase init failed: $e');
    }
  }

  static GoTrueClient? get _auth => _ready ? Supabase.instance.client.auth : null;

  static User? get currentUser => _auth?.currentUser;
  static Stream<AuthState> get changes => _auth?.onAuthStateChange ?? const Stream<AuthState>.empty();

  static const AuthResult _notReady = AuthResult(error: 'not configured');

  static Future<AuthResult> _guard(Future<AuthResult> Function(GoTrueClient a) run) async {
    final a = _auth;
    if (a == null) return _notReady;
    try {
      return await run(a);
    } on AuthException catch (e) {
      debugPrint('auth error: ${e.message}');
      return AuthResult(error: e.message);
    } catch (e) {
      debugPrint('auth failure: $e');
      return AuthResult(error: e.toString());
    }
  }

  static Future<AuthResult> signUp(String name, String email, String password) => _guard((a) async {
        final r = await a.signUp(
          email: email,
          password: password,
          data: {'name': name},
          emailRedirectTo: AuthConfig.redirect,
        );
        // With e-mail confirmation on, Supabase returns a user but no session.
        return AuthResult(needsConfirmation: r.session == null);
      });

  static Future<AuthResult> signIn(String email, String password) => _guard((a) async {
        await a.signInWithPassword(email: email, password: password);
        return const AuthResult();
      });

  static Future<AuthResult> sendReset(String email) => _guard((a) async {
        await a.resetPasswordForEmail(email, redirectTo: AuthConfig.redirect);
        return const AuthResult();
      });

  /// Opens the provider's page in a browser sheet; the session arrives via [changes].
  static Future<AuthResult> oauth(OAuthProvider provider) => _guard((a) async {
        await a.signInWithOAuth(provider, redirectTo: AuthConfig.redirect);
        return const AuthResult();
      });

  static Future<AuthResult> updateName(String name) => _guard((a) async {
        await a.updateUser(UserAttributes(data: {'name': name}));
        return const AuthResult();
      });

  static Future<AuthResult> changePassword(String password) => _guard((a) async {
        await a.updateUser(UserAttributes(password: password));
        return const AuthResult();
      });

  /// Deletes the account through the `delete_my_account` SQL function (see docs/supabase_setup.sql).
  static Future<AuthResult> deleteAccount() => _guard((a) async {
        await Supabase.instance.client.rpc('delete_my_account');
        await a.signOut();
        return const AuthResult();
      });

  static Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (e) {
      debugPrint('sign out failed: $e');
    }
  }
}
