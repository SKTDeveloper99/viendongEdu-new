import 'package:flutter/material.dart';
import '../grade_item.dart';
import '../../../theme/vd_tokens.dart';

// ── Chưa có điểm Tab ──────────────────────────────────────
class UnscoredSubjectsTab extends StatelessWidget {
  final List<GradeItem> items;
  const UnscoredSubjectsTab({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty_rounded, size: 64, color: context.vd.inkFaint),
            SizedBox(height: 12),
            Text('Không còn môn chưa có điểm',
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.vd.accentSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length} môn chưa có điểm',
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
                        color: context.vd.inkMuted,
                        borderRadius: BorderRadius.horizontal(
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
                            Text(item.mhten,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.school_outlined,
                                    size: 12, color: context.vd.primary),
                                const SizedBox(width: 4),
                                Text('${item.sotinchi} TC',
                                    style: TextStyle(
                                        fontSize: 12, color: context.vd.inkMuted)),
                                const SizedBox(width: 12),
                                Icon(Icons.tag,
                                    size: 12, color: context.vd.primary),
                                const SizedBox(width: 4),
                                Text(item.mhma,
                                    style: TextStyle(
                                        fontSize: 12, color: context.vd.inkMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: Text('Chưa học',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.vd.inkMuted)),
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

