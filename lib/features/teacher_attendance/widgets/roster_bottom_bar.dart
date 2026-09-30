import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';

/// Status line (CHƯA GỬI / CHƯA LƯU + counts) and the "Lưu điểm danh" button.
class RosterBottomBar extends StatelessWidget {
  const RosterBottomBar({
    super.key,
    required this.queued,
    required this.needsReasonCount,
    required this.presentCount,
    required this.lateCount,
    required this.excusedCount,
    required this.absentCount,
    required this.unmarkedCount,
    required this.saving,
    required this.onSave,
  });

  final bool queued;

  /// Punched-but-absent students still waiting for a reason; null = none.
  final int? needsReasonCount;
  final int presentCount;
  final int lateCount;
  final int excusedCount;
  final int absentCount;
  final int unmarkedCount;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: context.vd.surface,
          boxShadow: [
            BoxShadow(
              color: context.vd.shadow,
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${queued ? 'CHƯA GỬI • kết nối lại rồi bấm Lưu\n' : ''}'
                '${needsReasonCount != null ? 'CHƯA LƯU • $needsReasonCount SV quẹt cổng bị ghi vắng, cần lý do\n' : ''}'
                'Có $presentCount • Trễ $lateCount • Phép $excusedCount • '
                'Vắng $absentCount • Chưa điểm danh $unmarkedCount',
                style: TextStyle(
                  fontSize: 12,
                  color: needsReasonCount != null ? context.vd.danger : null,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.vd.primary),
              onPressed: saving ? null : onSave,
              child: saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.vd.onPrimary,
                      ),
                    )
                  : const Text('Lưu điểm danh'),
            ),
          ],
        ),
      ),
    );
  }
}
