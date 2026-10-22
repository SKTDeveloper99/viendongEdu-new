part of '../gv_lichthi_screen.dart';

class _ExamCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ExamCard({required this.data});

  @override
  State<_ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<_ExamCard> {
  bool _expanded = false;

  String _formatDate(String? raw) {
    if (raw == null || raw.length < 10) return raw ?? '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return raw.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final tenMon = d['_tenMon']?.toString() ?? '';
    final maLop = d['_maLop']?.toString() ?? '';
    final displayName = tenMon.isNotEmpty
        ? tenMon
        : (d['maNhom']?.toString() ?? '');
    final loaiThi = d['loaiThi']?.toString() ?? '';
    final ngayThi = _formatDate(d['ngayThi'] as String?);
    final gioBatDau = d['gioBatDau']?.toString() ?? '';
    final thoiGian = d['thoiGian'] as int? ?? 0;
    final siSo = d['siSo'] as int? ?? 0;
    final hinhThuc = d['hinhThuc']?.toString() ?? '';
    final cb1 = d['canBoCoiThi1']?.toString().trim() ?? '';
    final cb2 = d['canBoCoiThi2']?.toString().trim() ?? '';
    final ghiChu = d['ghiChu']?.toString().trim() ?? '';

    final loaiColor = loaiThi.contains('Giữa')
        ? context.vd.info
        : context.vd.primary;

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
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
        ),
        child: Column(
          children: [
            // ── Summary row ──
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: loaiColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 14, 8, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (maLop.isNotEmpty)
                                      Text(
                                        maLop,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: context.vd.inkMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              if (loaiThi.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: loaiColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    loaiThi,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: loaiColor,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              Icon(
                                _expanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: context.vd.inkFaint,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 13,
                                color: context.vd.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                ngayThi,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.vd.inkMuted,
                                ),
                              ),
                              if (gioBatDau.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.access_time,
                                  size: 13,
                                  color: context.vd.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  gioBatDau,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.vd.inkMuted,
                                  ),
                                ),
                              ],
                              if (thoiGian > 0) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.timer_outlined,
                                  size: 13,
                                  color: context.vd.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$thoiGian phút',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.vd.inkMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Expanded detail ──
            if (_expanded) ...[
              Divider(height: 1, color: context.vd.surfaceAlt),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  children: [
                    if (siSo > 0)
                      _DetailRow(
                        icon: Icons.people_outline,
                        label: 'Sĩ số',
                        value: '$siSo sinh viên',
                      ),
                    if (hinhThuc.isNotEmpty)
                      _DetailRow(
                        icon: Icons.description_outlined,
                        label: 'Hình thức',
                        value: hinhThuc,
                      ),
                    if (cb1.isNotEmpty)
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: 'CB coi thi 1',
                        value: cb1,
                      ),
                    if (cb2.isNotEmpty)
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: 'CB coi thi 2',
                        value: cb2,
                      ),
                    if (ghiChu.isNotEmpty)
                      _DetailRow(
                        icon: Icons.notes,
                        label: 'Ghi chú',
                        value: ghiChu,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: context.vd.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
