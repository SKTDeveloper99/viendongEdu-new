import 'package:flutter/material.dart';

import '../theme/vd_tokens.dart';

/// The school's crest with its name, for the splash and sign-in screens.
///
/// The crest is the official artwork, cut out with no pixel changed
/// (`assets/brand/crest-circle-870.png`). By the vice-principal's order of
/// 18/11 it is never redrawn, recoloured, tinted, cropped or given an
/// effect, and it always sits on white with clear space around it. In dark
/// mode the lockup therefore keeps its own white plate.
class VdBrandLockup extends StatelessWidget {
  const VdBrandLockup({super.key, this.crestSize = 120, this.plate = true});

  static const crestAsset = 'assets/brand/crest-circle-870.png';
  static const schoolName = 'CAO ĐẲNG VIỄN ĐÔNG';
  static const tagline = 'TRƯỜNG CHẤT LƯỢNG CAO';

  /// Diameter of the crest in logical pixels.
  final double crestSize;

  /// Draw a white plate behind the lockup when the page is not white
  /// (dark mode). A page that is already white needs none.
  final bool plate;

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lockup = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          crestAsset,
          width: crestSize,
          height: crestSize,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'Biểu trưng Cao đẳng Viễn Đông',
        ),
        SizedBox(height: crestSize * 0.2),
        ExcludeSemantics(
          child: Text(
            schoolName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.35,
              letterSpacing: 0.6,
              color: vd.brandInk,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ExcludeSemantics(
          child: Text(
            tagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
              letterSpacing: 2.6,
              color: vd.brandRed,
            ),
          ),
        ),
      ],
    );
    final labelled = Semantics(
      container: true,
      label: 'Cao đẳng Viễn Đông, trường chất lượng cao',
      child: lockup,
    );
    if (!plate || !dark) return labelled;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: vd.brandPaper,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: labelled,
      ),
    );
  }
}
