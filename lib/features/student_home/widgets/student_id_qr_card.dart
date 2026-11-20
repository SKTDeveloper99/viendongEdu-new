import 'package:flutter/material.dart';
import '../../../theme/vd_tokens.dart';
import 'student_id_qr_view.dart';

/// "Cá nhân" card: the student's name, student ID (MSSV) and a QR code whose
/// content is exactly the student ID string. Tapping it shows the code large.
///
/// This QR is only for look-up at a desk (office staff scan it instead of
/// typing the ID). It is NOT proof of identity: it carries no signature, no
/// token and no secret, and it must never be used for attendance.
///
/// It builds only from the identity already held after sign-in (passed in by
/// the caller), so it works with no signal and makes no network call.
/// Renders nothing when [isStudent] is false or [studentId] is blank.
class StudentIdQrCard extends StatelessWidget {
  final String name;
  final String studentId;
  final bool isStudent;

  const StudentIdQrCard({
    super.key,
    required this.name,
    required this.studentId,
    required this.isStudent,
  });

  /// True when there is a real ID to encode ('–' is the "unknown" filler).
  static bool hasId(String id) {
    final t = id.trim();
    return t.isNotEmpty && t != '–' && t != '-';
  }

  static String semanticLabel(String id) => 'Mã QR của mã số sinh viên $id';

  @override
  Widget build(BuildContext context) {
    if (!isStudent || !hasId(studentId)) return const SizedBox.shrink();
    final id = studentId.trim();
    return Material(
      key: const Key('student-id-qr-card'),
      color: context.vd.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => showStudentIdQrDialog(context, name: name, studentId: id),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: context.vd.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.vd.hairline, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MSSV: $id',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.vd.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Chạm để phóng to mã QR',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.vd.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StudentIdQrCode(data: id, size: 72),
            ],
          ),
        ),
      ),
    );
  }
}
