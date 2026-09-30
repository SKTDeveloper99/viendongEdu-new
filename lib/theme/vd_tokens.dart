import 'package:flutter/material.dart';

/// Semantic colour tokens for the whole app. Every colour used in widgets
/// must come from here (`context.vd.X`); see the guard in
/// test/architecture_guard_test.dart.
@immutable
class VdTokens extends ThemeExtension<VdTokens> {
  const VdTokens({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.hairline,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.accentSoft,
    required this.headerTop,
    required this.headerBottom,
    required this.onHeader,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.evening,
    required this.shadow,
    required this.scrim,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color hairline;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color accentSoft;
  final Color headerTop;
  final Color headerBottom;
  final Color onHeader;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;
  final Color evening;
  final Color shadow;
  final Color scrim;

  static const light = VdTokens(
    bg: Color(0xFFFAF7F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF4EDE1),
    ink: Color(0xFF231E1A),
    inkMuted: Color(0xFF6F655D),
    inkFaint: Color(0xFFA1978E),
    hairline: Color(0xFFE8E0D6),
    primary: Color(0xFFA8471A),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFE8743C),
    accentSoft: Color(0xFFFCE9DD),
    headerTop: Color(0xFF94301B),
    headerBottom: Color(0xFF7C2415),
    onHeader: Color(0xFFFAF7F2),
    success: Color(0xFF2E7D32),
    successSoft: Color(0xFFE8F5E9),
    warning: Color(0xFFB26A00),
    warningSoft: Color(0xFFFFF3E0),
    danger: Color(0xFFC62828),
    dangerSoft: Color(0xFFFDECEA),
    info: Color(0xFF1565C0),
    infoSoft: Color(0xFFE3F2FD),
    evening: Color(0xFF7B1FA2),
    shadow: Color(0x1A231E1A),
    scrim: Color(0x8A000000),
  );

  static const dark = VdTokens(
    bg: Color(0xFF16120F),
    surface: Color(0xFF221C18),
    surfaceAlt: Color(0xFF2B241F),
    ink: Color(0xFFF3ECE3),
    inkMuted: Color(0xFFB5A99D),
    inkFaint: Color(0xFF7D7168),
    hairline: Color(0xFF3A322C),
    primary: Color(0xFFE07A45),
    onPrimary: Color(0xFF1A120D),
    accent: Color(0xFFF08A55),
    accentSoft: Color(0xFF3A2519),
    headerTop: Color(0xFF5A1E12),
    headerBottom: Color(0xFF3E150D),
    onHeader: Color(0xFFF3ECE3),
    success: Color(0xFF66BB6A),
    successSoft: Color(0xFF1E2E1F),
    warning: Color(0xFFFFB74D),
    warningSoft: Color(0xFF33261A),
    danger: Color(0xFFEF5350),
    dangerSoft: Color(0xFF3A1D1B),
    info: Color(0xFF64B5F6),
    infoSoft: Color(0xFF1A2733),
    evening: Color(0xFFCE93D8),
    shadow: Color(0x66000000),
    scrim: Color(0xB3000000),
  );

  @override
  VdTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? hairline,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? accentSoft,
    Color? headerTop,
    Color? headerBottom,
    Color? onHeader,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? evening,
    Color? shadow,
    Color? scrim,
  }) {
    return VdTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      hairline: hairline ?? this.hairline,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      headerTop: headerTop ?? this.headerTop,
      headerBottom: headerBottom ?? this.headerBottom,
      onHeader: onHeader ?? this.onHeader,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      evening: evening ?? this.evening,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  VdTokens lerp(ThemeExtension<VdTokens>? other, double t) {
    if (other is! VdTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return VdTokens(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      inkFaint: l(inkFaint, other.inkFaint),
      hairline: l(hairline, other.hairline),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      headerTop: l(headerTop, other.headerTop),
      headerBottom: l(headerBottom, other.headerBottom),
      onHeader: l(onHeader, other.onHeader),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      evening: l(evening, other.evening),
      shadow: l(shadow, other.shadow),
      scrim: l(scrim, other.scrim),
    );
  }
}

extension VdTokensX on BuildContext {
  /// Semantic colour tokens of the active theme. Falls back to the tokens
  /// matching the theme brightness when a bare `MaterialApp` (e.g. in a
  /// widget test) has not registered the extension.
  VdTokens get vd {
    final theme = Theme.of(this);
    return theme.extension<VdTokens>() ??
        (theme.brightness == Brightness.dark ? VdTokens.dark : VdTokens.light);
  }
}
