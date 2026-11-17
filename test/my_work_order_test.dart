import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/features/work/work_api.dart';

Map<String, dynamic> _a(
  String id,
  String status,
  String at, {
  bool ack = false,
}) => {
  'assignment_id': id,
  'status': status,
  'assigned_at': at,
  'acknowledged_at': ack ? at : null,
};

void main() {
  test('the switch is on by default', () {
    expect(myWorkUnopenedFirst, isTrue);
  });

  test(
    'unopened pieces come first, newest first; the rest keep their order',
    () {
      final rows = [
        _a('due-soon', 'in_progress', '2026-11-01T01:00:00Z'),
        _a('old-unopened', 'assigned', '2026-11-02T01:00:00Z'),
        _a('opened', 'assigned', '2026-11-16T01:00:00Z', ack: true),
        _a('handed-in', 'submitted', '2026-11-03T01:00:00Z'),
        _a('new-unopened', 'assigned', '2026-11-17T06:00:00Z'),
      ];
      expect(unopenedFirst(rows).map((a) => a['assignment_id']), [
        'new-unopened',
        'old-unopened',
        'due-soon',
        'opened',
        'handed-in',
      ]);
    },
  );

  test('nothing unopened: the order is unchanged', () {
    final rows = [
      _a('b', 'submitted', '2026-11-02T01:00:00Z'),
      _a('a', 'in_progress', '2026-11-01T01:00:00Z'),
    ];
    expect(unopenedFirst(rows), rows);
  });
}
