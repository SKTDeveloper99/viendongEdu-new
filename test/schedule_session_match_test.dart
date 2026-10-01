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
}
