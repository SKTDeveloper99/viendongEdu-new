import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/data/teacher_attendance_repository.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/schedule_card.dart';
import 'package:viendongedu2_flutter/models/ems_attendance_models.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_attendance_cache.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

class _Repo extends TeacherAttendanceRepository {
  _Repo(this.sessions, this.rosters);

  final List<EmsSession> sessions;
  final Map<String, EmsRoster> rosters;
  String? requestedDate;
  EmsSession? requestedRoster;
  int saveCalls = 0;

  @override
  Future<List<EmsSession>> mySessions({String? date}) async {
    requestedDate = date;
    return sessions;
  }

  @override
  Future<EmsRoster> roster(EmsSession session) async {
    requestedRoster = session;
    return rosters[session.sessionKey]!;
  }

  @override
  Future<EmsAttendanceDraft?> loadDraft(String draftKey) async => null;

  @override
  Future<void> saveDraft(
    String draftKey,
    Map<String, String> marks,
    Map<String, String> notes, {
    required bool queued,
    List<EmsRosterStudent> students = const [],
    EmsSession? session,
  }) async {}

  @override
  Future<EmsSaveResult> saveMarks(
    EmsSession session,
    List<EmsMark> marks, {
    List<String> remove = const [],
  }) async {
    saveCalls++;
    return const EmsSaveResult();
  }
}

void main() {
  const monday = [
    EmsSession(
      sectionId: 'section-a',
      sectionCode: 'MON-A',
      sessionDate: '2026-10-05',
      startTime: '09:00',
      endTime: '10:00',
      sessionKey: '101:09-00:2026-10-05',
      rosterSize: 2,
    ),
    EmsSession(
      sectionId: 'section-b',
      sectionCode: 'MON-B',
      sessionDate: '2026-10-05',
      startTime: '09:00',
      endTime: '10:00',
      sessionKey: '202:09-00:2026-10-05',
      rosterSize: 20,
    ),
    EmsSession(
      sectionId: 'section-c',
      sectionCode: 'MON-C',
      sessionDate: '2026-10-05',
      startTime: '09:00',
      endTime: '10:00',
      sessionKey: '303:09-00:2026-10-05',
      rosterSize: 31,
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.emsToken = 'test-token';
  });

  tearDown(() => AppSession.instance.emsToken = null);

  testWidgets(
    'selected same-time class opens only its real roster and renders names',
    (tester) async {
      final repo = _Repo(monday, {
        monday.first.sessionKey: const EmsRoster(
          sessionKey: '101:09-00:2026-10-05',
          students: [
            EmsRosterStudent(mssv: '2600000001', fullName: 'Nguyễn An'),
            EmsRosterStudent(mssv: '2600000002', fullName: 'Trần Bình'),
          ],
        ),
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: VdTheme.light(),
          home: Scaffold(
            body: ScheduleCard(
              repository: repo,
              date: '2026-10-05',
              data: const {
                'lmhma': 'MON-A',
                'mhten': 'Lớp Linh',
                'thoigianbd': '2026-10-05T09:00:00+07:00',
                'thoigiankt': '2026-10-05T10:00:00+07:00',
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Lớp Linh'));
      await tester.pump();
      await tester.tap(find.text('Điểm danh bằng danh sách'));
      await tester.pumpAndSettle();

      expect(repo.requestedDate, '2026-10-05');
      expect(repo.requestedRoster?.sectionCode, 'MON-A');
      expect(repo.requestedRoster?.rosterSize, 2);
      expect(find.text('Nguyễn An'), findsOneWidget);
      expect(find.text('Trần Bình'), findsOneWidget);
      expect(repo.saveCalls, 0);
    },
  );
}
