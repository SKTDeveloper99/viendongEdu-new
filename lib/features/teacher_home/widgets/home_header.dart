import 'package:flutter/material.dart';

import '../../../components/home_header_bar.dart';

/// Header of the home tab: greeting, name, teacher code, "Cơ hữu" badge and
/// the notification bell with its unread count.
class HomeHeader extends StatelessWidget {
  final DateTime now;
  final String name;
  final String code;
  final bool isCoHuu;
  final int unreadCount;
  final VoidCallback onBell;
  const HomeHeader({
    super.key,
    required this.now,
    required this.name,
    required this.code,
    required this.isCoHuu,
    required this.unreadCount,
    required this.onBell,
  });

  @override
  Widget build(BuildContext context) {
    return HomeHeaderBar(
      now: now,
      name: name,
      chips: ['Mã GV: $code', if (isCoHuu) 'Cơ hữu'],
      unreadCount: unreadCount,
      onBell: onBell,
    );
  }
}
