import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../theme/vd_tokens.dart';
import 'student_id_qr_card.dart';

// Large view and the code itself for the student-ID look-up QR. Look-up at a
// desk only, NOT proof of identity: no signature, no token, no attendance use.

/// Large view of the student-ID QR (same look-up-only code, see
/// [StudentIdQrCard]): dark modules on white in both themes, wide quiet zone.
Future<void> showStudentIdQrDialog(
  BuildContext context, {
  required String name,
  required String studentId,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      key: const Key('student-id-qr-dialog'),
      backgroundColor: ctx.vd.qrPaper,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const Key('student-id-qr-close'),
                tooltip: 'Đóng',
                iconSize: 28,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                color: ctx.vd.qrInk,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: LayoutBuilder(
                builder: (_, c) {
                  final side = c.maxWidth.clamp(0.0, 300.0).toDouble();
                  return StudentIdQrCode(data: studentId, size: side);
                },
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ctx.vd.qrInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MSSV: $studentId',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: ctx.vd.qrInk),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The code itself on a white field. The white margin is 14% of [size]:
/// at least 4 modules of quiet zone for a short ID (21 or 25 modules wide).
/// Look-up only, see [StudentIdQrCard].
class StudentIdQrCode extends StatelessWidget {
  /// Exactly what the QR encodes: the student ID string, nothing else.
  final String data;
  final double size;
  const StudentIdQrCode({super.key, required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    final padding = size * 0.14;
    return Semantics(
      label: StudentIdQrCard.semanticLabel(data),
      image: true,
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: context.vd.qrPaper,
            borderRadius: BorderRadius.circular(8),
          ),
          child: QrImageView(
            data: data,
            size: size - padding * 2,
            padding: EdgeInsets.zero,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            backgroundColor: context.vd.qrPaper,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: context.vd.qrInk,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: context.vd.qrInk,
            ),
          ),
        ),
      ),
    );
  }
}
