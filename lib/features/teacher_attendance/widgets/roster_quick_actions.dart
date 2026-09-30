import 'package:flutter/material.dart';

import '../attendance_format.dart';
import 'offline_banner.dart';
import '../../../theme/vd_tokens.dart';

/// Header above the roster: the needs-review notice, the gate-scan sync time,
/// the scanned / unscanned / roster totals and the bulk-mark buttons.
class RosterQuickActions extends StatelessWidget {
  const RosterQuickActions({
    super.key,
    required this.needsReview,
    required this.scanSyncedAt,
    required this.scannedCount,
    required this.unscannedCount,
    required this.rosterSize,
    required this.scansPending,
    required this.allPresent,
    required this.onMarkScannedPresent,
    required this.onMarkAllPresent,
    required this.onResetToScanned,
  });

  final bool needsReview;
  final DateTime? scanSyncedAt;
  final int scannedCount;
  final int unscannedCount;
  final int rosterSize;
  final int scansPending;
  final bool allPresent;
  final VoidCallback onMarkScannedPresent;
  final VoidCallback onMarkAllPresent;
  final VoidCallback onResetToScanned;

  @override
  Widget build(BuildContext context) {
    // "Quẹt cổng: có mặt (0)" từng đếm người đã quẹt NHƯNG chưa đánh dấu —
    // vừa đánh xong là về 0, giáo viên tưởng máy nói không ai quẹt (Dũng,
    // 18/09). Nay: tổng đã quẹt / chưa quẹt luôn hiện, nút chỉ nói còn
    // bao nhiêu người đã quẹt mà chưa được đánh có mặt.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (needsReview)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: OfflineBanner(
              text:
                  'Điểm danh trên máy chủ đã thay đổi khi bạn mất mạng. '
                  'Tự gửi đã dừng; hãy kiểm tra danh sách hiện tại rồi bấm Lưu.',
            ),
          ),
        // Giờ đồng bộ quẹt cổng: giáo viên đối chiếu được "đã quẹt" là tính
        // tới lúc nào, thay vì đoán danh sách trống nghĩa là không ai quẹt.
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            scanSyncedAt == null
                ? 'Lấy quẹt cổng: chưa có dữ liệu'
                : 'Lấy quẹt cổng lúc ${schoolHhmm(scanSyncedAt!)} — chưa quẹt KHÔNG phải vắng',
            style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Đã quẹt $scannedCount • Chưa quẹt $unscannedCount • Sĩ số $rosterSize',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.vd.ink,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: scansPending == 0 ? null : onMarkScannedPresent,
              icon: const Icon(Icons.sensor_door_outlined, size: 16),
              label: Text(
                scansPending == 0
                    ? 'Đã quẹt → có mặt (xong)'
                    : 'Đã quẹt → có mặt (còn $scansPending)',
              ),
            ),
            allPresent
                ? OutlinedButton.icon(
                    onPressed: onResetToScanned,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Bỏ chọn tất cả'),
                  )
                : OutlinedButton.icon(
                    onPressed: rosterSize == 0 ? null : onMarkAllPresent,
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Tất cả có mặt'),
                  ),
          ],
        ),
      ],
    );
  }
}
