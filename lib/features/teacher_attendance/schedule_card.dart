import 'package:flutter/material.dart';

import '../../data/teacher_attendance_repository.dart';
import '../../services/app_session.dart';
import '../../utils/snack.dart';
import 'roster_screen.dart';
import 'schedule_session_match.dart';
import '../../theme/vd_tokens.dart';

// ── Schedule Card ────────────────────────────────────────
({String label, Color color}) _buoiInfo(BuildContext context, String? b) =>
    switch (b) {
      'S' => (label: 'Sáng', color: context.vd.info),
      'C' => (label: 'Chiều', color: context.vd.warning),
      'T' => (label: 'Tối', color: context.vd.evening),
      _ => (label: '', color: context.vd.inkFaint),
    };

class ScheduleCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String date;
  const ScheduleCard({super.key, required this.data, required this.date});

  @override
  State<ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<ScheduleCard> {
  bool _expanded = false;
  bool _loading = false;

  Future<void> _openAttendance() async {
    setState(() => _loading = true);
    try {
      // ── CUTOVER 2026-09-12: điểm danh ghi vào EMS, không ghi vào IMS ───────
      //
      // IMS chỉ còn là nơi LẤY danh sách học viên của lớp môn học (đã scrape sang
      // `enrollments`, khớp 612/613 lớp HK261 theo ims_lop_mon_hoc_id). Việc GHI
      // điểm danh chuyển hẳn sang EMS.
      //
      // Vì sao phải chuyển chứ không vá tiếp: `giangvien/diemdanh/luu` của IMS là
      // INSERT chứ không phải UPSERT, nên lưu hai lần là sinh ra hai bản ghi mâu
      // thuẫn. Đo trên IMS thật ngày 09/09/2026: từ 01/08 có 11.075 nhóm trùng /
      // 31.462 dòng, 2.633 mâu thuẫn trên 1.490 học viên, và 1.250 trường hợp
      // dòng VẮNG thắng — 916 em đang bị báo vắng dù có đi học. Bản vá phía app
      // (a07222a) làm giảm, nhưng KHÔNG thể diệt: endpoint không idempotent thì
      // mạng chập chờn vẫn ghi trùng.
      // `attendance_marks` của EMS có UNIQUE (session_key, mssv), nên lưu hai lần
      // là KHÔNG THỂ tạo ra dòng thứ hai. Đó là lý do chuyển, không phải vì mới.
      //
      // Token EMS đã được AppSession đổi từ token IMS lúc đăng nhập
      // (mirrorTeacher), nên giáo viên KHÔNG phải đăng nhập thêm lần nào.
      // A missing EMS session must fail closed. The old IMS endpoint inserts
      // duplicates and cannot truthfully confirm an EMS save.
      if (!AppSession.instance.hasEms) {
        await AppSession.instance.refreshEmsToken(force: true);
      }
      if (!mounted) return;
      if (!AppSession.instance.hasEms) {
        showErrorSnack(
          context,
          'Chưa kết nối được EMS. Chưa có dữ liệu điểm danh nào được gửi. '
          'Vui lòng kiểm tra mạng rồi thử lại.',
        );
        return;
      }
      final sectionCode = widget.data['lmhma']?.toString().trim() ?? '';
      final start = _time(widget.data['thoigianbd']?.toString());
      final end = _time(widget.data['thoigiankt']?.toString());
      if (sectionCode.isEmpty || start.isEmpty || end.isEmpty) {
        showErrorSnack(context, 'Không xác định được buổi học đã chọn.');
        return;
      }
      final repository = const TeacherAttendanceRepository();
      final sessions = await repository.mySessions(date: widget.date);
      if (!mounted) return;
      final session = matchScheduleSession(
        sessions: sessions,
        sectionCode: sectionCode,
        date: widget.date,
        startTime: start,
        endTime: end,
      );
      if (session == null) {
        showErrorSnack(
          context,
          'Không tìm thấy duy nhất buổi học đã chọn trên EMS. Chưa mở danh sách điểm danh.',
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TeacherRosterScreen(repository: repository, session: session),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    final buoi = _buoiInfo(context, d['buoi']?.toString());
    final baonghiyn = d['baonghiyn'];
    final daBaoNghi = baonghiyn != null && baonghiyn != false && baonghiyn != 0;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.vd.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.vd.shadow,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
          border: Border(
            left: BorderSide(
              color: daBaoNghi ? context.vd.inkFaint : buoi.color,
              width: 5,
            ),
          ),
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
                      Text(
                        start,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: buoi.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        end,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.vd.inkFaint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Container(width: 1, height: 40, color: context.vd.hairline),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subject,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (daBaoNghi) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.vd.surfaceAlt,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event_busy_outlined,
                                      size: 12,
                                      color: context.vd.inkMuted,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Báo nghỉ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: context.vd.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
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
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.room,
                              size: 13,
                              color: context.vd.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              room,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.vd.inkFaint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.class_outlined,
                              size: 13,
                              color: context.vd.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                classCode,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.vd.inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Chevron
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: context.vd.inkFaint,
                    size: 20,
                  ),
                ],
              ),
            ),

            // ── Expanded: nút điểm danh ──
            if (_expanded) ...[
              Divider(height: 1, color: context.vd.surfaceAlt),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _openAttendance,
                        icon: _loading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: context.vd.onPrimary,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.checklist_rounded,
                                color: context.vd.onPrimary,
                                size: 18,
                              ),
                        label: Text(
                          'Điểm danh bằng danh sách',
                          style: TextStyle(
                            color: context.vd.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.vd.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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

String _time(String? value) {
  final s = value?.trim() ?? '';
  return s.length >= 5 ? s.substring(0, 5) : s;
}
