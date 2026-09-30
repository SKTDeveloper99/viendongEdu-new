import 'package:flutter/material.dart';

import '../class_models.dart';

/// Midterm / final / total scores exactly as the server sent them.
class ClassGradeCard extends StatelessWidget {
  final ClassItem item;
  const ClassGradeCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Điểm số',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              if (item.diemcc != null)
                Expanded(child: _ScoreBox('Chuyên cần', item.diemcc!)),
              if (item.diemgk != null) ...[
                const SizedBox(width: 10),
                Expanded(child: _ScoreBox('Giữa kỳ', item.diemgk!)),
              ],
              if (item.diemck != null) ...[
                const SizedBox(width: 10),
                Expanded(child: _ScoreBox('Cuối kỳ', item.diemck!)),
              ],
            ],
          ),
          if (item.tongdiem != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('Tổng kết',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const Spacer(),
                  Text(item.tongdiem!.toStringAsFixed(1),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final double value;
  const _ScoreBox(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value % 1 == 0 ? value.toInt().toString() : value.toString(),
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
