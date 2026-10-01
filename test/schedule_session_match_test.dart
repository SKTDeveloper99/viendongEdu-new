import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/schedule_session_match.dart';
import 'package:viendongedu2_flutter/models/ems_attendance_models.dart';

void main() {
  final monday = [
    EmsSession(
      sectionId: '7b4a3d9e-uuid-a',
      sectionCode: 'MON-A',
      sessionDate: '2026-10-05',
      startTime: '09:00',
      endTime: '10:00',
      sessionKey: '101:09-00:2026-10-05',
      rosterSize: 2,
    ),
    EmsSession(
      sectionId: '7b4a3d9e-uuid-b',
      sectionCode: 'MON-B',
      sessionDate: '2026-10-05',
      startTime: '09:00',
      endTime: '10:00',
      sessionKey: '202:09-00:2026-10-05',
      rosterSize: 20,
    ),
    EmsSession(
      sectionId: '7b4a3d9e-uuid-c',
      sectionCode: 'MON-C',
      sessionDate: '2026-10-05',
      startTime: '09:00',
      endTime: '10:00',
      sessionKey: '303:09-00:2026-10-05',
      rosterSize: 31,
    ),
  ];

  test('same-time Monday cards resolve to their exact EMS rosters', () {
    for (final expected in monday) {
      final actual = matchScheduleSession(
        sessions: monday,
        // Schedule rows also carry numeric lmhid values (44660 etc). The
        // shared lmhma/section_code is the identity that crosses into EMS.
        sectionCode: expected.sectionCode,
        date: '2026-10-05',
        startTime: '09:00',
        endTime: '10:00',
      );
      expect(actual?.sessionKey, expected.sessionKey);
      expect(actual?.rosterSize, expected.rosterSize);
    }
  });

  test('unmatched date and ambiguous EMS rows fail closed', () {
    expect(
      matchScheduleSession(
        sessions: monday,
        sectionCode: 'MON-A',
        date: '2026-10-12',
        startTime: '09:00',
        endTime: '10:00',
      ),
      isNull,
    );
    expect(
      matchScheduleSession(
        sessions: [...monday, monday.first],
        sectionCode: 'MON-A',
        date: '2026-10-05',
        startTime: '09:00',
        endTime: '10:00',
      ),
      isNull,
    );
  });

  test('unmaterialized EMS row fails closed', () {
    const unmaterialized = EmsSession(
      sectionId: '',
      sectionCode: 'MON-A',
      sessionDate: '2026-10-05',
      startTime: '09:00',
      endTime: '10:00',
      sessionKey: '',
    );
    expect(
      matchScheduleSession(
        sessions: const [unmaterialized],
        sectionCode: 'MON-A',
        date: '2026-10-05',
        startTime: '09:00',
        endTime: '10:00',
      ),
      isNull,
    );
  });

  test('timestamp-shaped CRM times still match exact EMS times', () {
    expect(
      matchScheduleSession(
        sessions: monday,
        sectionCode: 'MON-A',
        date: '2026-10-05',
        startTime: '2026-10-05T09:00:00+07:00',
        endTime: '2026-10-05T10:00:00+07:00',
      )?.rosterSize,
      2,
    );
  });

  test('zoned timestamps compare as Vietnam wall time', () {
    expect(normalizeSchoolTime('2026-10-05T02:00:00Z'), '09:00');
    expect(normalizeSchoolTime('2026-10-05T09:00:00+07:00'), '09:00');
    expect(normalizeSchoolTime('2026-10-05T05:00:00-04:00'), '16:00');
    expect(normalizeSchoolTime('2026-10-05T25:00:00'), isEmpty);
    expect(normalizeSchoolTime('not a time'), isEmpty);
  });

  test('invalid session dates cannot match by textual prefix', () {
    expect(
      matchScheduleSession(
        sessions: [
          EmsSession(
            sectionId: 'section-a',
            sectionCode: 'MON-A',
            sessionDate: '2026-10-05Tnonsense',
            startTime: '09:00',
            endTime: '10:00',
            sessionKey: 'broken',
          ),
        ],
        sectionCode: 'MON-A',
        date: '2026-10-05',
        startTime: '09:00',
        endTime: '10:00',
      ),
      isNull,
    );
  });
}
