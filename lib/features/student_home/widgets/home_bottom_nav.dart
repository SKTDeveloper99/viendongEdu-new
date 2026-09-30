import 'package:flutter/material.dart';

import '../../../theme/vd_theme.dart';

/// Bottom bar: Trang chủ (0) / centre QR button (1) / Cá nhân (2).
class HomeBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  const HomeBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 64,
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Trang chủ',
                  selected: currentIndex == 0,
                  onTap: () => onSelect(0),
                ),
                const SizedBox(width: 64),
                NavItem(
                  icon: Icons.person_rounded,
                  label: 'Cá nhân',
                  selected: currentIndex == 2,
                  onTap: () => onSelect(2),
                ),
              ],
            ),
          ),
          Positioned(
            top: -24,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => onSelect(1),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: currentIndex == 1
                        ? const LinearGradient(
                            colors: [Colors.white, Colors.white],
                          )
                        : const LinearGradient(
                            colors: [VdColors.headerTop, VdColors.headerBottom],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    shape: BoxShape.circle,
                    border: Border.all(color: VdColors.terracotta, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.qr_code_rounded,
                    size: 34,
                    color: currentIndex == 1
                        ? VdColors.terracotta
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? VdColors.terracotta : Colors.grey,
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? VdColors.terracotta : Colors.grey,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
