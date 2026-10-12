import 'package:flutter/material.dart';

import '../models/crm_money_tuition.dart';
import '../theme/vd_tokens.dart';

/// Above the tuition summary: the offline-copy label (build standard) and the
/// LAW M-53 reminder when the bảng kê says the student owes.
class TuitionNotices extends StatelessWidget {
  final CrmTuitionResponse? response;
  const TuitionNotices({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    final r = response;
    if (r == null) return const SizedBox.shrink();
    return Column(
      children: [
        if (r.offlineSavedAt != null) ...[
          TuitionOfflineNote(savedAt: r.offlineSavedAt!),
          const SizedBox(height: 12),
        ],
        if (r.summary.owes) ...[
          const TuitionDebtBanner(),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class TuitionDebtBanner extends StatelessWidget {
  const TuitionDebtBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.vd.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.vd.danger.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: context.vd.danger),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Bạn còn nợ học phí theo sổ của Phòng Kế toán. '
              'Vui lòng đóng trước kỳ thi giữa kỳ 02/11 để được dự thi.',
              style: TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class TuitionOfflineNote extends StatelessWidget {
  final DateTime savedAt;
  const TuitionOfflineNote({super.key, required this.savedAt});

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final t = '${two(savedAt.hour)}:${two(savedAt.minute)} '
        '${two(savedAt.day)}/${two(savedAt.month)}';
    return Row(
      children: [
        Icon(Icons.cloud_off_outlined, size: 18, color: context.vd.inkFaint),
        const SizedBox(width: 6),
        Expanded(
          child: Text('Không có kết nối — đang xem bản lưu lúc $t.',
              style: TextStyle(fontSize: 12, color: context.vd.inkFaint)),
        ),
      ],
    );
  }
}
