import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';

/// Gradient header of the home tab: name, teacher code, "Cơ hữu" badge and the
/// notification bell with its unread count.
class HomeHeader extends StatelessWidget {
  final String name;
  final String code;
  final bool isCoHuu;
  final int unreadCount;
  final VoidCallback onBell;
  const HomeHeader({
    super.key,
    required this.name,
    required this.code,
    required this.isCoHuu,
    required this.unreadCount,
    required this.onBell,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.vd.headerTop, context.vd.headerBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.vd.onHeader.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: context.vd.onHeader, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.vd.onHeader,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mã GV: $code',
                  style: TextStyle(fontSize: 13, color: context.vd.onHeader.withValues(alpha: 0.7)),
                ),
                if (isCoHuu) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.vd.onHeader.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Cơ hữu',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.vd.onHeader,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onBell,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.vd.onHeader.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: context.vd.onHeader,
                    size: 24,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: context.vd.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: TextStyle(
                          color: context.vd.onHeader,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
