import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/vd_motion.dart';
import '../../../theme/vd_tokens.dart';
import '../pet.dart';
import '../pet_motion.dart';

class PetCompanion extends StatefulWidget {
  const PetCompanion({super.key, required this.pet});

  final InfinitePet pet;

  @override
  State<PetCompanion> createState() => _PetCompanionState();
}

class _PetCompanionState extends State<PetCompanion>
    with TickerProviderStateMixin {
  late final _motion = PetMotion(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion.setReduced(VdMotion.of(context).reduced);
  }

  @override
  void didUpdateWidget(covariant PetCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pet != widget.pet) _motion.reset();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Vuốt ve ${widget.pet.label}',
          value: _motion.isDizzy ? 'Đang chóng mặt' : 'Sẵn sàng chơi',
          child: InkWell(
            key: const ValueKey('pet-tap-target'),
            onTap: _motion.tap,
            borderRadius: BorderRadius.circular(24),
            child: SizedBox.square(
              dimension: 192,
              child: ExcludeSemantics(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      key: const ValueKey('pet-wobble'),
                      angle: _motion.wobble,
                      alignment: Alignment.bottomCenter,
                      child: Transform.scale(
                        key: const ValueKey('pet-squash'),
                        scaleX: _motion.scaleX,
                        scaleY: _motion.scaleY,
                        alignment: Alignment.bottomCenter,
                        child: Image.asset(
                          widget.pet.asset,
                          width: 152,
                          height: 152,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    if (_motion.isDizzy)
                      for (var i = 0; i < 3; i++)
                        Positioned(
                          left:
                              84 +
                              68 *
                                  math.cos(
                                    _motion.starAngle + i * 2 * math.pi / 3,
                                  ),
                          top:
                              30 +
                              20 *
                                  math.sin(
                                    _motion.starAngle + i * 2 * math.pi / 3,
                                  ),
                          child: Transform.rotate(
                            key: ValueKey('pet-star-$i'),
                            angle: _motion.starAngle,
                            child: Icon(Icons.star, color: context.vd.warning),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Text(
          _motion.isDizzy
              ? '${widget.pet.label} chóng mặt rồi, nghỉ một chút nhé!'
              : 'Chạm để chơi với ${widget.pet.label}',
          key: ValueKey(_motion.isDizzy ? 'pet-dizzy' : 'pet-ready'),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.vd.inkMuted),
        ),
      ],
    ),
  );
}
