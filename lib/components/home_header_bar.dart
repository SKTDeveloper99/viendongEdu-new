import 'package:flutter/material.dart';

import '../core/greeting.dart';
import '../theme/vd_tokens.dart';
import 'vd_pressable.dart';

/// Compact home header on the header gradient: greeting by device time, name,
/// identity chips (MSSV / teacher code / Cơ hữu) and the bell with its badge.
class HomeHeaderBar extends StatelessWidget {
  final DateTime now;
  final String name;
  final List<String> chips;
  final int unreadCount;
  final VoidCallback onBell;
  const HomeHeaderBar({
    super.key,
    required this.now,
    required this.name,
    required this.chips,
    required this.unreadCount,
    required this.onBell,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, (top < 24 ? 24 : top) + 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.headerTop, t.headerBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greetingFor(now),
                  style: TextStyle(
                    fontSize: 13,
                    color: t.onHeader.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: t.onHeader,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final c in chips) _chip(t, c)],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _bell(t),
        ],
      ),
    );
  }

  Widget _chip(VdTokens t, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: t.onHeader.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: t.onHeader,
      ),
    ),
  );

  Widget _bell(VdTokens t) => VdPressable(
    child: Semantics(
      button: true,
      label: unreadCount > 0 ? 'Thông báo, $unreadCount chưa đọc' : 'Thông báo',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onBell,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: t.onHeader.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: t.onHeader,
                    size: 24,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: BoxDecoration(
                        color: t.danger,
                        shape: BoxShape.circle,
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: t.onHeader,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
