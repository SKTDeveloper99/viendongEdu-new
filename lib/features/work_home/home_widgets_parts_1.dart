part of 'home_widgets.dart';

BoxDecoration _cardDeco(VdTokens t) => BoxDecoration(
  color: t.surface,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: t.hairline),
  boxShadow: [
    BoxShadow(color: t.shadow, blurRadius: 10, offset: const Offset(0, 4)),
  ],
);

/// One calm line when nothing waits.
class CalmFocusCard extends StatelessWidget {
  final String text;
  final IconData icon;
  const CalmFocusCard({
    super.key,
    required this.text,
    this.icon = Icons.check_circle_outline,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _cardDeco(t),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: t.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: t.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The home's focus card, compact so the home never scrolls on a small phone:
/// a status chip and a right-hand note, one title line, one detail line, and
/// the action beside them.
class CompactFocusCard extends StatelessWidget {
  final String chip;
  final bool live;
  final bool warn;
  final String right;
  final String title;
  final String line;
  final String action;
  final VoidCallback onAction;
  const CompactFocusCard({
    super.key,
    required this.chip,
    this.live = false,
    this.warn = false,
    required this.right,
    required this.title,
    required this.line,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    final tone = warn ? t.warning : (live ? t.success : t.primary);
    final soft = warn ? t.warningSoft : (live ? t.successSoft : t.accentSoft);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: _cardDeco(t),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: soft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 7, color: tone),
                          const SizedBox(width: 6),
                          Text(
                            chip,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: tone,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        right,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Owner 2026-11-17: a long title wraps to a second
                          // line instead of being cut with "…".
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: t.ink,
                            ),
                          ),
                          if (line.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              line,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: t.inkMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 40),
                      ),
                      child: Text(action),
                    ),
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

/// "Tiếp theo": what waits after the focus card, on a phone tall enough.
class NextList extends StatelessWidget {
  final List<Map> items;
  final void Function(String taskId) onOpen;
  const NextList({super.key, required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 18,
            child: Text(
              'TIẾP THEO',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: t.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (final q in items)
            SizedBox(
              height: 52,
              child: VdPressable(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onOpen('${q['task_id']}'),
                  child: Row(
                    children: [
                      Icon(
                        q['kind'] == 'review'
                            ? Icons.fact_check_outlined
                            : Icons.schedule,
                        size: 20,
                        color: q['kind'] == 'review' ? t.warning : t.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${q['title'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: t.ink,
                              ),
                            ),
                            Text(
                              q['kind'] == 'review'
                                  ? 'Chờ duyệt · ${q['person'] ?? ''}'
                                  : (dueLabel(q['at']).isEmpty
                                        ? 'Việc của tôi'
                                        : dueLabel(q['at'])),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: t.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: t.inkFaint),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
