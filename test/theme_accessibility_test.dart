import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/theme/vd_tokens.dart';

void main() {
  for (final t in [VdTokens.light, VdTokens.dark]) {
    test('semantic text pairs have 4.5:1 contrast (${t.bg})', () {
      double ratio(Color a, Color b) {
        final x = a.computeLuminance();
        final y = b.computeLuminance();
        return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
      }

      for (final surface in [t.bg, t.surface, t.surfaceAlt]) {
        for (final ink in [
          t.ink,
          t.inkMuted,
          t.inkFaint,
          t.primary,
          t.accent,
          t.success,
          t.warning,
          t.danger,
          t.info,
          t.evening,
        ]) {
          expect(
            ratio(ink, surface),
            greaterThanOrEqualTo(4.5),
            reason: '$ink on $surface',
          );
        }
      }
      for (final pair in [
        (t.onPrimary, t.primary),
        (t.onPrimary, t.accent),
        (t.onPrimary, t.success),
        (t.onPrimary, t.warning),
        (t.onPrimary, t.danger),
        (
          t.onHeader,
          Color.alphaBlend(t.onHeader.withValues(alpha: .2), t.headerTop),
        ),
        (
          t.onHeader,
          Color.alphaBlend(t.onHeader.withValues(alpha: .2), t.headerBottom),
        ),
        (t.onHeader, t.headerTop),
        (t.onHeader, t.headerBottom),
        (t.primary, t.accentSoft),
        (t.success, t.successSoft),
        (t.warning, t.warningSoft),
        (t.danger, t.dangerSoft),
        (t.info, t.infoSoft),
      ]) {
        expect(
          ratio(pair.$1, pair.$2),
          greaterThanOrEqualTo(4.5),
          reason: '${pair.$1} on ${pair.$2}',
        );
      }
    });
  }
}
