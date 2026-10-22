part of '../tuition_screen.dart';

class _BackButton extends StatelessWidget {
  const _BackButton();
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Quay lại',
    onPressed: () => Navigator.pop(context),
    icon: Icon(Icons.arrow_back_ios, color: context.vd.onPrimary, size: 20),
  );
}

// ── Summary Section ─────────────────────────────────────
class _SummarySection extends StatelessWidget {
  final CrmTuitionSummary? summary;

  const _SummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final unknown = s == null || !s.moneyKnown;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.vd.primary, context.vd.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: context.vd.shadow,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tổng học phí phải đóng',
                style: TextStyle(color: context.vd.onPrimary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                _fmtAmount(s?.owedTotal),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: context.vd.onPrimary,
                ),
              ),
              if (unknown) ...[
                const SizedBox(height: 6),
                Text(
                  s?.moneyUnknownReason ??
                      'Chưa có luật tính học phí cho lớp này.',
                  style: TextStyle(color: context.vd.onPrimary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 4),
              if (s?.paymentStatus != null)
                Text(
                  s!.paymentStatus!,
                  style: TextStyle(color: context.vd.onPrimary, fontSize: 12),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── 2 stat cards — đọc thẳng từ summary, không tự cộng ──
        if (!unknown)
          Row(
            children: [
              Expanded(
                child: _MiniCard(
                  icon: Icons.check_circle_outline,
                  label: 'Đã đóng',
                  text: _fmtAmount(s.paid),
                  color: context.vd.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Còn lại',
                  text: _fmtAmount(s.balance),
                  color: context.vd.danger,
                ),
              ),
            ],
          ),

        if (s != null && (s.otherReceipts.total ?? 0) != 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.vd.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: context.vd.shadow,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khoản thu khác (KHÔNG phải học phí)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.vd.inkFaint,
                  ),
                ),
                const SizedBox(height: 6),
                if ((s.otherReceipts.mienGiamKhenThuong ?? 0) != 0)
                  Text(
                    'Miễn giảm/khen thưởng: ${_fmtAmount(s.otherReceipts.mienGiamKhenThuong)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if ((s.otherReceipts.lePhiKhac ?? 0) != 0)
                  Text(
                    'Lệ phí khác: ${_fmtAmount(s.otherReceipts.lePhiKhac)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if ((s.otherReceipts.hoanPhi ?? 0) != 0)
                  Text(
                    'Hoàn phí: ${_fmtAmount(s.otherReceipts.hoanPhi)}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color color;

  const _MiniCard({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.vd.shadow,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sổ công nợ IMS — nguồn RIÊNG, không gộp với summary phía trên ──
class _CongNoCard extends StatelessWidget {
  final CrmCongNo congNo;
  const _CongNoCard({required this.congNo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.vd.shadow,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sổ công nợ (IMS)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.vd.inkFaint,
            ),
          ),
          const SizedBox(height: 6),
          if (!congNo.computable || congNo.note != null)
            Text(
              congNo.note ?? 'Chưa có nghĩa vụ học phí được ghi nhận.',
              style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
            )
          else ...[
            Text(
              'Phải nộp: ${_fmtAmount(congNo.phaiNop)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Đã nộp: ${_fmtAmount(congNo.daNop)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Công nợ: ${_fmtAmount(congNo.congNo)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Transaction Card ────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  final CrmTuitionPayment item;
  const _TransactionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = item;
    final isPaid = (t.soTien ?? 0) > 0;
    final color = isPaid ? context.vd.success : context.vd.danger;
    final bgColor = isPaid ? context.vd.successSoft : context.vd.dangerSoft;
    final icon = isPaid
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.vd.shadow,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (t.loaiPhieuThu ?? '').trim().isEmpty
                        ? '–'
                        : t.loaiPhieuThu!.trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fmtDate(t.ngayNop),
                    style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
                  ),
                  if ((t.ghiChu ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      t.ghiChu!,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.vd.inkFaint,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Text(
              _fmtAmount(t.soTien),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
