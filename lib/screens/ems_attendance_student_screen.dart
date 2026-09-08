// lib/screens/ems_attendance_student_screen.dart
//
// Điểm danh EMS của chính học viên (THỬ NGHIỆM).
//
// Khác màn hình "Lớp môn học" (đọc thẳng IMS): đây là bản ghi của EMS, nơi
// mỗi buổi chỉ có ĐÚNG MỘT dòng. Trong IMS một buổi có thể tồn tại hai dòng
// mâu thuẫn nhau — có mặt và vắng cùng lúc — và bản hiển thị đếm cả hai.
//
// Buổi chưa được thầy/cô ghi thì KHÔNG hiện là vắng; nó không hiện gì cả.

import 'package:flutter/material.dart';
import '../services/ems_api_service.dart';

class EmsAttendanceStudentScreen extends StatefulWidget {
  const EmsAttendanceStudentScreen({super.key});

  @override
  State<EmsAttendanceStudentScreen> createState() =>
      _EmsAttendanceStudentScreenState();
}

class _EmsAttendanceStudentScreenState
    extends State<EmsAttendanceStudentScreen> {
  static const _orange = Color(0xFFE65100);
  static const _green = Color(0xFF2E7D32);
  static const _red = Color(0xFFC62828);

  bool _loading = true;
  String? _error;
  List<EmsStudentMark> _marks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await EmsApiService.myAttendance();
      if (!mounted) return;
      setState(() {
        _marks = m;
        _loading = false;
      });
    } on EmsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  int get _present => _marks.where((m) => m.status == 'present').length;
  int get _absent => _marks.where((m) => m.status == 'absent').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: const Text('Điểm danh EMS (thử nghiệm)'),
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
        'Hệ thống mới này đang chạy song song để đối chiếu. Buổi nào thầy/cô '
            'chưa ghi thì ở đây trống — trống KHÔNG có nghĩa là vắng.',
      );
    }
    return RefreshIndicator(
      color: _orange,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
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
          _stat('Tổng buổi đã ghi', _marks.length, Colors.grey[800]!),
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
    final absent = m.status == 'absent';
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
            height: 38,
            decoration: BoxDecoration(
              color: absent ? _red : _green,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.subjectName?.isNotEmpty == true
                      ? m.subjectName!
                      : (m.sectionCode ?? 'Buổi học'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m.sessionDate ?? '',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                if (absent && (m.note?.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Lý do: ${m.note}',
                      style: const TextStyle(fontSize: 11, color: _red),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            absent ? 'Vắng' : 'Có mặt',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: absent ? _red : _green,
            ),
          ),
        ],
      ),
    );
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
