import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';
import '../save_status.dart';

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
    this.saveStatus = RosterSaveStatus.none,
    this.savedAt,
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
  final RosterSaveStatus saveStatus;
  final DateTime? savedAt;

  /// "ĐÃ LƯU ✓ lúc 15:11 03/11" / "CHƯA LƯU • …"; null when nothing to say or
  /// a more specific CHƯA GỬI / CHƯA LƯU line is already shown.
  String? get saveLine {
    if (queued || needsReasonCount != null) return null;
    switch (saveStatus) {
      case RosterSaveStatus.unsaved:
        return 'CHƯA LƯU • bấm Lưu điểm danh để gửi';
      case RosterSaveStatus.saved:
        final t = savedAt;
        if (t == null) return 'ĐÃ LƯU ✓';
        String two(int n) => n.toString().padLeft(2, '0');
        return 'ĐÃ LƯU ✓ lúc ${two(t.hour)}:${two(t.minute)} '
            '${two(t.day)}/${two(t.month)}';
      case RosterSaveStatus.none:
        return null;
    }
  }

  /// The server holds exactly what is on screen: the button itself says so
  /// (Linh 03/11: on weak floor-4 Wi-Fi teachers could not tell whether Lưu
  /// had gone through). Any edit turns it back into "Lưu điểm danh".
  bool get showsSaved =>
      !queued &&
      needsReasonCount == null &&
      saveStatus == RosterSaveStatus.saved;

  String get buttonLabel => showsSaved ? '✓ Đã lưu' : 'Lưu điểm danh';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: context.vd.surface,
          boxShadow: [BoxShadow(color: context.vd.shadow, blurRadius: 6)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (saveLine case final line?)
                    Text(
                      line,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: saveStatus == RosterSaveStatus.saved
                            ? context.vd.success
                            : context.vd.danger,
                      ),
                    ),
                  Text(
                    '${queued ? 'CHƯA GỬI • kết nối lại rồi bấm Lưu\n' : ''}'
                    '${needsReasonCount != null ? 'CHƯA LƯU • $needsReasonCount SV quẹt cổng bị ghi vắng, cần lý do\n' : ''}'
                    'Có $presentCount • Vắng $absentCount • '
                    'Khác ${lateCount + excusedCount} • Chưa điểm danh $unmarkedCount',
                    style: TextStyle(
                      fontSize: 12,
                      color: needsReasonCount != null
                          ? context.vd.danger
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: showsSaved
                    ? context.vd.success
                    : context.vd.primary,
              ),
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
                  : Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
