import 'package:flutter/material.dart';

import '../../../services/ems_api_service.dart';
import '../attendance_colors.dart';

/// Asks before saving with undecided students. True = save the [chosen]
/// marks and leave the rest empty; anything else = go back, send nothing.
Future<bool> showUnmarkedConfirmDialog(
  BuildContext context, {
  required List<EmsRosterStudent> undecided,
  required int chosen,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Còn ${undecided.length} học viên chưa điểm danh'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Những học viên này sẽ KHÔNG được ghi có mặt hay vắng — '
              'buổi học của họ để trống. Nếu họ vắng, hãy quay lại và chọn '
              '"Vắng" cho từng người.',
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
            const SizedBox(height: 10),
            for (final s in undecided.take(12))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• ${s.fullName} (${s.mssv})',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            if (undecided.length > 12)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '… và ${undecided.length - 12} học viên nữa',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: attendanceOrange),
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Quay lại điểm danh'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Lưu $chosen đã chọn, để trống số còn lại'),
        ),
      ],
    ),
  );
  return ok == true;
}
