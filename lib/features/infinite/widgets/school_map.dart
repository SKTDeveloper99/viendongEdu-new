import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';
import '../quest.dart';
import 'map_pin.dart';

/// The 3D school picture with a pin per quest. Pinch and drag to explore;
/// tap a pin to open its quest. The picture and pin positions come from the
/// quest book, so a new season can swap both without an app build.
class SchoolMap extends StatefulWidget {
  const SchoolMap({
    super.key,
    required this.map,
    required this.quests,
    required this.isClaimed,
    required this.onTap,
    this.height = 300,
  });

  final MapArt map;
  final List<Quest> quests;
  final bool Function(Quest) isClaimed;
  final void Function(Quest) onTap;
  final double height;

  @override
  State<SchoolMap> createState() => _SchoolMapState();
}

class _SchoolMapState extends State<SchoolMap>
    with SingleTickerProviderStateMixin {
  final _view = TransformationController();
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  double? _laidOutWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _view.dispose();
    super.dispose();
  }

  /// Centre [MapArt.focusX] the first time the viewport width is known.
  void _focus(double viewportW, double imageW) {
    if (_laidOutWidth == viewportW) return;
    _laidOutWidth = viewportW;
    final dx = (imageW * widget.map.focusX - viewportW / 2).clamp(
      0.0,
      (imageW - viewportW).clamp(0.0, double.infinity),
    );
    _view.value = Matrix4.translationValues(-dx, 0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final w = h * widget.map.aspect;
    final pinned = widget.quests.where((q) => q.spot != null).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: h,
        color: context.vd.ink,
        child: LayoutBuilder(
          builder: (context, box) {
            _focus(box.maxWidth, w);
            return InteractiveViewer(
              transformationController: _view,
              constrained: false,
              minScale: 1,
              maxScale: 3,
              boundaryMargin: EdgeInsets.zero,
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  children: [
                    Positioned.fill(child: _picture(context)),
                    for (final q in pinned)
                      Positioned(
                        left: q.spot!.x * w - 22,
                        top: q.spot!.y * h - 50,
                        child: MapPin(
                          quest: q,
                          claimed: widget.isClaimed(q),
                          pulse: _pulse,
                          onTap: () => widget.onTap(q),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _picture(BuildContext context) {
    final bundled = Image.asset(
      widget.map.asset,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    final url = widget.map.url;
    if (url == null) return bundled;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => bundled,
      errorWidget: (_, _, _) => bundled,
    );
  }
}
