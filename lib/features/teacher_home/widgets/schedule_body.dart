import 'package:flutter/material.dart';

import '../../../components/skeleton.dart';
import '../../../components/vd_fade_in.dart';
import '../../../theme/vd_motion.dart';
import 'gv_class_chip.dart';
import '../../../theme/vd_tokens.dart';

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
    return AnimatedSwitcher(
      duration: VdMotion.of(context).standard,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(
        key: ValueKey<bool>(loading),
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
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
              color: context.vd.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: context.vd.shadow,
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
                  color: n == 0 ? context.vd.success : context.vd.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: n == 0
                      ? Text(
                          summaryText,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.vd.inkMuted,
                          ),
                        )
                      : Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: context.vd.inkMuted,
                            ),
                            children: [
                              const TextSpan(text: 'Hôm nay bạn có '),
                              TextSpan(
                                text: '$n',
                                style: TextStyle(
                                  color: context.vd.danger,
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
            color: context.vd.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: context.vd.shadow,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.event_available, size: 18, color: context.vd.success),
              SizedBox(width: 8),
              Text(
                'Không có lịch dạy hôm nay',
                style: TextStyle(fontSize: 13, color: context.vd.inkMuted),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        children: classes.indexed
            .map(
              (e) => VdFadeIn(
                index: e.$1,
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/gv_schedule'),
                  child: GvClassChip(data: e.$2),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
