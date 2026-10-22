import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../components/vd_nav_item.dart';
import '../../../theme/vd_tokens.dart';

/// How far the centre QR button rises above the bar. The dashboard scroll
/// area keeps this much (+16) free at its end so nothing is covered.
const double homeNavOverhang = 24;

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
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ColoredBox(
        color: context.vd.surface,
        child: SafeArea(
          top: false,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 64),
                decoration: BoxDecoration(
                  color: context.vd.surface,
                  border: Border(top: BorderSide(color: context.vd.hairline)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(0),
                        child: Semantics(
                          sortKey: const OrdinalSortKey(0),
                          child: VdNavItem(
                            icon: Icons.dashboard_rounded,
                            label: 'Trang chủ',
                            selected: currentIndex == 0,
                            onTap: () => onSelect(0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 72),
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: Semantics(
                          sortKey: const OrdinalSortKey(2),
                          child: VdNavItem(
                            icon: Icons.person_rounded,
                            label: 'Cá nhân',
                            selected: currentIndex == 2,
                            onTap: () => onSelect(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -homeNavOverhang,
                left: 0,
                right: 0,
                child: Center(
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: Semantics(
                      sortKey: const OrdinalSortKey(1),
                      label: 'Mã QR cá nhân',
                      button: true,
                      selected: currentIndex == 1,
                      child: InkWell(
                        onTap: () => onSelect(1),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: currentIndex == 1
                                ? LinearGradient(
                                    colors: [
                                      context.vd.surface,
                                      context.vd.surface,
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      context.vd.headerTop,
                                      context.vd.headerBottom,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.vd.primary,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.vd.shadow,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.qr_code_rounded,
                            size: 34,
                            color: currentIndex == 1
                                ? context.vd.primary
                                : context.vd.onHeader,
                          ),
                        ),
                      ),
                    ),
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
