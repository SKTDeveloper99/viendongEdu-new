import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/app_session.dart';
import '../services/api_service.dart';
import '../components/menu_item.dart';
import '../components/skeleton.dart';
import 'gv_profile_info_screen.dart';

({String label, Color color}) _gvBuoiInfo(String? b) => switch (b) {
      'S' => (label: 'Sáng', color: const Color(0xFF2196F3)),
      'C' => (label: 'Chiều', color: const Color(0xFFFF9800)),
      'T' => (label: 'Tối', color: const Color(0xFF9C27B0)),
      _ => (label: '', color: Colors.grey),
    };

class GvHomeScreen extends StatefulWidget {
  const GvHomeScreen({super.key});

  @override
  State<GvHomeScreen> createState() => _GvHomeScreenState();
}

class _GvHomeScreenState extends State<GvHomeScreen> {
  int _currentIndex = 0;

  List<Map<String, dynamic>> _todayClasses = [];
  bool _scheduleLoading = true;
  bool _scheduleExpanded = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTodaySchedule();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final id = AppSession.instance.giangVien?.id.toString();
    if (id == null) return;
    try {
      final res = await http
          .get(Uri.parse('https://noti-backend-eight.vercel.app/api/notifications?studentID=$id'))
          .timeout(const Duration(seconds: 10));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        final list = json['data'] as List;
        final count = list.where((e) => e['status'] != 'read').length;
        if (mounted) setState(() => _unreadCount = count);
      }
    } catch (_) {}
  }

  Future<void> _loadTodaySchedule() async {
    try {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final data = await ApiService.getGvScheduleByDate(date);
      if (mounted) {
        setState(() {
          _todayClasses = data.map((e) => e as Map<String, dynamic>).toList();
          _scheduleLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _scheduleLoading = false);
    }
  }

  Future<void> _logout() async {
    await AppSession.instance.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  Widget _buildTodaySchedule() {
    final now = DateTime.now();
    final weekdays = ['', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    final dateLabel =
        '${weekdays[now.weekday]}, ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final n = _todayClasses.length;
    final summaryText = n == 0
        ? 'Hôm nay bạn không có lịch dạy nào 🎉'
        : 'Hôm nay bạn có $n lịch dạy — nhấn để xem chi tiết';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFFE65100)),
                      const SizedBox(width: 6),
                      const Text('Lịch dạy hôm nay',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(dateLabel,
                      style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
                ],
              ),
              const Spacer(),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    setState(() => _scheduleExpanded = !_scheduleExpanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _scheduleExpanded ? 'Thu gọn' : 'Mở rộng',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _scheduleExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: const Color(0xFFE65100),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_scheduleLoading)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              children: [SkeletonChip(), SkeletonChip()],
            ),
          )
        else if (!_scheduleExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/gv_schedule'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      n == 0 ? Icons.event_available : Icons.event_note,
                      size: 18,
                      color: n == 0 ? Colors.green : const Color(0xFFE65100),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: n == 0
                          ? Text(summaryText,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey))
                          : RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.grey),
                                children: [
                                  const TextSpan(text: 'Hôm nay bạn có '),
                                  TextSpan(
                                    text: '$n',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(
                                      text: ' lịch dạy — nhấn để xem chi tiết'),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_todayClasses.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.event_available, size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Không có lịch dạy hôm nay',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              children: _todayClasses
                  .map((d) => GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, '/gv_schedule'),
                        child: _GvClassChip(data: d),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gv = AppSession.instance.giangVien;
    final userid = AppSession.instance.userid ?? '–';

    final tabs = [
      // ── Tab Home ──
      Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gv?.ten ?? '–',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mã GV: $userid',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70),
                    ),
                    if (gv?.gvcohuuyn == true) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Cơ hữu',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Navigator.pushNamed(context, '/notifications');
                    _loadUnreadCount();
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 24),
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 18, minHeight: 18),
                            child: Text(
                              _unreadCount > 99 ? '99+' : '$_unreadCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTodaySchedule(),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    crossAxisCount: 4,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    children: [
                      MenuItemWidget(
                        icon: Icons.calendar_today,
                        label: 'Lịch dạy',
                        onTap: () =>
                            Navigator.pushNamed(context, '/gv_schedule'),
                      ),
                      MenuItemWidget(
                        icon: Icons.class_rounded,
                        label: 'Lớp học',
                        onTap: () =>
                            Navigator.pushNamed(context, '/gv_lophoc'),
                      ),
                      MenuItemWidget(
                        icon: Icons.assignment_outlined,
                        label: 'Lịch thi',
                        onTap: () =>
                            Navigator.pushNamed(context, '/gv_lichthi'),
                      ),
                      MenuItemWidget(
                        icon: Icons.manage_accounts_outlined,
                        label: 'Quản lý lớp',
                        onTap: () =>
                            Navigator.pushNamed(context, '/gv_quanly_lop'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Tab Profile ──
      Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gv?.ten ?? '–',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userid,
                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(
                  children: [
                    _ProfileMenuCard(
                      icon: Icons.person_outline,
                      label: 'Thông tin cá nhân',
                      onTap: () {
                        if (gv != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GvProfileInfoScreen(
                                  gv: gv!, userid: userid),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _ProfileMenuCard(
                      icon: Icons.lock_outline,
                      label: 'Đổi mật khẩu',
                      onTap: () =>
                          Navigator.pushNamed(context, '/change_password'),
                    ),
                    const SizedBox(height: 10),
                    _ProfileMenuCard(
                      icon: Icons.logout,
                      label: 'Đăng xuất',
                      color: const Color(0xFFF44336),
                      onTap: _logout,
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                children: [
                  Text(
                    'Phần mềm Viendongedu phiên bản 1.1.43',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Thuộc bản quyền Cao đẳng Viễn Đông',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: tabs[_currentIndex],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, -2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.dashboard_rounded,
              label: 'Trang chủ',
              selected: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Cá nhân',
              selected: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ── Class Chip lịch dạy hôm nay ─────────────────────────
class _GvClassChip extends StatelessWidget {
  final Map<String, dynamic> data;
  const _GvClassChip({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['mhten']?.toString() ?? '';
    final room = data['phongten']?.toString().trim() ?? '';
    final classCode = data['lmhma']?.toString() ?? '';
    final start = data['thoigianbd']?.toString() ?? '';
    final endRaw = data['thoigiankt'] as String? ?? '';
    final end = endRaw.length >= 16 ? endRaw.substring(11, 16) : endRaw;
    final buoi = _gvBuoiInfo(data['buoi']?.toString());

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
        border: Border(left: BorderSide(color: buoi.color, width: 5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tên môn + badge buổi
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if (buoi.label.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: buoi.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      buoi.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: buoi.color,
                      ),
                    ),
                  ),
              ],
            ),
            // Mã lớp — subtitle
            if (classCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  classCode,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF444444)),
                ),
              ),
            const SizedBox(height: 6),
            // Giờ học
            Row(
              children: [
                Icon(Icons.access_time, size: 13, color: buoi.color),
                const SizedBox(width: 4),
                Text(
                  end.isNotEmpty ? '$start – $end' : start,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: buoi.color,
                  ),
                ),
              ],
            ),
            // Phòng học
            if (room.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.room, size: 13, color: Color(0xFFE65100)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      room,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ProfileMenuCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFFE65100),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE65100), size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(
      height: 1, indent: 48, endIndent: 16, color: Color(0xFFF0F0F0));
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? const Color(0xFFE65100) : Colors.grey,
                size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? const Color(0xFFE65100) : Colors.grey,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

