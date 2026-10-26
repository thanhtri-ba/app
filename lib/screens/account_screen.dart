import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_rules.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common.dart';
import '../widgets/labeled_field.dart';

/// Profile, password and account deletion for a signed-in user.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final TextEditingController _name =
      TextEditingController(text: context.read<SessionProvider>().user?.name ?? '');
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  String? _errName, _errPass, _errPass2;

  @override
  void dispose() {
    _name.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _saveName() async {
    final tr = context.trr;
    final vi = context.read<SettingsProvider>().isVi;
    final session = context.read<SessionProvider>();
    if (_name.text.trim().isEmpty) {
      setState(() => _errName = tr('Enter your name', 'Nhập tên của bạn'));
      return;
    }
    FocusScope.of(context).unfocus();
    final r = await session.updateName(_name.text);
    if (!mounted) return;
    _toast(r.ok ? tr('Name updated', 'Đã cập nhật tên') : friendlyAuthError(r.error ?? '', vi: vi));
  }

  Future<void> _savePassword() async {
    final tr = context.trr;
    final vi = context.read<SettingsProvider>().isVi;
    final session = context.read<SessionProvider>();
    final issue = passwordIssue(_pass.text);
    setState(() {
      _errPass = issue == null ? null : passwordIssueText(issue, vi: vi);
      _errPass2 = _pass.text == _pass2.text ? null : tr('Passwords do not match', 'Hai mật khẩu không khớp');
    });
    if (_errPass != null || _errPass2 != null) return;
    FocusScope.of(context).unfocus();
    final r = await session.changePassword(_pass.text);
    if (!mounted) return;
    if (r.ok) {
      _pass.clear();
      _pass2.clear();
    }
    _toast(r.ok ? tr('Password changed', 'Đã đổi mật khẩu') : friendlyAuthError(r.error ?? '', vi: vi));
  }

  Future<void> _logout() async {
    final nav = Navigator.of(context);
    final session = context.read<SessionProvider>();
    await session.signOut();
    nav.popUntil((r) => r.isFirst);
  }

  Future<void> _delete() async {
    final tr = context.trr;
    final vi = context.read<SettingsProvider>().isVi;
    final session = context.read<SessionProvider>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Delete your account?', 'Xoá tài khoản?')),
        content: Text(ctx.tr(
            'Your account and its data on our server will be deleted permanently. Photos on this device are not touched. This cannot be undone.',
            'Tài khoản và dữ liệu của bạn trên máy chủ sẽ bị xoá vĩnh viễn. Ảnh trên máy này không bị ảnh hưởng. Không thể hoàn tác.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Cancel', 'Huỷ'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('Delete forever', 'Xoá vĩnh viễn'),
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await session.deleteAccount();
    if (!mounted) return;
    if (r.ok) {
      nav.popUntil((r) => r.isFirst);
    } else {
      _toast(friendlyAuthError(r.error ?? '', vi: vi) +
          tr(' If this keeps happening, the server function may be missing.',
              ' Nếu lỗi lặp lại, có thể máy chủ chưa cài hàm xoá tài khoản.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final session = context.watch<SessionProvider>();
    final user = session.user;
    final busy = session.busy;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Account', 'Tài khoản'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text(user?.email ?? '', style: TextStyle(fontSize: 15, color: pal.sec)),
          const SizedBox(height: 18),
          LabeledField(
            label: context.tr('Name', 'Tên'),
            controller: _name,
            hint: context.tr('Your name', 'Tên của bạn'),
            error: _errName,
            enabled: !busy,
            action: TextInputAction.done,
            onChanged: (_) => setState(() => _errName = null),
            onSubmit: _saveName,
          ),
          const SizedBox(height: 12),
          PillButton(
              label: context.tr('Save name', 'Lưu tên'), filled: false, onTap: busy ? null : _saveName),
          const SizedBox(height: 28),
          Text(context.tr('Change password', 'Đổi mật khẩu'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: pal.text)),
          const SizedBox(height: 12),
          LabeledField(
            label: context.tr('New password', 'Mật khẩu mới'),
            controller: _pass,
            hint: context.tr('8+ characters, letters and digits', 'Từ 8 ký tự, gồm chữ và số'),
            error: _errPass,
            obscure: true,
            enabled: !busy,
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
            enabled: !busy,
            action: TextInputAction.done,
            autofill: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() => _errPass2 = null),
            onSubmit: _savePassword,
          ),
          const SizedBox(height: 12),
          PillButton(
              label: context.tr('Change password', 'Đổi mật khẩu'),
              filled: false,
              onTap: busy ? null : _savePassword),
          const SizedBox(height: 28),
          PillButton(label: context.tr('Log out', 'Đăng xuất'), filled: false, onTap: busy ? null : _logout),
          const SizedBox(height: 28),
          Text(context.tr('Danger zone', 'Vùng nguy hiểm'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: pal.dangerText)),
          const SizedBox(height: 8),
          PillButton(
              label: context.tr('Delete account', 'Xoá tài khoản'),
              danger: true,
              onTap: busy ? null : _delete),
          const SizedBox(height: 8),
          Text(
            context.tr('Deleting removes your account on the server only. Your photos stay on this device.',
                'Xoá chỉ gỡ tài khoản trên máy chủ. Ảnh của bạn vẫn nằm trên máy này.'),
            style: TextStyle(fontSize: 12, height: 17 / 12, color: pal.sec),
          ),
        ],
      ),
    );
  }
}
