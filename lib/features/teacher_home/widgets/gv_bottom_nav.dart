import 'package:flutter/material.dart';

import '../../../components/vd_nav_item.dart';
import '../../../theme/vd_tokens.dart';

/// Bottom bar: Trang chủ (0) / Cá nhân (1).
class GvBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  const GvBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vd.surface,
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: context.vd.surface,
            border: Border(top: BorderSide(color: context.vd.hairline)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              VdNavItem(
                icon: Icons.dashboard_rounded,
                label: 'Trang chủ',
                selected: currentIndex == 0,
                horizontalPadding: 32,
                onTap: () => onSelect(0),
              ),
              VdNavItem(
                icon: Icons.person_rounded,
                label: 'Cá nhân',
                selected: currentIndex == 1,
                horizontalPadding: 32,
                onTap: () => onSelect(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
