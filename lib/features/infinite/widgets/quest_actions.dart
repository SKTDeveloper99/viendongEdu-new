import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';
import '../quest.dart';
import 'qr_scan_sheet.dart';

/// The playable part of a quest card: quiz choices, a code field or the QR
/// scanner, the link button and the claim button.
class QuestActions extends StatefulWidget {
  const QuestActions({
    super.key,
    required this.quest,
    required this.needsOpen,
    required this.busy,
    required this.onOpen,
    required this.onClaim,
  });

  final Quest quest;
  final bool needsOpen;
  final bool busy;
  final VoidCallback onOpen;
  final void Function(String code) onClaim;

  @override
  State<QuestActions> createState() => _QuestActionsState();
}

class _QuestActionsState extends State<QuestActions> {
  final _code = TextEditingController();
  String? _choice;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QrScanSheet(hint: widget.quest.hint),
    );
    if (value == null || !mounted) return;
    widget.onClaim(value);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: _actions(context, widget.quest),
  );

  List<Widget> _actions(BuildContext context, Quest q) {
    final vd = context.vd;
    final claimIcon = widget.busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(q.atSchool ? Icons.location_on : Icons.redeem_rounded, size: 18);
    final locked = widget.busy || widget.needsOpen;
    return [
      if (q.kind == QuestKind.quiz) ...[
        const SizedBox(height: 12),
        if (q.question != null)
          Text(
            q.question!,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in q.choices)
              ChoiceChip(
                label: Text(c),
                selected: _choice == c,
                onSelected: (_) => setState(() => _choice = c),
              ),
          ],
        ),
      ],
      if (q.kind == QuestKind.code) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _code,
          // ASCII keyboard: Vietnamese Telex turns "vd" into "Về".
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Mã bí mật',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
      if (q.hint != null && q.kind != QuestKind.qr) ...[
        const SizedBox(height: 6),
        Text(q.hint!, style: TextStyle(color: vd.inkFaint, fontSize: 12)),
      ],
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          if (q.url != null)
            OutlinedButton.icon(
              onPressed: widget.onOpen,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Mở liên kết'),
            ),
          if (q.kind == QuestKind.qr)
            FilledButton.icon(
              onPressed: locked ? null : _scan,
              icon: widget.busy
                  ? claimIcon
                  : const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Quét mã QR'),
            )
          else
            FilledButton.icon(
              onPressed: locked
                  ? null
                  : () => widget.onClaim(
                      q.kind == QuestKind.quiz ? _choice ?? '' : _code.text,
                    ),
              icon: claimIcon,
              label: const Text('Nhận thưởng'),
            ),
        ],
      ),
    ];
  }
}
