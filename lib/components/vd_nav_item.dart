import 'package:flutter/material.dart';

import '../theme/vd_tokens.dart';
import 'vd_pressable.dart';

/// One bottom-bar tab: icon over a 12 px label; primary when selected.
class VdNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double horizontalPadding;
  const VdNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    return VdPressable(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? t.primary : t.inkFaint, size: 26),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? t.primary : t.inkMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
