import 'package:flutter/material.dart';
import 'vd_fade_in.dart';
import 'vd_pressable.dart';
import '../theme/vd_tokens.dart';

/// Grid shape of the home menus: 4 columns from 360 px wide, else 3.
SliverGridDelegate menuGridDelegate(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= 360;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: wide ? 4 : 3,
    mainAxisExtent: 96,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  );
}

class MenuItemWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Position in the grid; drives the entrance stagger.
  final int index;

  const MenuItemWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    return VdFadeIn(
      index: index,
      child: VdPressable(child: _tile(context)),
    );
  }

  Widget _tile(BuildContext context) {
    final t = context.vd;
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: t.primary, size: 22),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
