import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';
import '../quest.dart';

/// One quest: open the link, type the code if any, claim at school.
class QuestCard extends StatefulWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.claimed,
    required this.needsOpen,
    required this.busy,
    required this.onOpen,
    required this.onClaim,
  });

  final Quest quest;
  final bool claimed;
  final bool needsOpen;
  final bool busy;
  final VoidCallback onOpen;
  final void Function(String code) onClaim;

  @override
  State<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<QuestCard> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quest;
    final rewards = q.rewards
        .map(cosmeticById)
        .nonNulls
        .map((c) => c.title ?? c.name)
        .join(' • ');
    return Card(
      color: context.vd.surface,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.claimed ? Icons.check_circle : Icons.flag_outlined,
                  color: widget.claimed
                      ? context.vd.success
                      : context.vd.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    q.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (q.desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(q.desc, style: TextStyle(color: context.vd.inkMuted)),
            ],
            if (rewards.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Phần thưởng: $rewards',
                style: TextStyle(color: context.vd.warning),
              ),
            ],
            if (!widget.claimed) ..._actions(context, q),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, Quest q) => [
    if (q.code != null) ...[
      const SizedBox(height: 10),
      TextField(
        controller: _code,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Mã bí mật trong bài đăng',
          isDense: true,
          border: OutlineInputBorder(),
        ),
      ),
    ],
    const SizedBox(height: 10),
    Row(
      children: [
        if (q.url != null)
          OutlinedButton.icon(
            onPressed: widget.onOpen,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Mở liên kết'),
          ),
        const Spacer(),
        FilledButton.icon(
          onPressed: widget.busy || widget.needsOpen
              ? null
              : () => widget.onClaim(_code.text),
          icon: widget.busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.location_on, size: 18),
          label: const Text('Nhận thưởng'),
        ),
      ],
    ),
  ];
}
