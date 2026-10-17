import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';

/// Owner 2026-10-17: a gentle check before saving a session that has Vắng or
/// Khác marks — absences are what students see and question first. True =
/// the teacher has checked and wants to save; anything else = go back.
Future<bool> showAbsenceCheckDialog(
  BuildContext context, {
  required int absent,
  required int other,
}) async {
  final counts = [
    if (absent > 0) '$absent học viên Vắng',
    if (other > 0) '$other học viên Khác',
  ].join(' và ');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Kính nhờ Thầy/Cô kiểm tra lại'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Buổi học này có $counts.',
              style: TextStyle(fontSize: 13, color: context.vd.ink),
            ),
            const SizedBox(height: 10),
            Text(
              '• Với học viên Vắng: Thầy/Cô vui lòng xác nhận lại em đó thật '
              'sự không có mặt trong lớp vào giờ học này.',
              style: TextStyle(fontSize: 13, color: context.vd.ink),
            ),
            const SizedBox(height: 6),
            Text(
              '• Mục Khác: xin Thầy/Cô chỉ dùng cho những trường hợp thật sự '
              'đặc biệt.',
              style: TextStyle(fontSize: 13, color: context.vd.ink),
            ),
            const SizedBox(height: 10),
            Text(
              'Nhà trường trân trọng cảm ơn Thầy/Cô.',
              style: TextStyle(fontSize: 13, color: context.vd.inkMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Xem lại'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: context.vd.primary),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Đã kiểm tra, lưu'),
        ),
      ],
    ),
  );
  return ok == true;
}
