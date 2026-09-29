import 'package:flutter/material.dart';

/// Viễn Đông "sang trọng ấm áp" (warm-luxury) palette.
///
/// Design principles honored here:
///  * NO gold-metal — warmth comes from whitespace + paper material, not shine.
///  * Orange is an ACCENT only (time labels, active-nav, swoosh) — never body text.
///  * Body text is espresso; buttons are SOLID terracotta/brick fills.
///  * The "swoosh" is the signature motif (loading, active-nav underline, transitions).
///
/// Font: BeVietnamPro is used everywhere (function AND display hierarchy).
/// Cormorant Garamond is deliberately NOT used because it renders the
/// Vietnamese circumflex (ô) incorrectly on dynamic text.
class VdColors {
  VdColors._();

  static const cream = Color(0xFFFAF7F2); // Kem — screen background
  static const paper = Color(0xFFF4EDE1); // Giấy — card fills
  static const espresso = Color(0xFF231E1A); // Cà phê — body text
  static const orange = Color(0xFFE8743C); // Cam — accent
  static const terracotta = Color(0xFFA8471A); // Đất nung — button / secondary
  static const brick = Color(0xFF8C2B18); // Gạch — headings / header band

  // Faculty header band gradient (deep brick → warm brick).
  static const headerTop = Color(0xFF94301B);
  static const headerBottom = Color(0xFF7C2415);

  // Ink alphas over cream/paper.
  static const hair = Color(0x1A231E1A); // rgba(35,30,26,0.10)
  static const ink60 = Color(0x99231E1A); // rgba(35,30,26,0.60)
  static const ink45 = Color(0x73231E1A); // rgba(35,30,26,0.45)

  // Cream alphas over the header band.
  static const cream78 = Color(0xC7FAF7F2); // rgba(250,247,242,0.78)
  static const cream58 = Color(0x94FAF7F2); // rgba(250,247,242,0.58)

  // Orange tint used for chips / soft accents on paper.
  static const orangeTint = Color(0x24E8743C); // rgba(232,116,60,0.14)
}

class VdTheme {
  VdTheme._();

  static const fontFamily = 'BeVietnamPro';

  /// Soft card shadow — barely-there, warm.
  static const cardShadow = [
    BoxShadow(
      color: Color(0x0F231E1A), // rgba(35,30,26,0.06)
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const cardRadius = 18.0;

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: VdColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: VdColors.terracotta,
        primary: VdColors.terracotta,
        secondary: VdColors.orange,
        surface: VdColors.paper,
        brightness: Brightness.light,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: VdColors.espresso,
        displayColor: VdColors.espresso,
      ),
    );
  }
}

/// Signature swoosh — a small terracotta→orange curved sweep.
/// Used as the active-nav underline and section accent.
class VdSwoosh extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;
  const VdSwoosh({super.key, this.width = 26, this.height = 4, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SwooshPainter(color ?? VdColors.orange),
    );
  }
}

class _SwooshPainter extends CustomPainter {
  final Color color;
  _SwooshPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [VdColors.terracotta, color],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.5,
        -size.height * 0.6,
        size.width,
        size.height * 0.4,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SwooshPainter old) => old.color != color;
}
