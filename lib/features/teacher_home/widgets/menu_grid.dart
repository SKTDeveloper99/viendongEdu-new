import 'package:flutter/material.dart';

import '../../../components/menu_item.dart';
import '../../../core/crm_web/crm_web_target.dart';
import '../../teacher_attendance/widgets/pending_send_badge.dart';
import '../../teacher_conversations/widgets/messages_tile.dart';
import '../../../services/app_session.dart';
import '../../staff_home/staff_home_screen.dart';

/// Navigation tiles of the teacher home.
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
        const MessagesTile(index: 4),
        MenuItemWidget(
          index: 5,
          icon: Icons.groups_outlined,
          label: 'Sinh viên của tôi',
          onTap: () => Navigator.pushNamed(context, '/gv_sinh_vien'),
        ),
        MenuItemWidget(
          index: 6,
          icon: Icons.how_to_reg_outlined,
          label: 'Danh sách thi',
          onTap: () => Navigator.pushNamed(context, '/gv_danh_sach_thi'),
        ),
        // Overlord slice: Việc của tôi is native (one piece on one screen).
        MenuItemWidget(
          index: 7,
          icon: Icons.task_alt,
          label: 'Việc của tôi',
          onTap: () => Navigator.pushNamed(context, '/work'),
        ),
        MenuItemWidget(
          index: 8,
          icon: Icons.groups_2_outlined,
          label: 'Nhóm',
          onTap: () =>
              Navigator.pushNamed(context, CrmTarget.groups().routeName),
        ),
        // A teacher with office duties also gets the office tiles the
        // server says she holds (one account, one sign-in).
        if (AppSession.instance.isStaff)
          for (final (i, t)
              in staffTiles(context, null)
                  .where((t) => t.label != 'Việc của tôi' && t.label != 'Nhóm')
                  .indexed)
            MenuItemWidget(
              index: 9 + i,
              icon: t.icon,
              label: t.label,
              onTap: t.onTap,
            ),
      ],
    );
  }
}
