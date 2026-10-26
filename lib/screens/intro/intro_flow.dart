import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/common.dart';
import 'auth_screen.dart';
import 'logo.dart';

/// Splash -> onboarding -> auth -> pre-permission, driven by [SessionProvider.stage].
class IntroFlow extends StatelessWidget {
  const IntroFlow({super.key});

  @override
  Widget build(BuildContext context) {
    final stage = context.select<SessionProvider, FlowStage>((s) => s.stage);
    final Widget page;
    switch (stage) {
      case FlowStage.splash:
        page = const _Splash(key: ValueKey('splash'));
        break;
      case FlowStage.onboarding:
        page = const _Onboarding(key: ValueKey('onb'));
        break;
      case FlowStage.auth:
        page = const AuthScreen(key: ValueKey('auth'));
        break;
      default:
        page = const _PermissionIntro(key: ValueKey('perm'));
    }
    return Scaffold(
      backgroundColor: context.pal.bg,
      body: GlowBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: page,
        ),
      ),
    );
  }
}

/// Gentle bobbing used by the logo and the illustration cards.
class Floaty extends StatefulWidget {
  final Widget child;
  final double angle; // degrees
  final double phase; // 0..1
  const Floaty({super.key, required this.child, this.angle = 0, this.phase = 0});

  @override
  State<Floaty> createState() => _FloatyState();
}

class _FloatyState extends State<Floaty> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
    value: widget.phase,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -8 * Curves.easeInOut.transform(_c.value)),
        child: Transform.rotate(angle: widget.angle * math.pi / 180, child: child),
      ),
      child: widget.child,
    );
  }
}

const List<List<Color>> _photoGrads = [
  [Color(0xFFFFB88C), Color(0xFF2F4858)],
  [Color(0xFF7EC8E3), Color(0xFF3C6E47)],
  [Color(0xFF2B2D5B), Color(0xFF6A5ACD)],
  [Color(0xFFA8E6CF), Color(0xFF7A9E7E)],
  [Color(0xFFF6D6FF), Color(0xFF8A6FA8)],
];

BoxDecoration _photoBox(int i, double radius, {Border? border, double blur = 30, double dy = 14}) {
  final g = _photoGrads[i % _photoGrads.length];
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g),
    border: border,
    boxShadow: [BoxShadow(color: const Color(0x40000000), blurRadius: blur, offset: Offset(0, dy))],
  );
}

/// Centres [child] vertically, and lets it scroll when the screen is too short to fit it.
class _CenterScroll extends StatelessWidget {
  final Widget child;
  const _CenterScroll({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 44),
        child: Column(
          children: [
            Expanded(
              child: _CenterScroll(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Floaty(angle: -4, child: AppMark(size: 112, radius: 30)),
                  const SizedBox(height: 28),
                  Text('Photo Cleaner',
                      style: TextStyle(
                          fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: pal.text)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 290),
                    child: Text(
                      context.tr('Find duplicates and clutter. Keep the moments that matter.',
                          'Tìm ảnh trùng và ảnh thừa. Giữ lại những khoảnh khắc quan trọng.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, height: 24 / 17, color: pal.sec),
                    ),
                  ),
                ],
                ),
              ),
            ),
            PillButton(
              label: context.tr('Get started', 'Bắt đầu'),
              onTap: () => context.read<SessionProvider>().startFromSplash(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Onboarding extends StatefulWidget {
  const _Onboarding({super.key});

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final session = context.read<SessionProvider>();
    final titles = [
      context.tr('Review in batches', 'Duyệt theo lô'),
      context.tr('Duplicates, found for you', 'Ảnh trùng, tìm sẵn cho bạn'),
      context.tr('30 days to change your mind', '30 ngày để đổi ý'),
    ];
    final descs = [
      context.tr(
          'Similar shots are grouped. Keep the best of each group and clear the rest in one go. Nothing is deleted until you confirm.',
          'Ảnh giống nhau được gom nhóm. Giữ tấm đẹp nhất mỗi nhóm và xoá phần còn lại cùng lúc. Không có gì bị xoá cho đến khi bạn xác nhận.'),
      context.tr('We group exact copies and similar shots, and keep the best one by default.',
          'Ứng dụng gom ảnh giống hệt và ảnh tương tự, mặc định giữ lại tấm đẹp nhất.'),
      context.tr('Deleted photos go to Recently Deleted, so you can restore them for 30 days.',
          'Ảnh đã xoá nằm trong Đã xoá gần đây, bạn có thể khôi phục trong 30 ngày.'),
    ];
    final last = _i == 2;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          children: [
            SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: session.finishOnboarding,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(context.tr('Skip', 'Bỏ qua'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: pal.sec)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                // Scales the picture down on short screens instead of overflowing.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: KeyedSubtree(key: ValueKey(_i), child: _illustration(_i)),
                  ),
                ),
              ),
            ),
            // A minimum (not a fixed) height: long Vietnamese text grows the block, short text
            // keeps the layout from jumping between pages.
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(titles[_i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 28,
                          height: 34 / 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: pal.text)),
                  const SizedBox(height: 10),
                  Text(descs[_i],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, height: 24 / 17, color: pal.sec)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var d = 0; d < 3; d++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: d == _i ? 26 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(d == _i ? 1 : 0.28),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            PillButton(
              label: last ? context.tr('Get started', 'Bắt đầu') : context.tr('Next', 'Tiếp'),
              onTap: () {
                if (last) {
                  session.finishOnboarding();
                } else {
                  setState(() => _i++);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _illustration(int i) {
    final pal = context.pal;
    switch (i) {
      case 0:
        return SizedBox(
          width: 280,
          height: 300,
          child: Stack(
            children: [
              Positioned(
                left: 10,
                top: 40,
                child: Floaty(
                    angle: -10,
                    phase: 0.2,
                    child: Container(width: 170, height: 226, decoration: _photoBox(0, 22))),
              ),
              Positioned(
                right: 6,
                top: 20,
                child: Floaty(
                    angle: 8,
                    phase: 0.5,
                    child: Container(width: 170, height: 226, decoration: _photoBox(1, 22))),
              ),
              Positioned(
                left: 50,
                top: 56,
                child: Floaty(
                  angle: -2,
                  child: Container(
                    width: 180,
                    height: 240,
                    decoration: _photoBox(2, 24, blur: 38, dy: 18),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Transform.rotate(
                          angle: -12 * math.pi / 180,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xD9FFFFFF),
                              border: Border.all(color: const Color(0xFFFF3B4E), width: 3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(context.tr('DELETE', 'XOÁ'),
                                style: const TextStyle(
                                    color: Color(0xFFFF3B4E), fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 1:
        return SizedBox(
          width: 280,
          height: 300,
          child: Stack(
            children: [
              Positioned(
                left: 20,
                top: 36,
                child: Floaty(
                    angle: -6,
                    phase: 0.3,
                    child: Container(width: 160, height: 210, decoration: _photoBox(3, 22))),
              ),
              Positioned(
                left: 84,
                top: 62,
                child: Floaty(
                  angle: 5,
                  phase: 0.7,
                  child: Container(
                    width: 160,
                    height: 210,
                    decoration: _photoBox(3, 22, border: Border.all(color: pal.bg, width: 3), dy: 18),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(99)),
                  child: const Text('x2',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              Positioned(
                left: 100,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: pal.sheet,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: pal.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 16, color: pal.ok),
                      const SizedBox(width: 6),
                      Text(context.tr('Best one kept', 'Giữ tấm đẹp nhất'),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: pal.text)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 0.78),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => CustomPaint(
                  size: const Size(240, 240),
                  painter: _RingPainter(progress: v, track: pal.line),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('30',
                      style: TextStyle(
                          fontSize: 64,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -2,
                          color: pal.text)),
                  const SizedBox(height: 4),
                  Text(context.tr('days', 'ngày'),
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: pal.sec)),
                ],
              ),
            ],
          ),
        );
    }
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  _RingPainter({required this.progress, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const r = 104.0;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = track;
    canvas.drawCircle(c, r, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accent;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, progress * 2 * math.pi, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.track != track;
}

class _PermissionIntro extends StatelessWidget {
  const _PermissionIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          children: [
            Expanded(
              child: _CenterScroll(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: pal.card,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: pal.line),
                    ),
                    child: Icon(Icons.photo_outlined, size: 48, color: pal.accentText),
                  ),
                  const SizedBox(height: 26),
                  Text(context.tr('Allow access to your photos', 'Cho phép truy cập ảnh'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: pal.text)),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      context.tr(
                          'Photo Cleaner needs to read your library to find duplicates and blurry shots.',
                          'Photo Cleaner cần đọc thư viện để tìm ảnh trùng và ảnh mờ.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, height: 24 / 17, color: pal.sec),
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user_outlined, size: 22, color: pal.ok),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr('Analysis runs on your device. Photos are never uploaded.',
                                'Phân tích diễn ra ngay trên máy. Ảnh không bao giờ được tải lên.'),
                            style: TextStyle(fontSize: 15, height: 20 / 15, color: pal.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ),
              ),
            ),
            PillButton(
              label: context.tr('Allow access to Photos', 'Cho phép truy cập Ảnh'),
              onTap: () => context.read<SessionProvider>().allowPhotos(),
            ),
          ],
        ),
      ),
    );
  }
}
