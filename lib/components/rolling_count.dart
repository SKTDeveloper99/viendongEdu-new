import 'package:flutter/material.dart';

import '../theme/vd_motion.dart';

/// A number that rolls up when it changes (Overlord home): the new value slides
/// in from below over VdMotion.standard; under Reduce Motion it just changes.
class RollingCount extends StatelessWidget {
  final String text;
  final TextStyle style;
  const RollingCount(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    final m = VdMotion.of(context);
    return AnimatedSwitcher(
      duration: m.standard,
      transitionBuilder: (child, anim) => ClipRect(
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.6),
            end: Offset.zero,
          ).chain(CurveTween(curve: VdMotion.curve)).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
      child: Text(
        text,
        key: ValueKey(text),
        style: style,
        textAlign: TextAlign.center,
      ),
    );
  }
}
