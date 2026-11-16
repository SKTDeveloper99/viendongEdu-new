import 'package:flutter/services.dart';
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
  Offset? _at;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final m = VdMotion.of(context);
    return Listener(
      onPointerDown: (e) {
        _at = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        // A drag (scrolling past the tile) is not a press.
        if (_at != null && (e.position - _at!).distance > 12) _set(false);
      },
      onPointerUp: (e) {
        // A real tap answers with a light haptic (Overlord home).
        if (_down && _at != null && (e.position - _at!).distance <= 12) {
          HapticFeedback.selectionClick();
        }
        _at = null;
        _set(false);
      },
      onPointerCancel: (_) {
        _at = null;
        _set(false);
      },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: m.press,
        curve: VdMotion.curve,
        // Visible pressed tint as well as the scale, readable at arm's length.
        child: AnimatedOpacity(
          opacity: _down ? 0.78 : 1,
          duration: m.press,
          child: widget.child,
        ),
      ),
    );
  }
}
