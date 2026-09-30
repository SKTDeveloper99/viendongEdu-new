import 'package:flutter/material.dart';

import '../../../components/home_header_bar.dart';
import '../student_home_view_model.dart';

/// Dashboard header: greeting, name, MSSV / class-code chips and the bell.
class HomeHeader extends StatelessWidget {
  final StudentHomeViewModel vm;
  const HomeHeader({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return HomeHeaderBar(
      now: vm.now,
      name: vm.name,
      chips: ['MSSV: ${vm.mssv}', vm.classCode],
      unreadCount: vm.unreadCount,
      onBell: () async {
        // Bảng tin CRM là nơi duy nhất học viên đọc thông báo kể từ khi gỡ
        // backend Vercel “noti-backend-eight” (bot A5, 2026-09-25) — không còn
        // một danh sách "Thông báo" riêng cho học viên.
        await Navigator.pushNamed(context, '/student_board');
        vm.loadUnreadCount();
      },
    );
  }
}
