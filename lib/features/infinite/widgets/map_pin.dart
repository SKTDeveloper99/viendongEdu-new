import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';
import '../quest.dart';

IconData questIcon(Quest q) => switch (q.kind) {
  QuestKind.checkin => Icons.location_on_rounded,
  QuestKind.link =>
    q.url!.contains('tiktok')
        ? Icons.play_circle_fill_rounded
        : Icons.thumb_up_alt_rounded,
  QuestKind.code => Icons.key_rounded,
  QuestKind.qr => Icons.qr_code_2_rounded,
  QuestKind.quiz => Icons.quiz_rounded,
  QuestKind.unknown => Icons.lock_clock_rounded,
};

/// A round map pin with a tail; pulses until the quest is done.
class MapPin extends StatelessWidget {
  const MapPin({
    super.key,
    required this.quest,
    required this.claimed,
    required this.pulse,
    required this.onTap,
  });

  final Quest quest;
  final bool claimed;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final color = claimed
        ? vd.success
        : quest.playable
        ? vd.primary
        : vd.inkFaint;
    final label = quest.spot!.label.isEmpty ? quest.title : quest.spot!.label;
    return Semantics(
      button: true,
      label: '$label: ${quest.title}${claimed ? ', đã xong' : ''}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 58,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              if (!claimed && quest.playable)
                AnimatedBuilder(
                  animation: pulse,
                  builder: (_, _) => Positioned(
                    top: 22 - 22 * (1 + pulse.value * 0.6),
                    child: Opacity(
                      opacity: (1 - pulse.value) * 0.55,
                      child: Container(
                        width: 44 * (1 + pulse.value * 0.6),
                        height: 44 * (1 + pulse.value * 0.6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: vd.surface, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: vd.shadow,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  claimed ? Icons.check_rounded : questIcon(quest),
                  color: vd.onPrimary,
                  size: 22,
                ),
              ),
              Positioned(
                top: 41,
                child: CustomPaint(
                  size: const Size(14, 10),
                  painter: _Tail(color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tail extends CustomPainter {
  _Tail(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_Tail old) => old.color != color;
}
