import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';
import '../quest.dart';

Color frameColor(BuildContext context, String? token) => switch (token) {
  'warning' => context.vd.warning,
  'danger' => context.vd.danger,
  'success' => context.vd.success,
  'evening' => context.vd.evening,
  'accent' => context.vd.accent,
  _ => context.vd.primary,
};

/// Initials in a ring; the ring is the equipped frame, if any.
class CosmeticAvatar extends StatelessWidget {
  const CosmeticAvatar({
    super.key,
    required this.name,
    this.frame,
    this.size = 88,
  });

  final String name;
  final Cosmetic? frame;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words.isEmpty || words.first.isEmpty
        ? '?'
        : words.last.characters.first.toUpperCase();
    final ring = frame == null
        ? context.vd.hairline
        : frameColor(context, frame!.frameToken);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(frame == null ? 2 : 5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [ring, context.vd.surface, ring]),
      ),
      child: CircleAvatar(
        backgroundColor: context.vd.surfaceAlt,
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            color: context.vd.ink,
          ),
        ),
      ),
    );
  }
}

/// One cosmetic the student owns; tap to equip or take off.
class CosmeticTile extends StatelessWidget {
  const CosmeticTile({
    super.key,
    required this.cosmetic,
    required this.equipped,
    required this.onTap,
  });

  final Cosmetic cosmetic;
  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = cosmetic;
    return ListTile(
      onTap: onTap,
      leading: c.isFrame
          ? CosmeticAvatar(name: c.name, frame: c, size: 40)
          : Icon(Icons.military_tech, color: context.vd.warning),
      title: Text(c.title ?? c.name),
      subtitle: Text(c.isFrame ? 'Khung ảnh đại diện' : 'Danh hiệu'),
      trailing: equipped
          ? Icon(Icons.check_circle, color: context.vd.success)
          : Text('Dùng', style: TextStyle(color: context.vd.primary)),
    );
  }
}
