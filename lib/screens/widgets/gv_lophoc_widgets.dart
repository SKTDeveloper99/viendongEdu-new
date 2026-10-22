part of '../gv_lophoc_screen.dart';

class _DayHeader extends StatelessWidget {
  final String ngayten;
  final int count;
  const _DayHeader({required this.ngayten, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: context.vd.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ngayten,
              style: TextStyle(
                color: context.vd.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count lớp',
            style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: context.vd.hairline)),
        ],
      ),
    );
  }
}

// ── Lop Card ─────────────────────────────────────────
class _LopCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LopCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final mhten = data['mhten']?.toString() ?? '';
    final lmhma = data['lmhma']?.toString() ?? '';
    final sotinchi = data['sotinchi'] as int? ?? 0;
    final phongten = data['phongten']?.toString() ?? '';
    final tietbd = data['tietbd']?.toString() ?? '';
    final tgbd = data['tgbatdau']?.toString() ?? '';
    final tgkt = data['tgketthuc']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: context.vd.shadow,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
        border: Border(left: BorderSide(color: context.vd.primary, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            // Giờ
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  tgbd,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.vd.primary,
                  ),
                ),
                Text(
                  tgkt,
                  style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.vd.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tietbd,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.vd.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 52, color: context.vd.hairline),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mhten,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (sotinchi > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.vd.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$sotinchi TC',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.vd.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (phongten.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.room, size: 13, color: context.vd.primary),
                        const SizedBox(width: 4),
                        Text(
                          phongten,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.vd.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  if (lmhma.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.class_outlined,
                            size: 13,
                            color: context.vd.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            lmhma,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.vd.inkFaint,
                            ),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
