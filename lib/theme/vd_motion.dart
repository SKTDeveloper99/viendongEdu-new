import 'package:flutter/widgets.dart';

/// Motion timing that respects the platform reduce-motion setting.
///
/// `VdMotion.of(context)` returns a resolver; every animation duration in the
/// app goes through it so that reduced motion shows content immediately.
class VdMotion {
  final bool reduced;
  const VdMotion._(this.reduced);

  static const Duration _quick = Duration(milliseconds: 150);
  static const Duration _standard = Duration(milliseconds: 200);
  static const Duration _press = Duration(milliseconds: 120);
  static const Duration _countUp = Duration(milliseconds: 600);
  static const Duration _stagger = Duration(milliseconds: 30);
  static const Duration _staggerCap = Duration(milliseconds: 240);

  static const Curve curve = Curves.easeOutCubic;
  static const Curve curveInOut = Curves.easeInOutCubic;

  static VdMotion of(BuildContext context) {
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final accessible = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    return VdMotion._(disabled || accessible);
  }

  Duration get quick => reduced ? Duration.zero : _quick;
  Duration get standard => reduced ? Duration.zero : _standard;
  Duration get press => reduced ? Duration.zero : _press;
  Duration get countUp => reduced ? Duration.zero : _countUp;

  /// Entrance delay for the [index]-th item: 30 ms each, capped at 240 ms.
  Duration staggerDelay(int index) {
    if (reduced) return Duration.zero;
    final d = _stagger * (index < 0 ? 0 : index);
    return d > _staggerCap ? _staggerCap : d;
  }
}
