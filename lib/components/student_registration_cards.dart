import 'package:flutter/material.dart';
import '../models/crm_registration_models.dart';
import '../theme/vd_tokens.dart';

String _fmtDate(DateTime? d) => d == null
    ? '–'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class RegistrationPeriodCard extends StatelessWidget {
  final CrmRegistrationPeriod period;
  const RegistrationPeriodCard({super.key, required this.period});
  @override
  Widget build(BuildContext context) {
    final open = period.isOpen;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: open ? context.vd.successSoft : context.vd.surfaceAlt,
        border: Border.all(
          color: open ? context.vd.success : context.vd.hairline,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            open ? Icons.lock_open_rounded : Icons.lock_rounded,
            color: open ? context.vd.success : context.vd.inkMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  open ? 'Đang mở đăng ký' : 'Đợt đăng ký đã đóng',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: open ? context.vd.success : context.vd.inkMuted,
                  ),
                ),
                if (period.startAt != null && period.endAt != null)
                  Text(
                    '${_fmtDate(period.startAt)} – ${_fmtDate(period.endAt)}',
                    style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RegistrationResultCard extends StatelessWidget {
  final CrmRegistrationResult result;
  const RegistrationResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isEms = result.isEmsRequest;
    final color = isEms ? context.vd.success : context.vd.info;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.subjectName ?? result.classCode ?? '–',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.classCode ?? '–',
                  style: TextStyle(fontSize: 11, color: context.vd.inkFaint),
                ),
                if (isEms && !result.syncedToIms) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ghi nhận ở EMS, chưa gửi tới Phòng Đào tạo (IMS).',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.vd.accent,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              result.sourceLabel,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegistrationOfferingCard extends StatelessWidget {
  final CrmRegistrationOffering mon;
  final bool isRegistered;
  final bool isProcessing;
  final bool canRegister;
  final bool allSections;
  final VoidCallback onToggle;
  const RegistrationOfferingCard({
    super.key,
    required this.mon,
    required this.isRegistered,
    required this.isProcessing,
    required this.canRegister,
    required this.allSections,
    required this.onToggle,
  });

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
                'Sĩ số: ${mon.registeredCount ?? '—'}/${mon.maxSize}',
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
              height: 40,
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
                          ? () => onToggle()
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
