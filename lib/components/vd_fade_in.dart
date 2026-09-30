import 'package:flutter/widgets.dart';

import '../theme/vd_motion.dart';

/// Fades and slides its child up 8 px once, [index] x 30 ms after mount
/// (delay capped at 240 ms). Plays once per widget lifetime; with reduced
/// motion the child is shown immediately.
class VdFadeIn extends StatefulWidget {
  final Widget child;
  final int index;
  const VdFadeIn({super.key, required this.child, this.index = 0});

  @override
  State<VdFadeIn> createState() => _VdFadeInState();
}

class _VdFadeInState extends State<VdFadeIn>
    with SingleTickerProviderStateMixin {
  static const _fadeMs = 220;
  AnimationController? _c;
  Animation<double>? _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final m = VdMotion.of(context);
    if (m.reduced) {
      _c = AnimationController(vsync: this, value: 1);
      _t = _c;
      return;
    }
    final delayMs = m.staggerDelay(widget.index).inMilliseconds;
    final total = delayMs + _fadeMs;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: total));
    _t = CurvedAnimation(
      parent: _c!,
      curve: Interval(delayMs / total, 1, curve: VdMotion.curve),
    );
    _c!.forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t!;
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: t.value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t.value)),
          child: child,
        ),
      ),
    );
  }
}
