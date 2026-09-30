import 'package:flutter/material.dart';

import '../class_detail_screen.dart';
import '../class_models.dart';
import '../../../theme/vd_tokens.dart';

/// One class in the list; tapping opens [ClassDetailScreen].
class ClassCard extends StatelessWidget {
  final ClassItem item;
  final String semTen;
  const ClassCard({super.key, required this.item, required this.semTen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ClassDetailScreen(item: item, semTen: semTen)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.vd.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: context.vd.shadow, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.vd.primary, context.vd.accent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _titleRow(context),
                    const SizedBox(height: 5),
                    _line(context, Icons.person_outline, item.gvten, ellipsis: false),
                    const SizedBox(height: 4),
                    _line(context, Icons.tag, item.lmhma, ellipsis: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            item.mhten,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        if (item.sotinchi > 0)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: context.vd.accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${item.sotinchi} TC',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.vd.primary),
            ),
          ),
      ],
    );
  }

  Widget _line(BuildContext context, IconData icon, String text, {required bool ellipsis}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: context.vd.primary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              overflow: ellipsis ? TextOverflow.ellipsis : null,
              style: TextStyle(fontSize: 12, color: context.vd.inkMuted)),
        ),
      ],
    );
  }
}
