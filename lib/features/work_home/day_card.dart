import 'package:flutter/material.dart';

import '../../components/vd_pressable.dart';
import '../../theme/vd_tokens.dart';
import 'home_prefs.dart';

/// A greeting the server switches on for one day (`day_card` in
/// GET /api/auth/app/me, CRM lib/app-day-card.js), shown above the focus card.
/// Every word comes from the server; the app gives only the look: brick on
/// cream, no picture, no motion beyond the app's tap effect. One tap closes
/// it and the phone remembers that card's id, so it does not come back.
///
/// The server's `line` may end with a signature on its own line
/// ("...\nTrường Cao đẳng Viễn Đông"); that last line is set apart, right.
class DayCardSlot extends StatefulWidget {
  final Map<String, dynamic>? card;
  const DayCardSlot({super.key, required this.card});

  @override
  State<DayCardSlot> createState() => _DayCardSlotState();
}

class _DayCardSlotState extends State<DayCardSlot> {
  String? _dismissed;
  bool _read = false;

  String get _id => '${widget.card?['id'] ?? ''}';
  String get _title => '${widget.card?['title'] ?? ''}'.trim();

  @override
  void initState() {
    super.initState();
    HomePrefs.dayCardDismissed().then((v) {
      if (!mounted) return;
      setState(() {
        _dismissed = v;
        _read = true;
      });
    });
  }

  void _close() {
    setState(() => _dismissed = _id);
    HomePrefs.setDayCardDismissed(_id);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.card == null || _id.isEmpty || _title.isEmpty) {
      return const SizedBox.shrink();
    }
    // Wait for the phone's memory so a closed card never flashes.
    if (!_read || _dismissed == _id) return const SizedBox.shrink();
    return DayCard(
      title: _title,
      line: '${widget.card?['line'] ?? ''}',
      onClose: _close,
    );
  }
}

class DayCard extends StatelessWidget {
  final String title;
  final String line;
  final VoidCallback onClose;
  const DayCard({
    super.key,
    required this.title,
    required this.line,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final brick = dark ? t.primary : t.headerTop;
    final parts = line.trim().split('\n').map((s) => s.trim()).toList();
    final sign = parts.length > 1 ? parts.removeLast() : '';
    final body = parts.where((s) => s.isNotEmpty).join(' ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VdPressable(
        child: Semantics(
          button: true,
          label: '$title. $body. Chạm để đóng',
          excludeSemantics: true,
          child: Material(
            color: t.surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              key: const ValueKey('day-card'),
              borderRadius: BorderRadius.circular(18),
              onTap: onClose,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.hairline),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                                color: brick,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.close, size: 18, color: t.inkFaint),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(width: 28, height: 2, color: brick),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                      if (sign.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              sign,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: brick,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
