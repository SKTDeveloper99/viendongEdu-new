import 'package:flutter/material.dart';
import '../grade_item.dart';
import '../../../theme/vd_tokens.dart';

// ── Chưa đạt Tab ─────────────────────────────────────────
class RemainingSubjectsTab extends StatelessWidget {
  final List<RemainingSubjectItem> items;
  const RemainingSubjectsTab({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty_rounded, size: 64, color: context.vd.inkFaint),
            SizedBox(height: 12),
            Text('Không còn môn chưa học',
                style: TextStyle(color: context.vd.inkMuted)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.vd.accentSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length} môn chưa học',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.vd.primary),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final mhten = item.name;
              final mhma = item.code;
              final sotinchi = item.credits;
              final trangthai = item.status;

              final (statusLabel, statusColor) = switch (trangthai) {
                1 => ('Đang học', context.vd.info),
                2 => ('Không đạt', context.vd.danger),
                _ => ('Chưa học', context.vd.primary),
              };

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: context.vd.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: context.vd.shadow,
                        blurRadius: 5,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 68,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mhten,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.school_outlined,
                                    size: 12, color: context.vd.primary),
                                const SizedBox(width: 4),
                                Text('$sotinchi TC',
                                    style: TextStyle(
                                        fontSize: 12, color: context.vd.inkMuted)),
                                const SizedBox(width: 12),
                                Icon(Icons.tag,
                                    size: 12, color: context.vd.primary),
                                const SizedBox(width: 4),
                                Text(mhma,
                                    style: TextStyle(
                                        fontSize: 12, color: context.vd.inkMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
