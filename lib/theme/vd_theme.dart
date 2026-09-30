import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vd_tokens.dart';

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
class VdTheme {
  VdTheme._();

  static const fontFamily = 'BeVietnamPro';

  static const cardRadius = 18.0;

  /// Soft card shadow — barely-there, warm.
  static List<BoxShadow> cardShadowOf(VdTokens t) => [
        BoxShadow(
          color: t.shadow,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static ThemeData light() => _build(VdTokens.light, Brightness.light);

  static ThemeData dark() => _build(VdTokens.dark, Brightness.dark);

  static ThemeData _build(VdTokens t, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      secondary: t.accent,
      onSecondary: t.onPrimary,
      primaryContainer: t.accentSoft,
      onPrimaryContainer: t.ink,
      secondaryContainer: t.accentSoft,
      onSecondaryContainer: t.ink,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.inkMuted,
      surfaceContainerHighest: t.surfaceAlt,
      surfaceContainerHigh: t.surfaceAlt,
      surfaceContainer: t.surfaceAlt,
      surfaceContainerLow: t.bg,
      surfaceContainerLowest: t.bg,
      outline: t.inkFaint,
      outlineVariant: t.hairline,
      error: t.danger,
      onError: t.onPrimary,
      errorContainer: t.dangerSoft,
      onErrorContainer: t.danger,
      shadow: t.shadow,
      scrim: t.scrim,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.bg,
      extensions: <ThemeExtension<dynamic>>[t],
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: t.ink,
        displayColor: t.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.headerTop,
        foregroundColor: t.onHeader,
        surfaceTintColor: Colors.transparent,
        // Header is always a dark terracotta band, so the status-bar icons
        // are light in both themes; the navigation bar follows the surface.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: t.surface,
          systemNavigationBarIconBrightness:
              brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: t.shadow,
      ),
      dividerTheme: DividerThemeData(color: t.hairline),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: t.surface,
        hintStyle: TextStyle(color: t.inkFaint),
        labelStyle: TextStyle(color: t.inkMuted),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.danger),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.ink,
        contentTextStyle: TextStyle(color: t.bg),
        actionTextColor: t.accent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceAlt,
        selectedColor: t.accentSoft,
        labelStyle: TextStyle(color: t.ink),
        side: BorderSide(color: t.hairline),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.accentSoft,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? t.primary : t.inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            color: s.contains(WidgetState.selected) ? t.primary : t.inkMuted,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: t.ink,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: t.inkMuted,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        modalBackgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: t.scrim,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.hairline,
        circularTrackColor: t.hairline,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onPrimary : t.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : t.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : t.inkFaint,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : null,
        ),
        checkColor: WidgetStatePropertyAll(t.onPrimary),
        side: BorderSide(color: t.inkMuted, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : t.inkMuted,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.primary,
        selectionColor: t.primary.withValues(alpha: 0.35),
        selectionHandleColor: t.primary,
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
      painter: _SwooshPainter(color ?? context.vd.accent, context.vd.primary),
    );
  }
}

class _SwooshPainter extends CustomPainter {
  final Color color;
  final Color from;
  _SwooshPainter(this.color, this.from);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [from, color],
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
  bool shouldRepaint(covariant _SwooshPainter old) => old.color != color || old.from != from;
}
