import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/features/work/work_api.dart';

void main() {
  final now = DateTime.utc(2026, 11, 19, 8);
  Map<String, dynamic> a(String status, {String? due, int returned = 0}) => {
    'status': status,
    'due_at': due,
    'returned_count': returned,
  };

  test('sections follow the web: open, wait, done, Không hoàn thành', () {
    expect(
      workSection(a('assigned', due: '2026-11-20T10:00:00Z'), now: now),
      'open',
    );
    // Overdue within the 7-day grace: still handed in.
    expect(
      workSection(a('in_progress', due: '2026-11-14T10:00:00Z'), now: now),
      'open',
    );
    // More than 7 days past the deadline: locked.
    expect(
      workSection(a('assigned', due: '2026-09-19T10:00:00Z'), now: now),
      'closed',
    );
    expect(workSection(a('in_progress', returned: 3), now: now), 'closed');
    expect(
      workSection(a('submitted', due: '2026-11-20T10:00:00Z'), now: now),
      'wait',
    );
    expect(workSection(a('done'), now: now), 'done');
    expect(workSection(a('cancelled'), now: now), 'closed');
    expect(
      workSection({
        'status': 'assigned',
        'work_process_decision': 'denied',
      }, now: now),
      'closed',
    );
  });

  test('the piece deadline is used when the part has none', () {
    expect(
      workLockReason(
        {'status': 'assigned'},
        now: now,
        dueAt: '2026-10-01T00:00:00Z',
      ),
      contains('quá hạn hơn 7 ngày'),
    );
    expect(workLockReason({'status': 'assigned'}, now: now), isNull);
  });

  test('còn N việc counts only what can still be handed in', () {
    final rows = [
      a('assigned', due: '2026-11-20T10:00:00Z'),
      a('assigned', due: '2026-09-01T10:00:00Z'),
      a('in_progress', due: '2026-08-01T10:00:00Z'),
      a('submitted'),
      a('in_progress'),
    ];
    expect(stillOpen(rows, now: now).length, 2);
  });

  test('Tiếp theo: the nearest deadline ahead, never the oldest overdue', () {
    final rows = [
      {
        'task_id': 'two-months',
        'status': 'assigned',
        'due_at': '2026-09-19T10:00:00Z',
      },
      {
        'task_id': 'tomorrow',
        'status': 'assigned',
        'due_at': '2026-11-20T15:30:00Z',
      },
      {
        'task_id': 'tonight',
        'status': 'in_progress',
        'due_at': '2026-11-19T15:30:00Z',
      },
      {
        'task_id': 'late-3d',
        'status': 'assigned',
        'due_at': '2026-11-16T14:00:00Z',
      },
      {
        'task_id': 'late-1d',
        'status': 'assigned',
        'due_at': '2026-11-18T14:00:00Z',
      },
      {'task_id': 'no-date', 'status': 'assigned'},
      {
        'task_id': 'handed',
        'status': 'submitted',
        'due_at': '2026-11-19T09:00:00Z',
      },
    ];
    expect(nextDue(rows, now: now).map((a) => a['task_id']), [
      'tonight',
      'tomorrow',
      'late-1d',
      'late-3d',
      'no-date',
    ]);
  });
}
