import 'package:flutter/material.dart';

import '../models/crm_money_tuition.dart';
import '../models/student_notice.dart';
import 'student_notices.dart';
import '../theme/vd_tokens.dart';

/// Above the tuition summary: the offline-copy label (build standard), then
/// the server's notices for this screen. When the server sends none that are
/// still current and the bảng kê says the student owes, a date-free reminder
/// stands in, so an old or switched-off server never leaves the debt unsaid
/// and the app never names an exam date it does not know.
class TuitionNotices extends StatelessWidget {
  final CrmTuitionResponse? response;

  /// Test clock for `until`; production uses the phone clock in Vietnam time.
  final DateTime Function()? now;

  const TuitionNotices({super.key, required this.response, this.now});

  static const debtFallback =
      'Bạn còn nợ học phí. Vui lòng đóng trước buổi thi gần nhất để được dự thi.';

  @override
  Widget build(BuildContext context) {
    final r = response;
    if (r == null) return const SizedBox.shrink();
    final shown = visibleStudentNotices(r.notices, now?.call());
    return Column(
      children: [
        if (r.offlineSavedAt != null) ...[
          TuitionOfflineNote(savedAt: r.offlineSavedAt!),
          const SizedBox(height: 12),
        ],
        StudentNoticeList(notices: shown),
        if (shown.isEmpty && r.summary.owes) ...[
          const StudentNoticeBanner(
            level: StudentNoticeLevel.urgent,
            text: debtFallback,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class TuitionOfflineNote extends StatelessWidget {
  final DateTime savedAt;
  const TuitionOfflineNote({super.key, required this.savedAt});

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final t =
        '${two(savedAt.hour)}:${two(savedAt.minute)} '
        '${two(savedAt.day)}/${two(savedAt.month)}';
    return Row(
      children: [
        Icon(Icons.cloud_off_outlined, size: 18, color: context.vd.inkFaint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Chưa cập nhật được — dữ liệu cũ, bản lưu lúc $t.',
            style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
          ),
        ),
      ],
    );
  }
}
