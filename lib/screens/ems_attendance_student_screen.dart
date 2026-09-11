// lib/screens/ems_attendance_student_screen.dart
//
// Điểm danh EMS của chính học viên — nguồn dữ liệu điểm danh chính thức.
//
// Khác màn hình "Lớp môn học" (đọc thẳng IMS): đây là bản ghi của EMS, nơi
// mỗi buổi chỉ có ĐÚNG MỘT dòng. Trong IMS một buổi có thể tồn tại hai dòng
// mâu thuẫn nhau — có mặt và vắng cùng lúc — và bản hiển thị đếm cả hai.
//
// Buổi chưa được thầy/cô ghi vẫn hiện là CHỜ XÁC NHẬN, tuyệt đối không là vắng.

import 'dart:async';

import 'package:flutter/material.dart';
import '../services/ems_attendance_cache.dart';
import '../services/ems_api_service.dart';

class EmsAttendanceStudentScreen extends StatefulWidget {
  const EmsAttendanceStudentScreen({super.key});

  @override
  State<EmsAttendanceStudentScreen> createState() =>
      _EmsAttendanceStudentScreenState();
}

class _EmsAttendanceStudentScreenState extends State<EmsAttendanceStudentScreen>
    with WidgetsBindingObserver {
  static const _orange = Color(0xFFE65100);
  static const _green = Color(0xFF2E7D32);
  static const _red = Color(0xFFC62828);

  bool _loading = true;
  bool _offline = false;
  String? _error;
  List<EmsStudentMark> _marks = const [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(background: true),
    );
    _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(background: true);
  }

  Future<void> _load({bool background = false}) async {
    if (!background) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final m = await EmsApiService.myAttendance();
      await EmsAttendanceCache.saveStudentHistory(m);
      if (!mounted) return;
      setState(() {
        _marks = m;
        _loading = false;
        _offline = false;
        _error = null;
      });
    } on EmsException catch (e) {
      final cached = await EmsAttendanceCache.loadStudentHistory();
      if (!mounted) return;
      if (cached.isNotEmpty) {
        setState(() {
          _marks = cached;
          _loading = false;
          _offline = true;
          _error = null;
        });
      } else if (!background) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  int get _present => _marks.where((m) => m.status == 'present').length;
  int get _absent => _marks.where((m) => m.status == 'absent').length;
  int get _pending => _marks.where((m) => m.status == null).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: const Text('Điểm danh EMS'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _center(
        Icons.cloud_off,
        'Không tải được dữ liệu',
        _error!,
        onRetry: _load,
      );
    }
    if (_marks.isEmpty) {
      return _center(
        Icons.inbox_outlined,
        'Chưa có buổi nào được ghi',
        'Chưa có lịch hoặc kết quả điểm danh EMS. Nếu đã quẹt cổng, bằng chứng '
            'vào trường sẽ hiện ngay khi thiết bị đồng bộ.',
      );
    }
    return RefreshIndicator(
      color: _orange,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_offline) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Mạng yếu: đang hiển thị kết quả đã lưu gần nhất. '
                'Ứng dụng sẽ tự cập nhật khi có mạng.',
                style: TextStyle(fontSize: 12, color: _orange),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _summary(),
          const SizedBox(height: 12),
          for (final m in _marks) ...[_row(m), const SizedBox(height: 6)],
        ],
      ),
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _stat('Có mặt', _present, _green),
          _stat('Vắng', _absent, _red),
          _stat('Chờ GV', _pending, _orange),
        ],
      ),
    );
  }

  Widget _stat(String label, int n, Color c) => Expanded(
    child: Column(
      children: [
        Text(
          '$n',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    ),
  );

  Widget _row(EmsStudentMark m) {
    final (label, color) = switch (m.status) {
      'present' => ('Có mặt', _green),
      'late' => ('Đi muộn', _orange),
      'absent' => ('Vắng', _red),
      'excused' => ('Vắng có phép', Colors.blueGrey),
      _ => ('Chờ giáo viên xác nhận', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 54,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.subjectName?.isNotEmpty == true
                      ? m.subjectName!
                      : (m.sectionCode ?? 'Buổi học'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${m.sessionDateVN}'
                  '${m.startTime == null ? '' : ' • ${m.startTime}-${m.endTime ?? ''}'}'
                  ' • $label',
                  style: TextStyle(fontSize: 12, color: color),
                ),
                if (m.arrivedAt != null)
                  Text(
                    'Đã vào trường lúc ${_hhmm(m.arrivedAt!)}'
                    '${m.arrivalOnTime == true ? ' • trước giờ học' : ''}',
                    style: const TextStyle(fontSize: 11, color: _green),
                  ),
                if (m.note?.isNotEmpty == true)
                  Text(
                    'Ghi chú: ${m.note}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _hhmm(DateTime d) {
    final school = d.toUtc().add(const Duration(hours: 7));
    return '${school.hour.toString().padLeft(2, '0')}:'
        '${school.minute.toString().padLeft(2, '0')}';
  }

  Widget _center(
    IconData icon,
    String title,
    String detail, {
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ],
        ),
      ),
    );
  }
}
