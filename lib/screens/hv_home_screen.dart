import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../models/mock_data.dart';
import '../services/api_service.dart';
import '../services/app_session.dart';
import '../services/ems_api_service.dart';
import '../components/menu_item.dart';
import 'hv_profile_info_screen.dart';
import 'student_board_screen.dart';

// "1970-01-01T20:30:00.000Z" → "20:30"
String _parseEndTime(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw).toUtc();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

// Helper: buoi code → label + color
({String label, Color color}) _buoiInfo(String? b) => switch (b) {
      'S' => (label: 'Sáng', color: const Color(0xFF2196F3)),
      'C' => (label: 'Chiều', color: const Color(0xFFFF9800)),
      'T' => (label: 'Tối', color: const Color(0xFF9C27B0)),
      _ => (label: '', color: Colors.grey),
    };

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  List<Map<String, dynamic>> _todayClasses = [];
  bool _scheduleLoading = true;
  bool _scheduleExpanded = true;
  int _unreadCount = 0;

  // ── Bảng tin (EMS) ─────────────────────────────────────────────────────────
  // Tách hẳn khỏi _unreadCount của chuông Vercel ở trên: hai nguồn khác nhau,
  // và EMS hỏng thì phần còn lại của trang chủ vẫn phải chạy.
  AnnouncementItem? _latestBoardItem;
  int _boardUnread = 0;
  bool _boardFailed = false;
  bool _boardLoading = false;
  // Một phiên chỉ nhắc "bắt buộc đọc" một lần.
  static bool _mustReadShown = false;

  @override
  void initState() {
    super.initState();
    _loadTodaySchedule();
    _loadUnreadCount();
    _loadBoard();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadBoard();
  }

  /// Thẻ mới nhất + số chưa đọc của Bảng tin.
  ///
  /// Nuốt mọi lỗi: một EMS chết KHÔNG được phép làm hỏng trang chủ IMS. Thẻ chỉ
  /// đơn giản là không hiện, và _boardFailed cho phép hiện trạng thái thử lại.
  Future<void> _loadBoard() async {
    if (_boardLoading) return;
    _boardLoading = true;
    try {
      final items = await EmsApiService.board(limit: 20);
      final unread = items.where((i) => i.isUnread).length;
      if (!mounted) return;
      setState(() {
        _latestBoardItem = items.isEmpty ? null : items.first;
        _boardUnread = unread;
        _boardFailed = false;
      });
      _maybeShowMustRead(items);
    } catch (_) {
      // A DELIBERATE denial (no EMS account for this student, or a deactivated
      // one) is not a failure to retry — most students today have no EMS
      // account at all, and showing them "không tải được" forever would be a
      // permanent false alarm on the home screen. Only a real fault gets the
      // retry card.
      if (mounted) {
        setState(() => _boardFailed = !AppSession.instance.emsDenied);
      }
    } finally {
      _boardLoading = false;
    }
  }

  /// Nhiều nhất MỘT lần mỗi phiên: nhắc thông báo bắt buộc đọc chưa xác nhận.
  /// Nếu không chặn, mỗi lần resume app sẽ bung lại một tấm che mặt màn hình.
  void _maybeShowMustRead(List<AnnouncementItem> items) {
    if (_mustReadShown) return;
    final pending = items.where((i) => i.needsAcknowledgement).toList();
    if (pending.isEmpty) return;
    _mustReadShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const StudentBoardScreen()));
      _loadBoard();
    });
  }

  Future<void> _loadUnreadCount() async {
    final id = AppSession.instance.hocVien?.id.toString();
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
      final data = await ApiService.getTodaySchedule();
      if (mounted) {
        setState(() {
          _todayClasses =
              data.map((e) => e as Map<String, dynamic>).toList();
          _scheduleLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _scheduleLoading = false);
    }
  }

  // ── Session helpers ──────────────────────────────────
  String get _name => AppSession.instance.hocVien?.fullName ?? '–';
  String get _mssv => AppSession.instance.hocVien?.mshv ?? '–';
  String get _malop => AppSession.instance.hocVien?.malop ?? '–';
  String get _ngaysinh => AppSession.instance.hocVien?.ngaysinhFormatted ?? '–';
  String get _sdt => AppSession.instance.hocVien?.sdt ?? '–';
  String get _email => AppSession.instance.hocVien?.email ?? '–';
  String get _cmnd => AppSession.instance.hocVien?.cmnd ?? '–';
  String get _khoahoc {
    final k = AppSession.instance.hocVien?.khoahoc;
    return k != null ? 'Khóa $k' : '–';
  }

  IconData _mapStringToIcon(String? name) => switch (name) {
        'calendar_today' => Icons.calendar_today,
        'assignment' => Icons.assignment,
        'account_balance' => Icons.account_balance,
        'add_circle' => Icons.add_circle,
        'bar_chart' => Icons.bar_chart,
        'people' => Icons.people,
        'payments' => Icons.payments,
        'receipt_long' => Icons.receipt_long,
        'campaign' => Icons.campaign,
        _ => Icons.help_outline,
      };

  Future<void> _logout() async {
    // Reset the once-per-session must-read prompt so a different student who
    // logs in on the SAME app process still gets their acknowledgement sheet.
    _mustReadShown = false;
    await AppSession.instance.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  // ── Bảng tin card ────────────────────────────────────
  Widget _buildBoardCard() {
    // Chưa có gì để nói và cũng không lỗi → không chiếm chỗ trên trang chủ.
    // Học viên chưa có tài khoản EMS cũng không thấy thẻ này (emsDenied).
    if (_latestBoardItem == null && !_boardFailed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            if (_boardFailed && _latestBoardItem == null) {
              _loadBoard();
              return;
            }
            await Navigator.pushNamed(context, '/student_board');
            _loadBoard();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.campaign_outlined,
                      color: Color(0xFFE65100), size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('Thông tin mới từ trung tâm',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE65100))),
                        if (_boardUnread > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$_boardUnread chưa đọc',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        _latestBoardItem?.title ??
                            'Không tải được bảng tin. Chạm để thử lại.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Today schedule section ───────────────────────────
  Widget _buildTodaySchedule() {
    final now = DateTime.now();
    final weekdays = ['', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    final dayLabel = weekdays[now.weekday];
    final dateLabel =
        '$dayLabel, ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final n = _todayClasses.length;
    final summaryText = n == 0
        ? 'Hôm nay bạn không có lịch học nào 🎉'
        : 'Hôm nay bạn có $n lịch học — nhấn để xem chi tiết';

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
                      const Icon(Icons.calendar_today,
                          size: 16, color: Color(0xFFE65100)),
                      const SizedBox(width: 6),
                      Text(
                        'Lịch học hôm nay',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                  ),
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
                    color: Color(0xFFE65100).withValues(alpha: 0.12),
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
                        color: Color(0xFFE65100),
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
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFE65100)),
              ),
            ),
          )
        else if (!_scheduleExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/schedule'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      n == 0 ? Icons.event_available : Icons.event_note,
                      size: 18,
                      color: n == 0 ? Colors.green : Color(0xFFE65100),
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
                                      text: ' lịch học — nhấn để xem chi tiết'),
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2)),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.event_available,
                      size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Không có lịch học hôm nay',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
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
                            Navigator.pushNamed(context, '/schedule'),
                        child: _ClassChip(data: d),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = MockData.menuItems;

    final List<Widget> tabs = [
      // ──────────── Dashboard ────────────
      Column(
        children: [
          // Header
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
                    color: Colors.white.withValues(alpha: 0.3),
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
                        _name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MSSV: $_mssv',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _malop,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

          // Scrollable content
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFFE65100),
              onRefresh: _loadTodaySchedule,
              child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lịch học hôm nay
                  _buildTodaySchedule(),

                  // Thông tin mới từ trung tâm
                  _buildBoardCard(),

                  // Menu grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemBuilder: (context, index) {
                      final m = items[index];
                      return MenuItemWidget(
                        icon: _mapStringToIcon(m['icon']?.toString()),
                        label: m['label']?.toString() ?? '',
                        onTap: () => Navigator.pushNamed(
                          context,
                          m['route']?.toString() ?? '/home',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        ],
      ),

      // ──────────── QR Code ────────────
      Container(
        color: Colors.grey[100],
        child: Column(
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
              child: Column(
                children: [
                  Text(
                    _name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'MSSV: $_mssv',
                    style: const TextStyle(
                        fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, 8)),
                ],
              ),
              child: QrImageView(
                data: _mssv,
                size: 220,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quét mã để điểm danh',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const Spacer(),
          ],
        ),
      ),

      // ──────────── Profile ────────────
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
                          _name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _mssv,
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HvProfileInfoScreen()),
                      ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                children: const [
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
                const SizedBox(width: 64),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Cá nhân',
                  selected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
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
                onTap: () => setState(() => _currentIndex = 1),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: _currentIndex == 1
                        ? const LinearGradient(
                            colors: [Colors.white, Colors.white])
                        : const LinearGradient(
                            colors: [
                              Color(0xFFE65100),
                              Color(0xFFFF8C00),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(0xFFE65100), width: 3),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: Icon(
                    Icons.qr_code_rounded,
                    size: 34,
                    color:
                        _currentIndex == 1 ? Color(0xFFE65100) : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Class Chip (lịch học hôm nay) ───────────────────────
class _ClassChip extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ClassChip({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['mhten']?.toString() ?? '';
    final classCode = data['lmhma']?.toString() ?? '';
    final room = data['phongten']?.toString().trim() ?? '';
    final teacher = data['gvten']?.toString() ?? '';
    final start = data['thoigianbd']?.toString() ?? '';
    final end = _parseEndTime(data['thoigiankt']?.toString());
    final buoi = _buoiInfo(data['buoi']?.toString());

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
        border: Border(left: BorderSide(color: buoi.color, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (buoi.label.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: buoi.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      buoi.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: buoi.color,
                      ),
                    ),
                  ),
              ],
            ),
            if (classCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  classCode,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF999999)),
                ),
              ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: buoi.color),
                const SizedBox(width: 3),
                Text(
                  end.isNotEmpty ? '$start – $end' : start,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: buoi.color,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.person_outline, size: 12, color: Color(0xFFE65100)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    teacher,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.room, size: 12, color: Color(0xFFE65100)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    room,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile menu card ─────────────────────────────────────
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
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

// ── Reusable widgets ─────────────────────────────────────
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
          Icon(icon, color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
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
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, indent: 48, endIndent: 16, color: Color(0xFFF0F0F0));
  }
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? Color(0xFFE65100) : Colors.grey, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? Color(0xFFE65100) : Colors.grey,
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

