import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/draft_merge.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/ems_attendance_cache.dart';

const _a = 'TEST260001';
const _b = 'TEST260002';

EmsRosterStudent _s(String mssv, [String? status, String? note]) =>
    EmsRosterStudent(
      mssv: mssv,
      fullName: 'Học viên $mssv',
      status: status,
      note: note,
    );

EmsAttendanceDraft _d(
  Map<String, String> marks, {
  Map<String, String> notes = const {},
  bool queued = true,
  List<EmsRosterStudent> baseline = const [],
}) => EmsAttendanceDraft(
  marks: marks,
  notes: notes,
  queued: queued,
  students: baseline,
);

class _Case {
  const _Case(
    this.name,
    this.draft,
    this.roster, {
    required this.marks,
    this.notes = const {},
    required this.conflict,
    required this.queued,
  });
  final String name;
  final EmsAttendanceDraft? draft;
  final List<EmsRosterStudent> roster;
  final Map<String, String> marks;
  final Map<String, String> notes;
  final bool conflict;
  final bool queued;
}

void main() {
  final cases = <_Case>[
    _Case(
      'no draft: server marks and notes only',
      null,
      [_s(_a, 'present', 'n'), _s(_b)],
      marks: {_a: 'present'},
      notes: {_a: 'n'},
      conflict: false,
      queued: false,
    ),
    _Case(
      'empty baseline with marks is a conflict',
      _d({_a: 'absent'}),
      [_s(_a, 'present')],
      marks: {_a: 'present'},
      conflict: true,
      queued: false,
    ),
    _Case(
      'empty baseline without marks keeps the queue flag',
      _d({}),
      [_s(_a, 'present')],
      marks: {_a: 'present'},
      conflict: false,
      queued: true,
    ),
    _Case(
      'student missing from roster is a conflict',
      _d({_a: 'present', _b: 'present'}, baseline: [_s(_a), _s(_b)]),
      [_s(_a)],
      marks: {_a: 'present'},
      conflict: true,
      queued: false,
    ),
    _Case(
      'unchanged in draft: server value wins, even if it changed',
      _d({_a: 'present'}, baseline: [_s(_a, 'present')]),
      [_s(_a, 'absent')],
      marks: {_a: 'absent'},
      conflict: false,
      queued: true,
    ),
    _Case(
      'intended applied over an unchanged server row',
      _d({_a: 'absent'}, notes: {_a: 'ốm'}, baseline: [_s(_a, 'present')]),
      [_s(_a, 'present')],
      marks: {_a: 'absent'},
      notes: {_a: 'ốm'},
      conflict: false,
      queued: true,
    ),
    _Case(
      'server already equals intended: no conflict',
      _d({_a: 'absent'}, baseline: [_s(_a)]),
      [_s(_a, 'absent')],
      marks: {_a: 'absent'},
      conflict: false,
      queued: true,
    ),
    _Case(
      'server status changed to something else: conflict',
      _d({_a: 'absent'}, baseline: [_s(_a)]),
      [_s(_a, 'late')],
      marks: {_a: 'late'},
      conflict: true,
      queued: false,
    ),
    _Case(
      'server note changed to something else: conflict',
      _d({_a: 'absent'}, notes: {_a: 'x'}, baseline: [_s(_a)]),
      [_s(_a, null, 'y')],
      marks: {},
      notes: {_a: 'y'},
      conflict: true,
      queued: false,
    ),
    _Case(
      'intended null removes the server mark and note',
      _d({}, baseline: [_s(_a, 'present', 'n'), _s(_b)]),
      [_s(_a, 'present', 'n'), _s(_b)],
      marks: {},
      notes: {},
      conflict: false,
      queued: true,
    ),
    _Case(
      'unqueued draft stays unqueued',
      _d({_a: 'present'}, queued: false, baseline: [_s(_a)]),
      [_s(_a)],
      marks: {_a: 'present'},
      conflict: false,
      queued: false,
    ),
  ];

  for (final c in cases) {
    test(c.name, () {
      final r = mergeDraftWithRoster(c.draft, c.roster);
      expect(r.marks, c.marks, reason: 'marks');
      expect(r.notes, c.notes, reason: 'notes');
      expect(r.needsReview, c.conflict, reason: 'needsReview');
      expect(r.queued, c.queued, reason: 'queued');
      if (c.conflict && c.draft != null) {
        final keep = r.draftToSave!;
        expect(keep.queued, isFalse);
        expect(keep.marks, c.draft!.marks);
        expect(keep.notes, c.draft!.notes);
        expect(keep.students, same(c.draft!.students));
      } else {
        expect(r.draftToSave, isNull);
      }
    });
  }
}
