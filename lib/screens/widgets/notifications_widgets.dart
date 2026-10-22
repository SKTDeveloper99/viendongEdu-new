part of '../notifications_screen.dart';

class _NotiCard extends StatelessWidget {
  final _Noti noti;
  final String Function(DateTime?) formatDate;
  final VoidCallback onTap;

  const _NotiCard({
    required this.noti,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: noti.isRead ? context.vd.surface : context.vd.accentSoft,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: context.vd.shadow,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          border: noti.isRead
              ? null
              : Border.all(color: context.vd.accentSoft, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: noti.isRead
                    ? context.vd.hairline
                    : context.vd.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                noti.isRead
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                color: noti.isRead ? context.vd.inkFaint : context.vd.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          noti.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: noti.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            color: context.vd.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!noti.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: context.vd.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    noti.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.vd.inkMuted,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatDate(noti.sentAt),
                    style: TextStyle(fontSize: 11, color: context.vd.inkFaint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
