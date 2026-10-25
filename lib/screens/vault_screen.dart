import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';
import '../providers/meta_provider.dart';
import '../providers/scan_provider.dart';
import '../providers/vault_provider.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Entry point: PIN setup / unlock, then the vault itself.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

enum _Step { unlock, create, confirm, open }

class _VaultScreenState extends State<VaultScreen> with WidgetsBindingObserver {
  _Step _step = _Step.unlock;
  String _first = '';
  bool _err = false;
  Timer? _tick;
  late final VaultProvider _vault;

  @override
  void initState() {
    super.initState();
    _vault = context.read<VaultProvider>();
    WidgetsBinding.instance.addObserver(this);
    VaultProvider.setSecure(true);
    final v = context.read<VaultProvider>();
    _step = v.hasPin ? _Step.unlock : _Step.create;
    if (v.hasPin && v.bioEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VaultProvider.setSecure(false);
    _vault.clearTemp();
    _tick?.cancel();
    super.dispose();
  }

  /// Leaving the app locks the vault: pop back out, so re-entering asks for PIN/biometrics.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    final v = context.read<VaultProvider>();
    if (v.busy) return; // a system dialog (delete confirmation) is in front of us
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _bio() async {
    final v = context.read<VaultProvider>();
    final ok = await v.authenticate(
        context.trr('Unlock your private vault', 'Mở khoá két riêng tư'));
    if (ok && mounted) setState(() => _step = _Step.open);
  }

  Future<void> _onPin(String pin) async {
    final v = context.read<VaultProvider>();
    switch (_step) {
      case _Step.unlock:
        final ok = await v.checkPin(pin);
        if (!mounted) return;
        if (ok) {
          setState(() {
            _step = _Step.open;
            _err = false;
          });
        } else {
          HapticFeedback.heavyImpact();
          setState(() => _err = true);
          if (v.lockRemaining > Duration.zero) {
            _tick?.cancel();
            _tick = Timer.periodic(const Duration(seconds: 1), (t) {
              if (!mounted || v.lockRemaining == Duration.zero) {
                t.cancel();
              }
              if (mounted) setState(() {});
            });
          }
        }
        break;
      case _Step.create:
        setState(() {
          _first = pin;
          _step = _Step.confirm;
          _err = false;
        });
        break;
      case _Step.confirm:
        if (pin == _first) {
          await v.setPin(pin);
          if (mounted) setState(() => _step = _Step.open);
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _err = true;
            _first = '';
            _step = _Step.create;
          });
        }
        break;
      case _Step.open:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final v = context.watch<VaultProvider>();
    if (_step == _Step.open) return const _VaultHome();

    final lock = v.lockRemaining;
    String title;
    String sub;
    switch (_step) {
      case _Step.unlock:
        title = context.tr('Enter your PIN', 'Nhập mã PIN');
        sub = lock > Duration.zero
            ? context.tr('Too many attempts. Try again in ${lock.inSeconds + 1}s.',
                'Nhập sai quá nhiều lần. Thử lại sau ${lock.inSeconds + 1} giây.')
            : (_err
                ? context.tr('Wrong PIN, try again', 'Sai mã PIN, thử lại')
                : context.tr('Unlock your private vault', 'Mở khoá két riêng tư'));
        break;
      case _Step.create:
        title = context.tr('Create a PIN', 'Tạo mã PIN');
        sub = _err
            ? context.tr('PINs did not match, start again', 'Hai mã không khớp, nhập lại từ đầu')
            : context.tr('Choose a 4-digit PIN for your vault', 'Chọn mã PIN 4 số cho két');
        break;
      default:
        title = context.tr('Confirm your PIN', 'Xác nhận mã PIN');
        sub = context.tr('Enter the same PIN again', 'Nhập lại cùng mã PIN');
    }

    return Scaffold(
      backgroundColor: pal.bg,
      body: GlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
                  child: _RoundBack(onTap: () => Navigator.of(context).pop()),
                ),
              ),
              Expanded(
                child: _PinPad(
                  key: ValueKey('$_step$_err${lock.inSeconds}'),
                  title: title,
                  subtitle: sub,
                  error: _err,
                  disabled: _step == _Step.unlock && lock > Duration.zero,
                  onComplete: _onPin,
                  onBio: _step == _Step.unlock && v.bioEnabled ? _bio : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Text(
                  context.tr(
                      'Your photos are encrypted on this device. The PIN cannot be recovered: if you forget it, the vault cannot be opened.',
                      'Ảnh được mã hoá ngay trên máy. Mã PIN không thể khôi phục: nếu quên, bạn sẽ không mở được két.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 17 / 12, color: pal.sec),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundBack extends StatelessWidget {
  final VoidCallback onTap;
  const _RoundBack({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: pal.card,
          shape: BoxShape.circle,
          border: Border.all(color: pal.line),
        ),
        child: Icon(Icons.chevron_left_rounded, size: 24, color: pal.text),
      ),
    );
  }
}

class _PinPad extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool error;
  final bool disabled;
  final ValueChanged<String> onComplete;
  final VoidCallback? onBio;
  const _PinPad({
    super.key,
    required this.title,
    required this.subtitle,
    required this.error,
    required this.disabled,
    required this.onComplete,
    this.onBio,
  });

  @override
  State<_PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<_PinPad> {
  String _v = '';

  void _tap(String d) {
    if (widget.disabled || _v.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() => _v += d);
    if (_v.length == 4) {
      final pin = _v;
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) widget.onComplete(pin);
      });
    }
  }

  void _back() {
    if (_v.isEmpty) return;
    setState(() => _v = _v.substring(0, _v.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: 64,
              margin: const EdgeInsets.all(6),
              alignment: Alignment.center,
              decoration: label.isEmpty && child == null
                  ? null
                  : BoxDecoration(
                      color: child == null ? pal.card : Colors.transparent,
                      shape: BoxShape.circle,
                      border: child == null ? Border.all(color: pal.line) : null,
                    ),
              child: child ??
                  Text(label,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: pal.text)),
            ),
          ),
        );

    Widget row(List<String> d) => Row(children: [for (final x in d) key(x, onTap: () => _tap(x))]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: pal.card,
              shape: BoxShape.circle,
              border: Border.all(color: pal.line),
            ),
            child: Icon(Icons.lock_outline_rounded, size: 30, color: pal.accentText),
          ),
          const SizedBox(height: 18),
          Text(widget.title,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: pal.text)),
          const SizedBox(height: 6),
          Text(widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, color: widget.error ? pal.dangerText : pal.sec)),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _v.length
                        ? (widget.error ? pal.dangerText : AppColors.accent)
                        : Colors.transparent,
                    border: Border.all(
                        color: i < _v.length ? Colors.transparent : pal.sec, width: 1.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 26),
          row(const ['1', '2', '3']),
          row(const ['4', '5', '6']),
          row(const ['7', '8', '9']),
          Row(
            children: [
              widget.onBio == null
                  ? key('')
                  : key('',
                      onTap: widget.onBio,
                      child: Icon(Icons.fingerprint_rounded, color: pal.accentText, size: 30)),
              key('0', onTap: () => _tap('0')),
              key('',
                  onTap: _back,
                  child: Icon(Icons.backspace_outlined, color: pal.text, size: 24)),
            ],
          ),
        ],
      ),
    );
  }
}

class _VaultHome extends StatefulWidget {
  const _VaultHome();

  @override
  State<_VaultHome> createState() => _VaultHomeState();
}

class _VaultHomeState extends State<_VaultHome> {
  final Set<String> _sel = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Encrypt anything stored in plain form by the first version of the vault.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<VaultProvider>().migrateLegacy();
    });
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _add() async {
    final picked = await Navigator.of(context).push<List<AssetEntity>>(
        MaterialPageRoute(builder: (_) => const _VaultPicker()));
    if (picked == null || picked.isEmpty || !mounted) return;
    final vault = context.read<VaultProvider>();
    final lib = context.read<LibraryProvider>();
    final scan = context.read<ScanProvider>();
    final meta = context.read<MetaProvider>();
    final vi = context.read<VaultProvider>(); // same instance, kept for clarity
    final tr = context.trr;
    setState(() => _busy = true);
    vault.busy = true; // keeps auto-lock off while the system delete dialog is shown
    final copied = await vault.copyIn(picked);
    if (copied.isEmpty) {
      vault.busy = false;
      if (mounted) {
        setState(() => _busy = false);
        _msg(tr('Could not read those photos.', 'Không đọc được các ảnh đó.'));
      }
      return;
    }
    final tailStart = vi.items.length - copied.length;
    final tail = vi.items.sublist(tailStart);
    // Remove the originals from the library (system asks for confirmation).
    final deleted = await lib.deleteAssets(copied);
    final keep = <VaultItem>[];
    for (var k = 0; k < copied.length; k++) {
      if (!deleted.contains(copied[k].id)) keep.add(tail[k]);
    }
    if (keep.isNotEmpty) await vault.deleteForever(keep); // not removed from library -> not hidden
    scan.removeIds(deleted);
    meta.remove(deleted);
    vault.busy = false;
    if (!mounted) return;
    setState(() => _busy = false);
    _msg(deleted.isEmpty
        ? tr('Nothing was hidden.', 'Chưa ẩn ảnh nào.')
        : tr('Hidden ${deleted.length} items in the vault.', 'Đã ẩn ${deleted.length} mục vào két.'));
  }

  Future<void> _restore(List<VaultItem> list) async {
    final tr = context.trr;
    setState(() => _busy = true);
    final n = await context.read<VaultProvider>().restore(list);
    if (!mounted) return;
    await context.read<LibraryProvider>().reload();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sel.clear();
    });
    _msg(tr('Restored $n items to your library.', 'Đã khôi phục $n mục về thư viện.'));
  }

  Future<void> _delete(List<VaultItem> list) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Delete ${list.length} items forever?', 'Xoá vĩnh viễn ${list.length} mục?')),
        content: Text(ctx.tr('This cannot be undone. They will not go to Recently Deleted.',
            'Không thể hoàn tác. Chúng sẽ không vào Đã xoá gần đây.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Cancel', 'Huỷ'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('Delete', 'Xoá'), style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<VaultProvider>().deleteForever(list);
    if (mounted) setState(_sel.clear);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final vault = context.watch<VaultProvider>();
    final items = vault.items;
    final chosen = items.where((e) => _sel.contains(e.id)).toList();

    return Scaffold(
      backgroundColor: pal.bg,
      body: GlowBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RoundBack(onTap: () => Navigator.of(context).pop()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(context.tr('Private vault', 'Két riêng tư'),
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: pal.text)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: pal.card,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: pal.line),
                      ),
                      child: Text('${items.length}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: pal.text)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: pal.accentText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr(
                              'Hidden photos are encrypted (AES-256) and live in this app only. Restore them before uninstalling or changing phone, or they are lost.',
                              'Ảnh được mã hoá (AES-256) và chỉ nằm trong app. Hãy khôi phục trước khi gỡ app hoặc đổi máy, nếu không sẽ mất ảnh.'),
                          style: TextStyle(fontSize: 13, height: 18 / 13, color: pal.text),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const _BioRow(),
                if (vault.migrating)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              context.tr('Encrypting photos from the previous version...',
                                  'Đang mã hoá ảnh từ phiên bản trước...'),
                              style: TextStyle(fontSize: 13, color: pal.sec)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 80),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline_rounded, size: 44, color: pal.sec),
                                const SizedBox(height: 12),
                                Text(context.tr('Your vault is empty', 'Két đang trống'),
                                    style: TextStyle(
                                        fontSize: 20, fontWeight: FontWeight.w700, color: pal.text)),
                                const SizedBox(height: 6),
                                Text(
                                    context.tr('Add photos to hide them from your gallery.',
                                        'Thêm ảnh để ẩn khỏi thư viện.'),
                                    style: TextStyle(color: pal.sec)),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final it = items[i];
                            final on = _sel.contains(it.id);
                            return GestureDetector(
                              onTap: () => setState(() {
                                HapticFeedback.selectionClick();
                                if (!_sel.remove(it.id)) _sel.add(it.id);
                              }),
                              onLongPress: () {
                                if (it.video) {
                                  _msg(context.tr('Restore the video to your library to play it.',
                                      'Hãy khôi phục video về thư viện để xem.'));
                                } else {
                                  Navigator.of(context).push(softRoute<void>(_VaultViewer(item: it)));
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _VaultThumb(item: it),
                                    if (on) Container(color: const Color(0x66000000)),
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: on ? AppColors.accent : Colors.black38,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: on
                                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: chosen.isEmpty
                      ? PillButton(
                          label: context.tr('Add photos', 'Thêm ảnh'),
                          icon: Icons.add_rounded,
                          onTap: _busy ? null : _add,
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: PillButton(
                                label: context.tr('Restore ${chosen.length}', 'Khôi phục ${chosen.length}'),
                                onTap: _busy ? null : () => _restore(chosen),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: PillButton(
                                label: context.tr('Delete', 'Xoá'),
                                danger: true,
                                onTap: _busy ? null : () => _delete(chosen),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VaultThumb extends StatefulWidget {
  final VaultItem item;
  const _VaultThumb({required this.item});

  @override
  State<_VaultThumb> createState() => _VaultThumbState();
}

class _VaultThumbState extends State<_VaultThumb> {
  late Future<Uint8List?> _f = context.read<VaultProvider>().thumbFor(widget.item);

  @override
  void didUpdateWidget(_VaultThumb old) {
    super.didUpdateWidget(old);
    if (old.item.id != widget.item.id || old.item.enc != widget.item.enc) {
      _f = context.read<VaultProvider>().thumbFor(widget.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final video = widget.item.video;
    return FutureBuilder<Uint8List?>(
      future: _f,
      builder: (context, snap) {
        final d = snap.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: pal.chip),
            if (d != null) Image.memory(d, fit: BoxFit.cover, gaplessPlayback: true),
            if (video)
              Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    size: 34, color: d == null ? pal.sec : Colors.white70),
              ),
          ],
        );
      },
    );
  }
}

/// Opt-in biometric unlock switch (hidden when the device has no biometrics enrolled).
class _BioRow extends StatefulWidget {
  const _BioRow();

  @override
  State<_BioRow> createState() => _BioRowState();
}

class _BioRowState extends State<_BioRow> {
  late final Future<bool> _avail = context.read<VaultProvider>().bioAvailable();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final v = context.watch<VaultProvider>();
    return FutureBuilder<bool>(
      future: _avail,
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.fingerprint_rounded, size: 24, color: pal.accentText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.tr('Unlock with biometrics', 'Mở khoá bằng sinh trắc học'),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: pal.text)),
              ),
              Switch(
                value: v.bioEnabled,
                onChanged: (on) async {
                  final ok = await v.setBio(
                      on, context.trr('Confirm it is you', 'Xác nhận đây là bạn'));
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.trr('Could not verify biometrics.',
                            'Không xác thực được sinh trắc học.'))));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Full-screen photo viewer: decrypts to a temp file only while this screen is open.
class _VaultViewer extends StatefulWidget {
  final VaultItem item;
  const _VaultViewer({required this.item});

  @override
  State<_VaultViewer> createState() => _VaultViewerState();
}

class _VaultViewerState extends State<_VaultViewer> {
  late final VaultProvider _vault = context.read<VaultProvider>();
  late final Future<File> _f = _vault.openPlain(widget.item);

  @override
  void dispose() {
    _vault.clearTemp();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.item.name, style: const TextStyle(fontSize: 15)),
      ),
      body: FutureBuilder<File>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
                child: Text(context.tr('Could not open this photo.', 'Không mở được ảnh này.'),
                    style: const TextStyle(color: Colors.white70)));
          }
          final f = snap.data;
          if (f == null) return const Center(child: CircularProgressIndicator());
          return InteractiveViewer(
            maxScale: 5,
            child: Center(child: Image.file(f, fit: BoxFit.contain)),
          );
        },
      ),
    );
  }
}

/// Multi-select grid of library assets to hide.
class _VaultPicker extends StatefulWidget {
  const _VaultPicker();

  @override
  State<_VaultPicker> createState() => _VaultPickerState();
}

class _VaultPickerState extends State<_VaultPicker> {
  final Set<String> _sel = <String>{};

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lib = context.watch<LibraryProvider>();
    final assets = lib.assets.take(1500).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Choose photos to hide', 'Chọn ảnh để ẩn')),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
        itemCount: assets.length,
        itemBuilder: (context, i) {
          final a = assets[i];
          final on = _sel.contains(a.id);
          return GestureDetector(
            onTap: () => setState(() {
              if (!_sel.remove(a.id)) _sel.add(a.id);
            }),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(opacity: on ? 0.55 : 1, child: PhotoThumb(asset: a, size: 300)),
                  if (a.type == AssetType.video)
                    Positioned(left: 5, bottom: 5, child: Tag('▶ ${fmtDuration(a.duration)}')),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: on ? AppColors.accent : Colors.black38,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: on ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: PillButton(
            label: _sel.isEmpty
                ? context.tr('Tap photos to select', 'Chạm ảnh để chọn')
                : context.tr('Hide ${_sel.length} items', 'Ẩn ${_sel.length} mục'),
            onTap: _sel.isEmpty
                ? null
                : () => Navigator.of(context)
                    .pop(assets.where((a) => _sel.contains(a.id)).toList()),
          ),
        ),
      ),
    );
  }
}
