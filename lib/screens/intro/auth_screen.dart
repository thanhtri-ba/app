import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/common.dart';
import 'logo.dart';

final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Sign in / sign up. There is no server: this only creates a local profile.
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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  bool get _signup => _mode == 1;

  void _submit() {
    final vi = context.read<SessionProvider>(); // for navigation only
    setState(() {
      _errName = _signup && _name.text.trim().isEmpty
          ? context.trr('Enter your name', 'Nhập tên của bạn')
          : null;
      _errEmail = _emailRe.hasMatch(_email.text.trim())
          ? null
          : context.trr('Enter a valid email', 'Email không hợp lệ');
      _errPass = _pass.text.length >= 6
          ? null
          : context.trr('At least 6 characters', 'Tối thiểu 6 ký tự');
    });
    if (_errName != null || _errEmail != null || _errPass != null) return;
    final email = _email.text.trim();
    final name = _signup ? _name.text.trim() : email.split('@').first;
    FocusScope.of(context).unfocus();
    vi.signIn(name, email);
  }

  void _social(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.trr('$provider sign-in needs a backend and is not available in this build.',
          'Đăng nhập $provider cần backend nên chưa có trong bản này.')),
    ));
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
    final session = context.read<SessionProvider>();

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
                  ? context.tr('Sync your settings and unlock Pro features.',
                      'Đồng bộ cài đặt và mở khoá tính năng Pro.')
                  : context.tr('Log in to sync your settings and Pro plan.',
                      'Đăng nhập để đồng bộ cài đặt và gói Pro.'),
              style: TextStyle(fontSize: 16, height: 22 / 16, color: pal.sec),
            ),
            const SizedBox(height: 20),
            SegControl(
              labels: [context.tr('Log in', 'Đăng nhập'), context.tr('Sign up', 'Đăng ký')],
              index: _mode,
              onChanged: (i) => setState(() {
                _mode = i;
                _errName = _errEmail = _errPass = null;
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
              hint: context.tr('At least 6 characters', 'Tối thiểu 6 ký tự'),
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
            const SizedBox(height: 16),
            PillButton(
              label: _signup ? context.tr('Create account', 'Tạo tài khoản') : context.tr('Log in', 'Đăng nhập'),
              onTap: _submit,
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
                      label: 'Apple', icon: Icons.apple, filled: false, onTap: () => _social('Apple')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PillButton(label: 'Google', filled: false, onTap: () => _social('Google')),
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

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
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
                  'If an account exists for ${_c.text.trim()}, a reset link would be sent. (This build has no server, so no email is actually sent.)',
                  'Nếu có tài khoản cho ${_c.text.trim()}, một liên kết đặt lại sẽ được gửi. (Bản này chưa có server nên không có email nào được gửi thật.)'),
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
              label: context.tr('Send link', 'Gửi liên kết'),
              onTap: () {
                if (!_emailRe.hasMatch(_c.text.trim())) {
                  setState(() => _err = context.trr('Enter a valid email', 'Email không hợp lệ'));
                  return;
                }
                setState(() => _sent = true);
              },
            ),
          ],
        ],
      ),
    );
  }
}
