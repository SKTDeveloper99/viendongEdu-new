import 'package:flutter/material.dart';

import '../class_detail_screen.dart';
import '../class_models.dart';

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 96,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
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
                    _titleRow(),
                    const SizedBox(height: 5),
                    _line(Icons.person_outline, item.gvten, ellipsis: false),
                    const SizedBox(height: 4),
                    _line(Icons.tag, item.lmhma, ellipsis: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleRow() {
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
              color: const Color(0xFFE65100).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${item.sotinchi} TC',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100)),
            ),
          ),
      ],
    );
  }

  Widget _line(IconData icon, String text, {required bool ellipsis}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFFE65100)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              overflow: ellipsis ? TextOverflow.ellipsis : null,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      ],
    );
  }
}
