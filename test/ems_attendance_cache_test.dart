import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/ems_attendance_cache.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('queued teacher draft survives and can be cleared', () async {
    const key = 'LMH:07-30:2026-09-08';
    await EmsAttendanceCache.saveDraft(
      key,
      {'2600000001': 'present', '2600000002': 'absent'},
      {'2600000002': 'review later'},
      queued: true,
    );

    final draft = await EmsAttendanceCache.loadDraft(key);
    expect(draft?.queued, isTrue);
    expect(draft?.marks['2600000001'], 'present');
    expect(draft?.notes['2600000002'], 'review later');

    await EmsAttendanceCache.clearDraft(key);
    expect(await EmsAttendanceCache.loadDraft(key), isNull);
  });

  test('student keeps the last timeline for offline reading', () async {
    const marks = [
      EmsStudentMark(
        sessionDate: '2026-09-08',
        status: 'present',
        subjectName: 'Test subject',
      ),
    ];
    await EmsAttendanceCache.saveStudentHistory(marks);
    final restored = await EmsAttendanceCache.loadStudentHistory();
    expect(restored.single.status, 'present');
    expect(restored.single.subjectName, 'Test subject');
  });

  test(
    'teacher keeps the session list needed to start class offline',
    () async {
      const sessions = [
        EmsSession(
          sectionId: '11111111-1111-1111-1111-111111111111',
          sectionCode: 'LOP-THU',
          sessionDate: '2026-09-09',
          sessionKey: '123:07-30:2026-09-09',
          subjectName: 'Môn thử nghiệm',
          startTime: '07:30',
          endTime: '10:45',
          rosterSize: 67,
          reportState: 'submitted',
        ),
      ];
      await EmsAttendanceCache.saveTeacherSessions('2026-09-09', sessions);
      final restored = await EmsAttendanceCache.loadTeacherSessions(
        '2026-09-09',
      );
      expect(restored.single.sessionKey, '123:07-30:2026-09-09');
      expect(restored.single.rosterSize, 67);
      expect(restored.single.reportState, 'submitted');
    },
  );
}
