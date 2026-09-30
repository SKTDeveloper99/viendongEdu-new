import 'package:flutter/widgets.dart';

import '../theme/vd_motion.dart';

/// Scales its child down to 0.97 while a pointer is pressed on it. Purely
/// visual: it never claims the gesture, so the child's own InkWell/onTap
/// behaves exactly as before.
class VdPressable extends StatefulWidget {
  final Widget child;
  const VdPressable({super.key, required this.child});

  @override
  State<VdPressable> createState() => _VdPressableState();
}

class _VdPressableState extends State<VdPressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: VdMotion.of(context).press,
        curve: VdMotion.curve,
        child: widget.child,
      ),
    );
  }
}
