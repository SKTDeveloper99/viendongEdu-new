import 'package:flutter/material.dart';

import '../student_home_view_model.dart';
import '../../../theme/vd_tokens.dart';

/// "Thông tin mới từ trung tâm" — latest board item, or the retry card.
class BoardCard extends StatelessWidget {
  final StudentHomeViewModel vm;
  const BoardCard({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    // Chưa có gì để nói và cũng không lỗi → không chiếm chỗ trên trang chủ.
    // Học viên chưa có tài khoản EMS cũng không thấy thẻ này (emsDenied).
    if (vm.latestBoardItem == null && !vm.boardFailed) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Material(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            if (vm.boardFailed && vm.latestBoardItem == null) {
              vm.loadBoard();
              return;
            }
            await Navigator.pushNamed(context, '/student_board');
            vm.loadBoard();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.vd.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.campaign_outlined,
                    color: context.vd.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Thông tin mới từ trung tâm',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.vd.primary,
                            ),
                          ),
                          if (vm.boardUnread > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: context.vd.danger,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${vm.boardUnread} chưa đọc',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.vd.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vm.latestBoardItem?.title ??
                            'Không tải được bảng tin. Chạm để thử lại.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.vd.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
