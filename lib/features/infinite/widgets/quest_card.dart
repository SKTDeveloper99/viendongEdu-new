import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';
import '../quest.dart';
import 'map_pin.dart';
import 'quest_actions.dart';

/// One quest, drawn for its kind: check in, open a link, type a code,
/// scan a QR, or answer a quiz. Unknown kinds ask for an app update.
class QuestCard extends StatelessWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.rewards,
    required this.claimed,
    required this.needsOpen,
    required this.busy,
    required this.onOpen,
    required this.onClaim,
    this.message,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  });

  /// Result of the last claim attempt, shown under the buttons.
  final String? message;

  final Quest quest;
  final List<Cosmetic> rewards;
  final bool claimed;
  final bool needsOpen;
  final bool busy;
  final VoidCallback onOpen;
  final void Function(String code) onClaim;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final q = quest;
    final vd = context.vd;
    return Card(
      color: vd.surface,
      margin: margin,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: claimed ? vd.success : vd.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(questIcon(q), color: claimed ? vd.success : vd.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    q.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (q.spot != null && q.spot!.label.isNotEmpty)
                  Text(
                    q.spot!.label,
                    style: TextStyle(color: vd.inkFaint, fontSize: 12),
                  ),
              ],
            ),
            if (q.desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(q.desc, style: TextStyle(color: vd.inkMuted)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in rewards)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: vd.warningSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '✦ ${c.title ?? c.name}',
                      style: TextStyle(
                        color: vd.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (claimed) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: vd.success),
                  const SizedBox(width: 6),
                  Text(
                    'Đã xong',
                    style: TextStyle(
                      color: vd.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ] else if (!q.playable) ...[
              const SizedBox(height: 14),
              Text(
                'Cập nhật ứng dụng để chơi nhiệm vụ này.',
                style: TextStyle(
                  color: vd.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else
              QuestActions(
                quest: q,
                needsOpen: needsOpen,
                busy: busy,
                onOpen: onOpen,
                onClaim: onClaim,
              ),
            if (message != null && !claimed) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                style: TextStyle(color: vd.danger, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
