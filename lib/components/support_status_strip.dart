import 'package:flutter/material.dart';

import '../models/support_status.dart';
import '../theme/vd_tokens.dart';

/// Four-step progress of a support request: Đã gửi, Đã tiếp nhận, Đang xử
/// lý, Bạn xác nhận. [compact] is the one-line form for the list of
/// questions; the full form adds the owner, the due time and, while the
/// school waits for the student, the two confirmation buttons.
class SupportStatusStrip extends StatelessWidget {
  final SupportInfo info;
  final bool compact;

  /// Set only when the request waits for the student and the server gave a
  /// confirmation code; the buttons are hidden otherwise.
  final VoidCallback? onSatisfied;
  final VoidCallback? onUnsatisfied;
  final bool busy;

  const SupportStatusStrip({
    super.key,
    required this.info,
    this.compact = false,
    this.onSatisfied,
    this.onUnsatisfied,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final done = info.stepsDone;
    final waiting = info.status == SupportStatus.awaitingConfirmation;
    final steps = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < supportSteps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                // Level with the middle of the dots (10 compact, 18 full).
                margin: EdgeInsets.only(top: compact ? 4 : 8),
                color: i < done ? vd.success : vd.hairline,
              ),
            ),
          _Dot(
            done: i < done,
            current: waiting && i == 3,
            label: compact ? null : supportSteps[i],
          ),
        ],
      ],
    );
    if (compact) {
      return Semantics(
        label: 'Trạng thái yêu cầu: ${info.label}',
        excludeSemantics: true,
        child: Row(
          children: [
            SizedBox(width: 72, child: steps),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                info.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: waiting ? vd.warning : vd.inkMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: vd.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: vd.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trạng thái: ${info.label}',
            style: TextStyle(fontWeight: FontWeight.w700, color: vd.ink),
          ),
          const SizedBox(height: 12),
          steps,
          if (info.ownerName != null) ...[
            const SizedBox(height: 12),
            Text(
              'Người phụ trách: ${info.ownerName}',
              style: TextStyle(fontSize: 13, color: vd.ink),
            ),
          ],
          if (info.showsDue) ...[
            const SizedBox(height: 4),
            Text(
              'Dự kiến phản hồi trước ${supportDueText(info.dueAt!)}',
              style: TextStyle(fontSize: 13, color: vd.inkMuted),
            ),
          ],
          if (waiting) ...[
            const SizedBox(height: 12),
            Text(
              'Nhà trường đã gửi kết quả. Vấn đề của bạn đã được giải quyết chưa?',
              style: TextStyle(fontSize: 13, color: vd.ink),
            ),
            if (onSatisfied != null && onUnsatisfied != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy ? null : onSatisfied,
                    child: const Text('Đã hài lòng'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : onUnsatisfied,
                    child: const Text('Chưa giải quyết'),
                  ),
                ],
              ),
            ] else
              Text(
                'Hãy trả lời trong cuộc trao đổi bên dưới để xác nhận.',
                style: TextStyle(fontSize: 12, color: vd.inkMuted),
              ),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool done;
  final bool current;
  final String? label;
  const _Dot({required this.done, required this.current, this.label});

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final color = done
        ? vd.success
        : current
        ? vd.warning
        : vd.hairline;
    final dot = Container(
      width: label == null ? 10 : 18,
      height: label == null ? 10 : 18,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: done && label != null
          ? Icon(Icons.check, size: 12, color: vd.onPrimary)
          : null,
    );
    if (label == null) return dot;
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          dot,
          const SizedBox(height: 4),
          Text(
            label!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: done || current ? FontWeight.w600 : FontWeight.w400,
              color: done || current ? vd.ink : vd.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
