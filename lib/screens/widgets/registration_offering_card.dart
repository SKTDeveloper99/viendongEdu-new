part of '../registration_screen.dart';

class _OfferingCard extends StatelessWidget {
  const _OfferingCard({
    required this.mon,
    required this.isRegistered,
    required this.isProcessing,
    required this.canRegister,
    required this.allSections,
    required this.onToggle,
  });
  final CrmRegistrationOffering mon;
  final bool isRegistered, isProcessing, canRegister, allSections;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final full =
        mon.maxSize != null &&
        mon.registeredCount != null &&
        mon.registeredCount! >= mon.maxSize!;

    return Container(
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRegistered ? context.vd.success : context.vd.hairline,
          width: isRegistered ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.vd.shadow,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    mon.subjectName ?? '–',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isRegistered) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.vd.successSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Đã gửi (EMS)',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.vd.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _infoRow(context, Icons.tag_rounded, mon.subjectCode ?? '–'),
            _infoRow(
              context,
              Icons.person_outline_rounded,
              (mon.teacherName ?? '').isNotEmpty ? mon.teacherName! : '–',
            ),
            _infoRow(
              context,
              Icons.location_on_outlined,
              mon.facilityName ?? '–',
            ),
            _infoRow(
              context,
              Icons.star_border_rounded,
              '${mon.credits ?? '–'} tín chỉ'
              '${(mon.creditsLt ?? 0) > 0 ? '  ·  LT: ${mon.creditsLt}' : ''}'
              '${(mon.creditsTh ?? 0) > 0 ? '  ·  TH: ${mon.creditsTh}' : ''}',
            ),
            if (mon.maxSize != null)
              _infoRow(
                context,
                Icons.groups_outlined,
                'Sĩ số: ${mon.registeredCount ?? 0}/${mon.maxSize}',
              ),
            // Chỉ có ý nghĩa khi đang "Xem tất cả lớp" (chế độ mặc định đã
            // tự lọc theo chương trình rồi, mọi thẻ đều trong chương trình).
            if (allSections && mon.inMyCurriculum == false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ngoài chương trình học của bạn',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.vd.inkMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48 * MediaQuery.textScalerOf(context).scale(1),
              child: isProcessing
                  ? Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: context.vd.primary,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: (canRegister && !(full && !isRegistered))
                          ? onToggle
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRegistered
                            ? context.vd.dangerSoft
                            : context.vd.primary,
                        foregroundColor: isRegistered
                            ? context.vd.danger
                            : context.vd.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        disabledBackgroundColor: context.vd.hairline,
                      ),
                      child: Text(
                        isRegistered
                            ? 'Hủy đăng ký'
                            : full
                            ? 'Lớp đã đầy'
                            : 'Đăng ký',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 14, color: context.vd.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: context.vd.ink),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
