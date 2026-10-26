import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth_rules.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/labeled_field.dart';

/// Shown after the user opens the "reset password" e-mail link.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  String? _errPass, _errPass2, _errForm;

  @override
  void dispose() {
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tr = context.trr;
    final vi = context.read<SettingsProvider>().isVi;
    final session = context.read<SessionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final issue = passwordIssue(_pass.text);
    setState(() {
      _errForm = null;
      _errPass = issue == null ? null : passwordIssueText(issue, vi: vi);
      _errPass2 = _pass.text == _pass2.text ? null : tr('Passwords do not match', 'Hai mật khẩu không khớp');
    });
    if (_errPass != null || _errPass2 != null) return;
    FocusScope.of(context).unfocus();
    final r = await session.changePassword(_pass.text);
    if (!mounted) return;
    if (r.ok) {
      messenger.showSnackBar(SnackBar(content: Text(tr('Password changed', 'Đã đổi mật khẩu'))));
    } else {
      setState(() => _errForm = friendlyAuthError(r.error ?? '', vi: vi));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final session = context.watch<SessionProvider>();
    return Scaffold(
      backgroundColor: pal.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Text(context.tr('Set a new password', 'Đặt mật khẩu mới'),
                style: TextStyle(fontSize: 30, height: 36 / 30, fontWeight: FontWeight.w700, color: pal.text)),
            const SizedBox(height: 8),
            Text(
                context.tr('Choose a password you have not used before.',
                    'Chọn một mật khẩu bạn chưa dùng trước đây.'),
                style: TextStyle(fontSize: 16, height: 22 / 16, color: pal.sec)),
            const SizedBox(height: 24),
            LabeledField(
              label: context.tr('New password', 'Mật khẩu mới'),
              controller: _pass,
              hint: context.tr('8+ characters, letters and digits', 'Từ 8 ký tự, gồm chữ và số'),
              error: _errPass,
              obscure: true,
              action: TextInputAction.next,
              autofill: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() => _errPass = null),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: context.tr('Repeat new password', 'Nhập lại mật khẩu mới'),
              controller: _pass2,
              hint: context.tr('Repeat the password', 'Nhập lại mật khẩu'),
              error: _errPass2,
              obscure: true,
              action: TextInputAction.done,
              autofill: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() => _errPass2 = null),
              onSubmit: _save,
            ),
            if (_errForm != null) ...[
              const SizedBox(height: 12),
              Text(_errForm!, style: TextStyle(fontSize: 14, color: pal.dangerText)),
            ],
            const SizedBox(height: 20),
            PillButton(
              label: session.busy ? context.tr('Please wait…', 'Vui lòng đợi…') : context.tr('Save password', 'Lưu mật khẩu'),
              onTap: session.busy ? null : _save,
            ),
            const SizedBox(height: 10),
            PillButton(
                label: context.tr('Not now', 'Để sau'),
                filled: false,
                onTap: session.busy ? null : session.cancelRecovery),
          ],
        ),
      ),
    );
  }
}
