import 'package:flutter/material.dart';

/// App mark: two rounded squares with a check (64x64 viewBox of the prototype).
class AppMark extends StatelessWidget {
  final double size; // outer tile size
  final double radius;
  const AppMark({super.key, required this.size, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A93FF), Color(0xFF0057C2)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x610071E3), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.57,
          height: size * 0.57,
          child: CustomPaint(painter: _MarkPainter()),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 64;
    RRect r(double x, double y) => RRect.fromRectAndRadius(
        Rect.fromLTWH(x * k, y * k, 34 * k, 34 * k), Radius.circular(8 * k));
    canvas.drawRRect(r(14, 18), Paint()..color = const Color(0x59FFFFFF));
    canvas.drawRRect(r(18, 12), Paint()..color = Colors.white);
    final path = Path()
      ..moveTo(28 * k, 29 * k)
      ..lineTo(34 * k, 35 * k)
      ..lineTo(45 * k, 23 * k);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF0057C2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
