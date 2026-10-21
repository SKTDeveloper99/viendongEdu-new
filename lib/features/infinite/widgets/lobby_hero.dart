import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';
import '../quest.dart';
import 'cosmetic_avatar.dart';

class LobbyHero extends StatelessWidget {
  const LobbyHero({
    super.key,
    required this.name,
    this.frame,
    this.title,
    required this.completed,
    required this.total,
  });

  final String name;
  final Cosmetic? frame;
  final Cosmetic? title;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          context.vd.accentSoft,
          context.vd.surface,
          context.vd.warningSoft,
        ],
      ),
      border: Border.all(color: context.vd.hairline),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 16, color: context.vd.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'SÂN CHƠI SINH VIÊN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.vd.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        CosmeticAvatar(name: name, frame: frame, size: 112),
        const SizedBox(height: 14),
        Text(
          name.isEmpty ? 'Nhà thám hiểm' : name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.vd.ink,
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: context.vd.warningSoft,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.military_tech, size: 18, color: context.vd.warning),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title!.title!,
                    style: TextStyle(
                      color: context.vd.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                'Đã hoàn thành $completed/$total nhiệm vụ',
                style: TextStyle(
                  color: context.vd.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            Icon(Icons.bolt, size: 20, color: context.vd.accent),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : completed / total,
            minHeight: 9,
            color: context.vd.accent,
            backgroundColor: context.vd.hairline,
          ),
        ),
      ],
    ),
  );
}
