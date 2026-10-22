part of '../exam_screen.dart';

class _ExamCard extends StatelessWidget {
  final ExamItem exam;
  const _ExamCard({required this.exam});

  Color _loaiColor(BuildContext context) =>
      exam.loaiThi.contains('Giữa') ? context.vd.info : context.vd.accent;

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        children: [
          // Thanh màu trái
          Container(
            width: 5,
            height: 100,
            decoration: BoxDecoration(
              color: _loaiColor(context),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên môn + badge loại thi
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exam.mhten,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: _loaiColor(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          exam.loaiThi,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _loaiColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Ngày + giờ
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
                        exam.ngayThiFormatted,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.vd.inkMuted,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: context.vd.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        exam.gioBatDau,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.vd.inkMuted,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: context.vd.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${exam.thoiGian} phút',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.vd.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Phòng thi
                  Row(
                    children: [
                      Icon(Icons.room, size: 13, color: context.vd.primary),
                      const SizedBox(width: 4),
                      Text(
                        exam.phongten,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.vd.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
