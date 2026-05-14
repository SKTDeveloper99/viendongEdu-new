import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../components/skeleton.dart';
import '../utils/snack.dart';
import 'gv_attendance_screen.dart';
import 'gv_qr_attendance_screen.dart';

class GvScheduleScreen extends StatefulWidget {
  const GvScheduleScreen({super.key});

  @override
  State<GvScheduleScreen> createState() => _GvScheduleScreenState();
}

class _GvScheduleScreenState extends State<GvScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  late DateTime _currentMonday;
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;
  String? _error;
  final ScrollController _chipScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentMonday = _findMonday(DateTime.now());
    _fetch(_selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _chipScroll.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_chipScroll.hasClients) return;
    final weekDays = _weekDays;
    int index = weekDays.indexWhere((d) => _fmtDate(d) == _fmtDate(_selectedDate));
    if (index == -1) return;
    const chipWidth = 60.0;
    const chipMargin = 8.0;
    final chipOffset = index * (chipWidth + chipMargin);
    final viewport = _chipScroll.position.viewportDimension;
    final center = (chipOffset - viewport / 2 + chipWidth / 2)
        .clamp(0.0, _chipScroll.position.maxScrollExtent);
    _chipScroll.animateTo(center,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _fetch(DateTime date) async {
    setState(() { _loading = true; _error = null; });
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final data = await ApiService.getGvScheduleByDate(dateStr);
      if (!mounted) return;
      setState(() {
        _classes = data.map((e) => e as Map<String, dynamic>).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  DateTime _findMonday(DateTime d) => d.subtract(Duration(days: d.weekday - 1));
  List<DateTime> get _weekDays => List.generate(7, (i) => _currentMonday.add(Duration(days: i)));
  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _prevWeek() {
    setState(() => _currentMonday = _currentMonday.subtract(const Duration(days: 7)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _nextWeek() {
    setState(() => _currentMonday = _currentMonday.add(const Duration(days: 7)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _fetch(date);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFE65100)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _currentMonday = _findMonday(picked));
      _selectDate(picked);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickDate,
        backgroundColor: const Color(0xFFE65100),
        icon: const Icon(Icons.calendar_month, color: Colors.white, size: 20),
        label: Text(
          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
      body: SafeArea(top: false, child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Lịch dạy',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Week navigator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _prevWeek,
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 28),
                    ),
                    Text(
                      () {
                        final s = _currentMonday;
                        final e = _currentMonday.add(const Duration(days: 6));
                        return '${s.day}/${s.month} – ${e.day}/${e.month}/${e.year}';
                      }(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: _nextWeek,
                      child: const Icon(Icons.chevron_right,
                          color: Colors.white, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Day chips
                SizedBox(
                  height: 84,
                  child: ListView.builder(
                    controller: _chipScroll,
                    scrollDirection: Axis.horizontal,
                    itemCount: _weekDays.length,
                    itemBuilder: (context, i) {
                      final day = _weekDays[i];
                      final isSelected = _fmtDate(day) == _fmtDate(_selectedDate);
                      final isToday = _fmtDate(day) == _fmtDate(DateTime.now());
                      return GestureDetector(
                        onTap: () => _selectDate(day),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ['T2','T3','T4','T5','T6','T7','CN'][day.weekday - 1],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? const Color(0xFFE65100)
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? const Color(0xFFE65100)
                                      : Colors.white,
                                ),
                              ),
                              if (isToday)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(top: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFE65100)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: _loading
                ? skeletonList()
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style:
                                    const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _fetch(_selectedDate),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFE65100)),
                              child: const Text('Thử lại',
                                  style:
                                      TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : _classes.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_busy,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('Không có lịch dạy',
                                    style:
                                        TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _fetch(_selectedDate),
                            color: const Color(0xFFE65100),
                            child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                                16, 16, 16, 24),
                            itemCount: _classes.length,
                            itemBuilder: (ctx, i) =>
                                _ScheduleCard(data: _classes[i]),
                          ),
                        ),
          ),
        ],
      )),
    );
  }
}

// ── Schedule Card ────────────────────────────────────────
({String label, Color color}) _buoiInfo(String? b) => switch (b) {
      'S' => (label: 'Sáng', color: const Color(0xFF2196F3)),
      'C' => (label: 'Chiều', color: const Color(0xFFFF9800)),
      'T' => (label: 'Tối', color: const Color(0xFF9C27B0)),
      _ => (label: '', color: Colors.grey),
    };

class _ScheduleCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ScheduleCard({required this.data});

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  bool _expanded = false;
  bool _loading = false;

  Future<void> _openAttendance() async {
    setState(() => _loading = true);
    try {
      final d = widget.data;
      final ngayRaw = d['ngay'] as String? ?? '';
      final ngay = ngayRaw.length >= 10 ? ngayRaw.substring(0, 10) : ngayRaw;
      final ktRaw = d['thoigiankt'] as String? ?? '';
      final thoigiankt = ktRaw.length >= 16 ? ktRaw.substring(11, 16) : ktRaw;

      final list = await ApiService.postDiemDanhDanhSach(
        tkbid: d['tkbid'].toString(),
        lopid: d['lopid'].toString(),
        phongid: d['phongid'].toString(),
        ngay: ngay,
        thoigianbd: d['thoigianbd']?.toString() ?? '',
        thoigiankt: thoigiankt,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GvAttendanceScreen(
            subject: d['mhten']?.toString() ?? '',
            classCode: d['lmhma']?.toString() ?? '',
            ngay: ngay,
            students: list,
            tkbParams: {
              'tkbid': d['tkbid'].toString(),
              'lopid': d['lopid'].toString(),
              'phongid': d['phongid'].toString(),
              'ngay': ngay,
              'thoigianbd': d['thoigianbd']?.toString() ?? '',
              'thoigiankt': thoigiankt,
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openQrAttendance() {
    final d = widget.data;
    final ngayRaw = d['ngay'] as String? ?? '';
    final ngay = ngayRaw.length >= 10 ? ngayRaw.substring(0, 10) : ngayRaw;
    final ktRaw = d['thoigiankt'] as String? ?? '';
    final thoigiankt = ktRaw.length >= 16 ? ktRaw.substring(11, 16) : ktRaw;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GvQrAttendanceScreen(
          subject: d['mhten']?.toString() ?? '',
          classCode: d['lmhma']?.toString() ?? '',
          ngay: ngay,
          tkbParams: {
            'tkbid': d['tkbid'].toString(),
            'lopid': d['lopid'].toString(),
            'phongid': d['phongid'].toString(),
            'ngay': ngay,
            'thoigianbd': d['thoigianbd']?.toString() ?? '',
            'thoigiankt': thoigiankt,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final subject = d['mhten']?.toString() ?? '';
    final room = d['phongten']?.toString() ?? '';
    final classCode = d['lmhma']?.toString() ?? '';
    final start = d['thoigianbd']?.toString() ?? '';
    final endRaw = d['thoigiankt'] as String? ?? '';
    final end = endRaw.length >= 16 ? endRaw.substring(11, 16) : '';
    final buoi = _buoiInfo(d['buoi']?.toString());
    final baonghiyn = d['baonghiyn'];
    final daBaoNghi = baonghiyn != null && baonghiyn != false && baonghiyn != 0;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
          ],
          border: Border(left: BorderSide(
            color: daBaoNghi ? const Color(0xFF9E9E9E) : buoi.color,
            width: 5,
          )),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Giờ
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(start,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: buoi.color)),
                      const SizedBox(height: 2),
                      Text(end,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
            const SizedBox(width: 14),
            Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(subject,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (daBaoNghi) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_busy_outlined,
                                  size: 12, color: Color(0xFF757575)),
                              SizedBox(width: 4),
                              Text('Báo nghỉ',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF757575))),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: buoi.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(buoi.label,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: buoi.color)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.room,
                          size: 13, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Text(room,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.class_outlined,
                          size: 13, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(classCode,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey, size: 20,
            ),
          ],
        ),
      ),

            // ── Expanded: nút điểm danh ──
            if (_expanded) ...[
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _openAttendance,
                        icon: _loading
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.checklist_rounded,
                                color: Colors.white, size: 18),
                        label: const Text('Điểm danh bằng danh sách',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE65100),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _openQrAttendance,
                        icon: const Icon(Icons.qr_code_scanner,
                            color: Colors.white, size: 18),
                        label: const Text('Điểm danh bằng QR',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8C00),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
