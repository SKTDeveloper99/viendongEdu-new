import 'package:flutter/material.dart';

import '../../../components/skeleton.dart';
import '../../../theme/vd_theme.dart';
import 'gv_class_chip.dart';

/// The list part of the "Lịch dạy hôm nay" block: skeleton while loading,
/// nothing when failed, a one-line summary when collapsed, an empty card, or
/// the class chips.
class ScheduleBody extends StatelessWidget {
  final List<Map<String, dynamic>> classes;
  final bool loading;
  final bool failed;
  final bool expanded;
  const ScheduleBody({
    super.key,
    required this.classes,
    required this.loading,
    required this.failed,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final n = classes.length;
    final summaryText = failed
        ? 'Chưa tải được lịch dạy từ máy chủ'
        : n == 0
        ? 'Hôm nay bạn không có lịch dạy nào 🎉'
        : 'Hôm nay bạn có $n lịch dạy — nhấn để xem chi tiết';
    if (loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Column(children: [SkeletonChip(), SkeletonChip()]),
      );
    }
    if (failed) return const SizedBox.shrink();
    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/gv_schedule'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  n == 0 ? Icons.event_available : Icons.event_note,
                  size: 18,
                  color: n == 0 ? Colors.green : VdColors.terracotta,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: n == 0
                      ? Text(
                          summaryText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        )
                      : RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                            children: [
                              const TextSpan(text: 'Hôm nay bạn có '),
                              TextSpan(
                                text: '$n',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(
                                text: ' lịch dạy — nhấn để xem chi tiết',
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (classes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.event_available, size: 18, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Không có lịch dạy hôm nay',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        children: classes
            .map(
              (d) => GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/gv_schedule'),
                child: GvClassChip(data: d),
              ),
            )
            .toList(),
      ),
    );
  }
}
