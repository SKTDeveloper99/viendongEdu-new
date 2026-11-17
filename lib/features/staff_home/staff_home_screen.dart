import 'package:flutter/material.dart';

import '../../core/crm_web/crm_web_target.dart';
import '../../services/app_session.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import '../bell/bell_screen.dart';
import '../nhom/nhom_screens.dart';
import '../work/my_work_screen.dart';
import '../work_home/app_me_api.dart';

part 'staff_home_screen_parts_1.dart';

/// One tile of a home built from what the server says the person holds.
/// [native] false = the tile opens a Viva page inside the app.
class StaffTile {
  final IconData icon;
  final String label;
  final bool native;
  final int? count;
  final VoidCallback onTap;
  const StaffTile(
    this.icon,
    this.label, {
    required this.native,
    this.count,
    required this.onTap,
  });
}

/// The office tiles, shared by the office home and the teacher home of a
/// teacher with office duties.
List<StaffTile> staffTiles(
  BuildContext context,
  Map<String, dynamic>? counts, {
  VoidCallback? refresh,
}) {
  int? c(String k) => counts == null
      ? null
      : (counts[k] is int ? counts[k] as int : int.tryParse('${counts[k]}'));
  Future<void> push(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    refresh?.call();
  }

  final s = AppSession.instance;
  return [
    StaffTile(
      Icons.task_alt,
      'Việc của tôi',
      native: true,
      count: c('received_open'),
      onTap: () => push(const MyWorkScreen()),
    ),
    if (s.isStaff || s.canAssign)
      StaffTile(
        Icons.fact_check_outlined,
        'Chờ duyệt',
        native: true,
        count: c('to_review'),
        onTap: () => push(const MyWorkScreen(initialTab: 1)),
      ),
    StaffTile(
      Icons.notifications_none,
      'Thông báo',
      native: true,
      count: c('bell_work_unread'),
      onTap: () => push(const BellScreen()),
    ),
    StaffTile(
      Icons.event_note,
      'Lịch tuần',
      native: false,
      onTap: () =>
          Navigator.pushNamed(context, const CrmTarget.week().routeName),
    ),
    StaffTile(
      Icons.groups_2_outlined,
      'Nhóm',
      native: true,
      onTap: () => push(const NhomListScreen()),
    ),
    StaffTile(
      Icons.description_outlined,
      'Công văn',
      native: false,
      onTap: () =>
          Navigator.pushNamed(context, const CrmTarget.congVan().routeName),
    ),
    StaffTile(
      Icons.edit_note,
      'Nhật ký làm việc',
      native: false,
      onTap: () =>
          Navigator.pushNamed(context, const CrmTarget.workLog().routeName),
    ),
  ];
}

class StaffTileView extends StatelessWidget {
  final StaffTile tile;
  const StaffTileView(this.tile, {super.key});

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final n = tile.count ?? 0;
    return Material(
      color: vd.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: tile.onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: vd.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(tile.icon, color: vd.accent),
                  const Spacer(),
                  if (n > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: vd.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$n',
                        style: TextStyle(
                          color: vd.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                tile.label,
                style: TextStyle(fontWeight: FontWeight.w600, color: vd.ink),
              ),
              const SizedBox(height: 2),
              Text(
                tile.native ? 'trong app' : 'trang Viva',
                style: TextStyle(
                  fontSize: 11,
                  color: tile.native ? vd.success : vd.warning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home for an office account ("/staff_home").
class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}
