import 'package:flutter/material.dart';

import '../../components/rolling_count.dart';
import '../../components/vd_pressable.dart';
import '../../theme/vd_tokens.dart';
import '../work/work_api.dart';

part 'home_widgets_parts_1.dart';

/// One place the home offers: icon, one word, a badge only for what waits.
class HomeTileSpec {
  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onTap;
  const HomeTileSpec(
    this.icon,
    this.label, {
    this.badge = 0,
    required this.onTap,
  });
}

/// The tile grid. Rule: 5 or 6 places go three across (a fifth and sixth sit
/// centred under the first row, same width); 4 or fewer go two across. So a
/// short set reads as intended, never as a hole.
class HomeTileGrid extends StatelessWidget {
  final List<HomeTileSpec> tiles;
  const HomeTileGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final cols = tiles.length >= 5 ? 3 : 2;
    final rows = (tiles.length / cols).ceil();
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        // Tiles take the height that is left, within sensible bounds.
        final h = c.maxHeight.isFinite
            ? ((c.maxHeight - gap * (rows - 1)) / rows).clamp(64.0, 240.0)
            : (cols == 3 ? 104.0 : 92.0);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: WrapAlignment.center,
          children: [
            for (final t in tiles)
              SizedBox(
                width: w,
                height: h,
                child: HomeTile(
                  spec: t,
                  wide: cols == 2,
                  compact: h < 92,
                  scale: (h / 112).clamp(0.8, 1.6),
                ),
              ),
          ],
        );
      },
    );
  }
}

class HomeTile extends StatelessWidget {
  final HomeTileSpec spec;
  final bool wide;
  final bool compact;
  final double scale;
  const HomeTile({
    super.key,
    required this.spec,
    this.wide = false,
    this.compact = false,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    final d = (compact ? 36.0 : 44.0) * (scale > 1 ? scale : 1);
    final icon = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(color: t.accentSoft, shape: BoxShape.circle),
      child: Icon(
        spec.icon,
        color: t.primary,
        size: (compact ? 20.0 : 24.0) * (scale > 1 ? scale : 1),
      ),
    );
    final label = Text(
      spec.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink),
    );
    return VdPressable(
      child: Semantics(
        button: true,
        label: spec.badge > 0
            ? '${spec.label}, ${spec.badge} đang chờ'
            : spec.label,
        child: Material(
          color: t.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: spec.onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.hairline),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: wide
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              icon,
                              const SizedBox(width: 12),
                              Flexible(child: label),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [icon, const SizedBox(height: 10), label],
                          ),
                  ),
                  if (spec.badge > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(minWidth: 22),
                        decoration: BoxDecoration(
                          color: t.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: RollingCount(
                          spec.badge > 99 ? '99+' : '${spec.badge}',
                          style: TextStyle(
                            color: t.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The office state of the home's focus card, drawn like NextUpCard so the
/// three homes read as one app: what waits for my check, else the piece due
/// soonest, else one calm line.
class OfficeFocusCard extends StatelessWidget {
  final Map<String, dynamic>? counts;
  final VoidCallback onReview;
  final void Function(String taskId) onPiece;
  const OfficeFocusCard({
    super.key,
    required this.counts,
    required this.onReview,
    required this.onPiece,
  });

  static String? statusOf(Map<String, dynamic>? c) {
    if (c == null) return null;
    final review = asInt(c['to_review']);
    final due = c['next_due'] as Map?;
    if (review > 0) return '$review bài nộp chờ bạn duyệt';
    if (due != null) return 'Sắp đến hạn: ${due['title']}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = counts;
    if (c == null) return const FocusSkeleton();
    final review = asInt(c['to_review']);
    final first = c['first_review'] as Map?;
    final due = c['next_due'] as Map?;
    if (review > 0) {
      return CompactFocusCard(
        chip: 'Chờ bạn duyệt',
        warn: true,
        right: '$review bài nộp',
        title: '${first?['title'] ?? ''}',
        line: first == null
            ? ''
            : '${first['person'] ?? ''} · nộp lúc ${whenLabel(first['submitted_at'])}',
        action: 'Duyệt',
        onAction: onReview,
      );
    }
    if (due != null) {
      return CompactFocusCard(
        chip: 'Sắp đến hạn',
        right: dueLabel(due['due_at']),
        title: '${due['title'] ?? ''}',
        line: '',
        action: 'Mở',
        onAction: () => onPiece('${due['task_id']}'),
      );
    }
    return const CalmFocusCard(text: 'Không có việc nào đang chờ bạn.');
  }
}

/// A round header button (Tin nhắn, account initials) matching the bell.
class HeaderRoundButton extends StatelessWidget {
  final IconData? icon;
  final String? initials;
  final int badge;
  final String label;
  final VoidCallback onTap;
  const HeaderRoundButton({
    super.key,
    this.icon,
    this.initials,
    this.badge = 0,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    return VdPressable(
      child: Semantics(
        button: true,
        label: badge > 0 ? '$label, $badge chưa đọc' : label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.onHeader.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: icon != null
                        ? Icon(icon, color: t.onHeader, size: 22)
                        : Text(
                            initials ?? '',
                            style: TextStyle(
                              color: t.onHeader,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: BoxDecoration(
                          color: t.danger,
                          shape: BoxShape.circle,
                        ),
                        child: ExcludeSemantics(
                          child: RollingCount(
                            badge > 99 ? '99+' : '$badge',
                            style: TextStyle(
                              color: t.onHeader,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row on a hub screen (Lịch, Lớp, Văn phòng, Thêm).
class HubRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const HubRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VdPressable(
        child: Material(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: t.hairline),
            ),
            leading: CircleAvatar(
              backgroundColor: t.accentSoft,
              child: Icon(icon, color: t.primary),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: subtitle == null ? null : Text(subtitle!),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts[parts.length - 2].characters.first +
          parts.last.characters.first)
      .toUpperCase();
}

/// Placeholder while today's classes load (static; no shimmer).
class FocusSkeleton extends StatelessWidget {
  const FocusSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 96,
    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    decoration: BoxDecoration(
      color: context.vd.surfaceAlt,
      borderRadius: BorderRadius.circular(18),
    ),
  );
}
