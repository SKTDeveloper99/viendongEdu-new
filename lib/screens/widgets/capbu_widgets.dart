part of '../capbu_screen.dart';

class _CapBuCard extends StatelessWidget {
  final CrmCapBuItem item;
  final VoidCallback onTap;
  const _CapBuCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
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
          border: Border(left: BorderSide(color: context.vd.accent, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tên + số tiền
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.ten ?? '–',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fmtAmount(item.thanhTien),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.vd.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Học kỳ — dùng hocky_ten (nhãn đầy đủ) thay vì hocKy IMS cũ.
              Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 13,
                    color: context.vd.inkFaint,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.hocKyTen ?? '–',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.vd.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Mã + ngày cấp
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.tag, size: 13, color: context.vd.inkFaint),
                  const SizedBox(width: 5),
                  Text(
                    'Mã: ${item.ma ?? '–'}',
                    style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
                  ),
                  Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: context.vd.inkFaint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _fmtDate(item.ngayCap),
                    style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detail Sheet ─────────────────────────────────────
class _CapBuDetailSheet extends StatelessWidget {
  final CrmCapBuItem item;
  const _CapBuDetailSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.vd.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            item.ten ?? '–',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _fmtAmount(item.thanhTien),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.vd.accent,
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: context.vd.surfaceAlt),
          const SizedBox(height: 16),
          _Row(icon: Icons.tag, label: 'Mã HĐ', value: item.ma ?? '–'),
          const SizedBox(height: 10),
          _Row(
            icon: Icons.confirmation_number_outlined,
            label: 'Ký hiệu',
            value: item.kyHieu ?? '–',
          ),
          const SizedBox(height: 10),
          _Row(
            icon: Icons.school_outlined,
            label: 'Học kỳ',
            value: item.hocKyTen ?? '–',
          ),
          const SizedBox(height: 10),
          _Row(
            icon: Icons.calendar_today,
            label: 'Ngày cấp',
            value: _fmtDate(item.ngayCap),
          ),
          const SizedBox(height: 10),
          _Row(
            icon: Icons.price_change_outlined,
            label: 'Đơn giá',
            value: _fmtAmount(item.donGia),
          ),
          const SizedBox(height: 10),
          _Row(
            icon: Icons.payments_outlined,
            label: 'Thành tiền',
            value: _fmtAmount(item.thanhTien),
          ),
          const SizedBox(height: 10),
          _Row(
            icon: Icons.calculate_outlined,
            label: 'Tổng cộng',
            value: _fmtAmount(item.total),
          ),
          if ((item.ghiChu ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _Row(
              icon: Icons.notes_outlined,
              label: 'Ghi chú',
              value: item.ghiChu!,
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.vd.accent),
        const SizedBox(width: 10),
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: context.vd.inkFaint),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.vd.ink,
            ),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}
