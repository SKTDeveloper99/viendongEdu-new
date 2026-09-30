import 'package:flutter/material.dart';

import '../../../components/menu_item.dart';
import '../../teacher_attendance/widgets/pending_send_badge.dart';

/// Four navigation tiles of the teacher home.
class MenuGrid extends StatelessWidget {
  const MenuGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      gridDelegate: menuGridDelegate(context),
      children: [
        MenuItemWidget(
          index: 0,
          icon: Icons.calendar_today,
          label: 'Lịch dạy',
          onTap: () => Navigator.pushNamed(context, '/gv_schedule'),
        ),
        MenuItemWidget(
          index: 1,
          icon: Icons.assignment_outlined,
          label: 'Lịch thi',
          onTap: () => Navigator.pushNamed(context, '/gv_lichthi'),
        ),
        MenuItemWidget(
          index: 2,
          icon: Icons.manage_accounts_outlined,
          label: 'Lớp của tôi',
          onTap: () => Navigator.pushNamed(context, '/gv_quanly_lop'),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: MenuItemWidget(
                index: 3,
                icon: Icons.fact_check_outlined,
                label: 'Điểm danh',
                onTap: () => Navigator.pushNamed(context, '/ems_attendance_gv'),
              ),
            ),
            const Positioned(top: 2, right: 2, child: PendingSendBadge()),
          ],
        ),
      ],
    );
  }
}
