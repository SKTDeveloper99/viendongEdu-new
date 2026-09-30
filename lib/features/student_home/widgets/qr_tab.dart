import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../theme/vd_theme.dart';
import '../student_home_view_model.dart';

/// QR tab: the student's MSSV as a code for attendance scanning.
class QrTab extends StatelessWidget {
  final StudentHomeViewModel vm;
  const QrTab({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [VdColors.headerTop, VdColors.headerBottom],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Text(
                  vm.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'MSSV: ${vm.mssv}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: QrImageView(data: vm.mssv, size: 220),
          ),
          const SizedBox(height: 16),
          const Text(
            'Quét mã để điểm danh',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
