import 'dart:math' as math;

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
class CosmeticAvatar extends StatefulWidget {
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
  State<CosmeticAvatar> createState() => _CosmeticAvatarState();
}

class _CosmeticAvatarState extends State<CosmeticAvatar>
    with SingleTickerProviderStateMixin {
  late final _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _rotation.stop();
      _rotation.value = 0;
    } else {
      _rotation.repeat();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final frame = widget.frame;
    final size = widget.size;
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words.isEmpty || words.first.isEmpty
        ? '?'
        : words.last.characters.first.toUpperCase();
    final ring = frame == null
        ? context.vd.hairline
        : frameColor(context, frame.frameToken);
    return AnimatedBuilder(
      animation: _rotation,
      builder: (context, child) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(frame == null ? 2 : 5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [ring, context.vd.surface, ring],
            transform: GradientRotation(_rotation.value * 2 * math.pi),
          ),
          boxShadow: [
            BoxShadow(color: ring.withValues(alpha: 0.22), blurRadius: 20),
          ],
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
    return Material(
      color: equipped ? context.vd.accentSoft : context.vd.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: equipped ? context.vd.accent : context.vd.hairline,
            ),
            boxShadow: equipped
                ? [
                    BoxShadow(
                      color: context.vd.accent.withValues(alpha: 0.18),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              if (c.isFrame)
                CosmeticAvatar(name: c.name, frame: c, size: 46)
              else
                Icon(Icons.military_tech, size: 46, color: context.vd.warning),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Text(
                    c.title ?? c.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.vd.ink,
                    ),
                  ),
                ),
              ),
              Text(
                c.isFrame ? 'Khung ảnh' : 'Danh hiệu',
                style: TextStyle(fontSize: 10, color: context.vd.inkMuted),
              ),
              const SizedBox(height: 7),
              Text(
                equipped ? '✓ Đang dùng' : 'Trang bị',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: equipped ? context.vd.success : context.vd.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
