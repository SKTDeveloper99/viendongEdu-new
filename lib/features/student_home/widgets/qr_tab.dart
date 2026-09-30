import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../student_home_view_model.dart';
import '../../../theme/vd_tokens.dart';

/// QR tab: the student's MSSV as a code for attendance scanning.
class QrTab extends StatelessWidget {
  final StudentHomeViewModel vm;
  const QrTab({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.vd.surfaceAlt,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.vd.headerTop, context.vd.headerBottom],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Text(
                  vm.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.vd.onHeader,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'MSSV: ${vm.mssv}',
                  style: TextStyle(fontSize: 14, color: context.vd.onHeader.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.vd.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: context.vd.shadow,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: QrImageView(data: vm.mssv, size: 220),
          ),
          const SizedBox(height: 16),
          Text(
            'Quét mã để điểm danh',
            style: TextStyle(color: context.vd.inkMuted, fontSize: 14),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
