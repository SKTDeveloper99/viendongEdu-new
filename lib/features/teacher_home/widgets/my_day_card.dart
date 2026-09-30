import 'package:flutter/material.dart';

import '../../../theme/vd_theme.dart';
import '../../../theme/vd_tokens.dart';

/// "Ngày làm việc của tôi" shortcut card.
class MyDayCard extends StatelessWidget {
  const MyDayCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Material(
        color: context.vd.surfaceAlt,
        borderRadius: BorderRadius.circular(VdTheme.cardRadius),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/teacher_my_day'),
          borderRadius: BorderRadius.circular(VdTheme.cardRadius),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.today_outlined,
                  color: context.vd.primary,
                  size: 30,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ngày làm việc của tôi',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Lịch dạy, điểm danh và sinh viên cần phản hồi',
                        style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.vd.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
