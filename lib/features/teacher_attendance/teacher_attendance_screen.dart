// Điểm danh EMS — EMS là nguồn dữ liệu điểm danh chính thức.
//
// Vì sao tồn tại: ngày 07/09/2026, sáu học viên lớp 08CD15BEP4C quẹt cổng từ
// 07:05 đến 07:30 rồi bị ghi VẮNG bằng một lần lưu hàng loạt lúc 09:07:48–51.
// IMS không có gì phản đối, vì IMS không thể. Ở đây thì có:
//
//   • CHƯA ĐIỂM DANH không phải là VẮNG. Không chọn gì thì không ghi gì.
//   • Trường hợp lạ vẫn được lưu, kèm lý do/cờ để xem lại sau.
//   • Lưu lại bao nhiêu lần cũng chỉ một dòng; lưu muộn vẫn lưu được.
//
// Giáo viên vẫn là người quyết định cuối cùng. Máy chỉ từ chối im lặng.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/teacher_attendance_repository.dart';
import 'attendance_outbox.dart';
import 'roster_screen.dart';
import 'session_list_view_model.dart';
import 'widgets/attendance_message.dart';
import 'widgets/pending_send_badge.dart';
import 'widgets/session_card.dart';
import '../../theme/vd_tokens.dart';

/// Today's sessions of the teacher (route `/ems_attendance_gv`). Tapping one
/// opens its roster; the list reloads on return.
class EmsAttendanceTeacherScreen extends StatefulWidget {
  const EmsAttendanceTeacherScreen({super.key});

  @override
  State<EmsAttendanceTeacherScreen> createState() =>
      _EmsAttendanceTeacherScreenState();
}

class _EmsAttendanceTeacherScreenState
    extends State<EmsAttendanceTeacherScreen> {
  static const _repository = TeacherAttendanceRepository();
  late final SessionListViewModel _vm = SessionListViewModel(_repository);

  @override
  void initState() {
    super.initState();
    _vm.load();
    unawaited(AttendanceOutbox.instance.refreshCount());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        backgroundColor: context.vd.bg,
        appBar: AppBar(
          backgroundColor: context.vd.primary,
          foregroundColor: context.vd.onPrimary,
          title: const Row(
            children: [
              Flexible(child: Text('Điểm danh EMS')),
              SizedBox(width: 8),
              PendingSendBadge(),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _vm.loading ? null : _vm.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_vm.loading) return const Center(child: CircularProgressIndicator());
    final error = _vm.error;
    if (error != null) {
      return AttendanceMessage(
        icon: Icons.cloud_off,
        title: 'Không tải được danh sách buổi dạy',
        detail: error,
        onRetry: _vm.load,
      );
    }
    final sessions = _vm.sessions;
    if (sessions.isEmpty) {
      return const AttendanceMessage(
        icon: Icons.event_busy,
        title: 'Hôm nay bạn không có buổi học',
        detail: 'Buổi học lấy theo thời khoá biểu. Kéo xuống để tải lại.',
      );
    }
    return RefreshIndicator(
      color: context.vd.primary,
      onRefresh: _vm.load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: sessions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final s = sessions[i];
          return SessionCard(
            session: s,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TeacherRosterScreen(repository: _repository, session: s),
                ),
              );
              if (mounted) _vm.load();
            },
          );
        },
      ),
    );
  }
}
