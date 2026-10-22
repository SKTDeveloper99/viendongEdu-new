part of '../student_board_screen.dart';

class _BoardImage extends StatelessWidget {
  const _BoardImage({
    required this.image,
    this.inCard = false,
    this.width = 720,
  });
  final int width;
  final AnnouncementImage image;
  final bool inCard;

  @override
  Widget build(BuildContext context) {
    final parsed = Uri.parse(image.absoluteUrl);
    final url = parsed
        .replace(queryParameters: {...parsed.queryParameters, 'w': '$width'})
        .toString();
    final img = CachedNetworkImage(
      imageUrl: url,
      httpHeaders: EmsApiService.authHeaders,
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (_, _) => Container(
        height: inCard ? null : 180,
        color: context.vd.hairline,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.vd.primary,
            ),
          ),
        ),
      ),
      errorWidget: (_, _, _) => Container(
        height: inCard ? null : 140,
        color: context.vd.hairline,
        child: Icon(
          Icons.broken_image_outlined,
          color: context.vd.inkFaint,
          size: 28,
        ),
      ),
    );

    if (inCard) return img;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: image.aspectRatio != null
            ? AspectRatio(aspectRatio: image.aspectRatio!, child: img)
            : img,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.item});
  final AnnouncementItem item;

  @override
  Widget build(BuildContext context) {
    final urgent = item.category == 'urgent';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: urgent ? context.vd.dangerSoft : context.vd.accentSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.isCorrection ? 'Đính chính' : item.categoryLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: urgent ? context.vd.danger : context.vd.primary,
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item, required this.onTap});
  final AnnouncementItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(14),
        border: item.isUnread
            ? Border.all(color: context.vd.accentSoft, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: context.vd.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CategoryChip(item: item),
                    const SizedBox(width: 6),
                    if (item.needsAcknowledgement)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.vd.dangerSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Bắt buộc đọc',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.vd.danger,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (item.isUnread)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: context.vd.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: item.isUnread
                        ? FontWeight.bold
                        : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AnnouncementBody.plainText(item.body).replaceAll('\n', ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: context.vd.inkMuted,
                  ),
                ),
                if (item.images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: item.images.first.aspectRatio ?? 16 / 9,
                      child: _BoardImage(
                        image: item.images.first,
                        inCard: true,
                      ),
                    ),
                  ),
                  if (item.images.length > 1) ...[
                    const SizedBox(height: 6),
                    Text(
                      '+${item.images.length - 1} ảnh nữa',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.vd.inkMuted,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13, color: context.vd.inkFaint),
                    const SizedBox(width: 4),
                    Text(
                      _StudentBoardScreenState._formatDate(item.publishedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.vd.inkFaint,
                      ),
                    ),
                    if (item.acknowledgedAt != null) ...[
                      const Spacer(),
                      Icon(
                        Icons.check_circle,
                        size: 13,
                        color: context.vd.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Đã xác nhận',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.vd.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
