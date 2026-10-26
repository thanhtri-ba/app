import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../../core/auth_rules.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import 'logo.dart';

/// Sign in / sign up with e-mail + password or Google / Apple (Supabase Auth).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _mode = 0; // 0 log in, 1 sign up
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _show = false;
  String? _errName, _errEmail, _errPass;
  String? _formError; // error from the server
  String? _info; // e.g. "check your inbox"

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  bool get _signup => _mode == 1;

  Future<void> _submit() async {
    final session = context.read<SessionProvider>();
    final tr = context.trr;
    final vi = context.read<SettingsProvider>().isVi;
    final issue = passwordIssue(_pass.text);
    setState(() {
      _formError = null;
      _info = null;
      _errName = _signup && _name.text.trim().isEmpty ? tr('Enter your name', 'Nhập tên của bạn') : null;
      _errEmail = isValidEmail(_email.text) ? null : tr('Enter a valid email', 'Email không hợp lệ');
      // The strength policy only applies when creating a password; old accounts just need one.
      _errPass = _signup
          ? (issue == null ? null : passwordIssueText(issue, vi: vi))
          : (_pass.text.isEmpty ? tr('Enter your password', 'Nhập mật khẩu') : null);
    });
    if (_errName != null || _errEmail != null || _errPass != null) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final r = _signup
        ? await session.signUpEmail(_name.text, email, _pass.text)
        : await session.signInEmail(email, _pass.text);
    if (!mounted) return;
    if (!r.ok) {
      setState(() => _formError = friendlyAuthError(r.error ?? '', vi: vi));
    } else if (r.needsConfirmation) {
      setState(() {
        _mode = 0;
        _pass.clear();
        _info = tr('We sent a confirmation link to $email. Open it, then log in.',
            'Đã gửi liên kết xác nhận tới $email. Hãy mở nó rồi đăng nhập.');
      });
    }
  }

  Future<void> _social(OAuthProvider provider) async {
    final session = context.read<SessionProvider>();
    final vi = context.read<SettingsProvider>().isVi;
    setState(() {
      _formError = null;
      _info = null;
    });
    // On success the browser sheet opens and the session arrives through the auth listener.
    final r = await session.signInWith(provider);
    if (!mounted) return;
    if (!r.ok) setState(() => _formError = friendlyAuthError(r.error ?? '', vi: vi));
  }

  void _forgot() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.pal.sheet,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _ForgotSheet(initialEmail: _email.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final session = context.watch<SessionProvider>();
    final canSubmit = session.authAvailable && !session.busy;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const AppMark(size: 44, radius: 13),
                const SizedBox(width: 12),
                Text('Photo Cleaner',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: pal.text)),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              _signup
                  ? context.tr('Create your account', 'Tạo tài khoản')
                  : context.tr('Welcome back', 'Chào mừng trở lại'),
              style: TextStyle(
                  fontSize: 32,
                  height: 38 / 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: pal.text),
            ),
            const SizedBox(height: 6),
            Text(
              _signup
                  ? context.tr('Use one account on all your devices.',
                      'Dùng chung một tài khoản trên mọi thiết bị.')
                  : context.tr('Log in with your account.', 'Đăng nhập bằng tài khoản của bạn.'),
              style: TextStyle(fontSize: 16, height: 22 / 16, color: pal.sec),
            ),
            if (!session.authAvailable) ...[
              const SizedBox(height: 14),
              _Notice(
                error: true,
                text: context.tr(
                    'Sign-in server is not configured in this build. You can still continue as a guest.',
                    'Bản này chưa kết nối máy chủ đăng nhập. Bạn vẫn có thể tiếp tục với tư cách khách.'),
              ),
            ],
            const SizedBox(height: 20),
            SegControl(
              labels: [context.tr('Log in', 'Đăng nhập'), context.tr('Sign up', 'Đăng ký')],
              index: _mode,
              onChanged: (i) => setState(() {
                _mode = i;
                _errName = _errEmail = _errPass = null;
                _formError = null;
                _info = null;
              }),
            ),
            const SizedBox(height: 18),
            if (_signup) ...[
              _Field(
                label: context.tr('Name', 'Tên'),
                controller: _name,
                hint: context.tr('Your name', 'Tên của bạn'),
                error: _errName,
                action: TextInputAction.next,
                autofill: const [AutofillHints.name],
                onChanged: (_) => setState(() => _errName = null),
              ),
              const SizedBox(height: 12),
            ],
            _Field(
              label: 'Email',
              controller: _email,
              hint: 'name@example.com',
              error: _errEmail,
              keyboard: TextInputType.emailAddress,
              action: TextInputAction.next,
              autofill: const [AutofillHints.email],
              onChanged: (_) => setState(() => _errEmail = null),
            ),
            const SizedBox(height: 12),
            _Field(
              label: context.tr('Password', 'Mật khẩu'),
              controller: _pass,
              hint: _signup
                  ? context.tr('8+ characters, letters and digits', 'Từ 8 ký tự, gồm chữ và số')
                  : context.tr('Your password', 'Mật khẩu của bạn'),
              error: _errPass,
              obscure: !_show,
              action: TextInputAction.done,
              autofill: [_signup ? AutofillHints.newPassword : AutofillHints.password],
              onChanged: (_) => setState(() => _errPass = null),
              onSubmit: _submit,
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _show = !_show),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 22, color: pal.sec),
                ),
              ),
            ),
            if (!_signup)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _forgot,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(context.tr('Forgot password?', 'Quên mật khẩu?'),
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: pal.accentText)),
                    ),
                  ),
                ),
              ),
            if (_formError != null) ...[
              const SizedBox(height: 12),
              _Notice(error: true, text: _formError!),
            ],
            if (_info != null) ...[
              const SizedBox(height: 12),
              _Notice(error: false, text: _info!),
            ],
            const SizedBox(height: 16),
            PillButton(
              label: session.busy
                  ? context.tr('Please wait…', 'Vui lòng đợi…')
                  : (_signup ? context.tr('Create account', 'Tạo tài khoản') : context.tr('Log in', 'Đăng nhập')),
              onTap: canSubmit ? _submit : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  Expanded(child: Divider(height: 1, color: pal.line)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(context.tr('or', 'hoặc'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: pal.sec)),
                  ),
                  Expanded(child: Divider(height: 1, color: pal.line)),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                      label: 'Apple',
                      icon: Icons.apple,
                      filled: false,
                      onTap: canSubmit ? () => _social(OAuthProvider.apple) : null),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PillButton(
                      label: 'Google',
                      filled: false,
                      onTap: canSubmit ? () => _social(OAuthProvider.google) : null),
                ),
              ],
            ),
            const SizedBox(height: 22),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: session.continueAsGuest,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(context.tr('Continue as guest', 'Tiếp tục với tư cách khách'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: pal.accentText)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(
                  'By continuing you agree to the Terms of Service and Privacy Policy. Your photos never leave your device.',
                  'Tiếp tục nghĩa là bạn đồng ý Điều khoản và Chính sách riêng tư. Ảnh của bạn không bao giờ rời khỏi máy.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 17 / 12, color: pal.sec),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final bool error;
  const _Notice({required this.text, required this.error});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = error ? pal.dangerText : pal.ok;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(error ? Icons.error_outline_rounded : Icons.mark_email_read_outlined, size: 20, color: c),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, height: 20 / 14, color: pal.text))),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? error;
  final TextInputType? keyboard;
  final TextInputAction? action;
  final bool obscure;
  final Iterable<String>? autofill;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmit;
  final Widget? trailing;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.error,
    this.keyboard,
    this.action,
    this.obscure = false,
    this.autofill,
    this.onChanged,
    this.onSubmit,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final hasErr = error != null;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: 1.5),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: pal.text)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          textInputAction: action,
          autofillHints: autofill,
          autocorrect: false,
          enableSuggestions: !obscure,
          onChanged: onChanged,
          onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
          style: TextStyle(fontSize: 16, color: pal.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: pal.sec),
            filled: true,
            fillColor: pal.card,
            isDense: false,
            contentPadding: EdgeInsets.fromLTRB(16, 16, trailing == null ? 16 : 6, 16),
            suffixIcon: trailing,
            enabledBorder: border(hasErr ? pal.dangerText : pal.line),
            focusedBorder: border(hasErr ? pal.dangerText : AppColors.accent),
            border: border(pal.line),
          ),
        ),
        if (hasErr)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(error!, style: TextStyle(fontSize: 13, color: pal.dangerText)),
          ),
      ],
    );
  }
}

class _ForgotSheet extends StatefulWidget {
  final String initialEmail;
  const _ForgotSheet({required this.initialEmail});

  @override
  State<_ForgotSheet> createState() => _ForgotSheetState();
}

class _ForgotSheetState extends State<_ForgotSheet> {
  late final TextEditingController _c = TextEditingController(text: widget.initialEmail);
  String? _err;
  bool _sent = false;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final session = context.read<SessionProvider>();
    final vi = context.read<SettingsProvider>().isVi;
    if (!isValidEmail(_c.text)) {
      setState(() => _err = context.trr('Enter a valid email', 'Email không hợp lệ'));
      return;
    }
    setState(() => _busy = true);
    final r = await session.sendReset(_c.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok) {
        _sent = true;
      } else {
        _err = friendlyAuthError(r.error ?? '', vi: vi);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: pal.line, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 20),
          Text(context.tr('Reset password', 'Đặt lại mật khẩu'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: pal.text)),
          const SizedBox(height: 6),
          if (_sent) ...[
            Text(
              context.tr(
                  'If an account exists for ${_c.text.trim()}, we sent a reset link. Check your inbox (and spam).',
                  'Nếu có tài khoản cho ${_c.text.trim()}, chúng tôi đã gửi liên kết đặt lại. Hãy kiểm tra hộp thư (kể cả thư rác).'),
              style: TextStyle(fontSize: 15, height: 21 / 15, color: pal.sec),
            ),
            const SizedBox(height: 20),
            PillButton(label: context.tr('Done', 'Xong'), onTap: () => Navigator.of(context).pop()),
          ] else ...[
            Text(context.tr('Enter your email and we will send a reset link.',
                'Nhập email để nhận liên kết đặt lại mật khẩu.'),
                style: TextStyle(fontSize: 15, height: 21 / 15, color: pal.sec)),
            const SizedBox(height: 16),
            _Field(
              label: 'Email',
              controller: _c,
              hint: 'name@example.com',
              error: _err,
              keyboard: TextInputType.emailAddress,
              onChanged: (_) => setState(() => _err = null),
            ),
            const SizedBox(height: 16),
            PillButton(
              label: _busy ? context.tr('Please wait…', 'Vui lòng đợi…') : context.tr('Send link', 'Gửi liên kết'),
              onTap: _busy ? null : _send,
            ),
          ],
        ],
      ),
    );
  }
}
