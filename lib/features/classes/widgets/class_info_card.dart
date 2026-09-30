import 'package:flutter/material.dart';

import '../class_models.dart';
import '../../../theme/vd_tokens.dart';

/// Class code, subject code, credits and teacher.
class ClassInfoCard extends StatelessWidget {
  final ClassItem item;
  const ClassInfoCard({super.key, required this.item});

  Widget _divider(BuildContext context) => Divider(
      height: 1, indent: 48, endIndent: 16, color: context.vd.hairline);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: context.vd.shadow, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _InfoRow(Icons.tag, 'Mã lớp', item.lmhma),
          _divider(context),
          _InfoRow(Icons.book_outlined, 'Mã môn', item.mhma),
          _divider(context),
          _InfoRow(Icons.school_outlined, 'Tín chỉ', '${item.sotinchi} TC'),
          _divider(context),
          _InfoRow(Icons.person_outline, 'Giảng viên', item.gvten),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: context.vd.primary, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: context.vd.inkMuted)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
