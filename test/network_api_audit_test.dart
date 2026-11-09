import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/data/api/attendance_api.dart';
import 'package:viendongedu2_flutter/data/api/auth_api.dart';
import 'package:viendongedu2_flutter/data/api/board_api.dart';
import 'package:viendongedu2_flutter/data/api/student_cases_api.dart';
import 'package:viendongedu2_flutter/data/api/teacher_conversations_api.dart';
import 'package:viendongedu2_flutter/data/api/teacher_notifications_api.dart';
import 'package:viendongedu2_flutter/data/api/teacher_students_api.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_money_api.dart';
import 'package:viendongedu2_flutter/services/crm_profile_api.dart';
import 'package:viendongedu2_flutter/services/crm_questions_api.dart';
import 'package:viendongedu2_flutter/services/crm_registration_api.dart';
import 'package:viendongedu2_flutter/services/crm_student_api.dart';
import 'package:viendongedu2_flutter/services/crm_teacher_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late http.Client original;
  late Future<void> Function() originalProbe;
  final session = EmsSession.fromJson({
    'section_id': 'TEST26SECTION',
    'session_key': 'TEST26SESSION',
    'session_date': '2026-10-20',
    'start_time': '07:30',
  });
  final calls = <String, Future<Object?> Function()>{
    'student/me': CrmStudentApi.me,
    'student/grades': CrmStudentApi.grades,
    'student/remaining-subjects': CrmStudentApi.remainingSubjects,
    'student/graduation-summary': CrmStudentApi.graduationSummary,
    'student/sections': CrmStudentApi.sections,
    'student/schedule': CrmStudentApi.schedule,
    'student/scheduleCached': CrmStudentApi.scheduleViewCached,
    'student/exams': CrmStudentApi.exams,
    'teacher/me': CrmTeacherApi.me,
    'teacher/overview': CrmTeacherApi.overview,
    'teacher/overviewCached': CrmTeacherApi.overviewCached,
    'teacher/semesters': CrmTeacherApi.semesters,
    'teacher/schedule': () => CrmTeacherApi.scheduleForDate('2026-10-20'),
    'teacher/schedule/semester': () =>
        CrmTeacherApi.scheduleForSemester('TEST26'),
    'teacher/classes': CrmTeacherApi.classes,
    'teacher/classesCached': CrmTeacherApi.classesCached,
    'teacher/students': () => CrmTeacherApi.classStudents('TEST26SECTION'),
    'teacher/attendance': () =>
        CrmTeacherApi.classAttendanceResult('TEST26SECTION'),
    'teacher/exams': CrmTeacherApi.exams,
    'student-care/list': TeacherStudentsApi.students,
    'student-care/detail': () => TeacherStudentsApi.student('TEST260001'),
    'money/tuition': CrmMoneyApi.getTuition,
    'money/cong-no': CrmMoneyApi.getCongNo,
    'money/fees': CrmMoneyApi.getFees,
    'money/capbu': CrmMoneyApi.getCapBu,
    'profile/student': CrmProfileApi.getStudentMe,
    'profile/teacher': CrmProfileApi.getTeacherMe,
    'profile/updateStudent': CrmProfileApi.updateStudentProfile,
    'profile/updateTeacher': CrmProfileApi.updateTeacherProfile,
    'registration/periods': CrmRegistrationApi.getPeriods,
    'registration/offerings': () =>
        CrmRegistrationApi.getOfferings(periodId: 'TEST26'),
    'registration/results': CrmRegistrationApi.getResults,
    'registration/register': () => CrmRegistrationApi.register('TEST26'),
    'registration/cancel': () => CrmRegistrationApi.cancel('TEST26'),
    'questions/list': CrmQuestionsApi.list,
    'questions/targets': CrmQuestionsApi.targets,
    'questions/detail': () => CrmQuestionsApi.detail('TEST26'),
    'questions/create': () => CrmQuestionsApi.create(
      subject: 'Test',
      message: 'Test',
      targetType: 'school',
    ),
    'questions/send': () => CrmQuestionsApi.sendMessage('TEST26', 'Test'),
    'attendance/sessions': AttendanceApi.mySessions,
    'attendance/roster': () => AttendanceApi.roster(session),
    'attendance/session-marks': () =>
        AttendanceApi.sessionMarks('TEST26SESSION'),
    'attendance/save': () => AttendanceApi.saveMarks(session, []),
    'attendance/student': AttendanceApi.myAttendance,
    'board/list': BoardApi.board,
    'board/cached': BoardApi.boardCached,
    'board/unread': BoardApi.unreadCount,
    'board/registerDevice': () => BoardApi.registerStudentDevice('test-device'),
    'board/revokeDevice': () => BoardApi.revokeStudentDevice('test-device'),
    'board/read': () => BoardApi.markRead('TEST26'),
    'board/acknowledge': () => BoardApi.acknowledge('TEST26'),
    'notifications/list': TeacherNotificationsApi.teacherNotifications,
    'notifications/read': () =>
        TeacherNotificationsApi.markTeacherNotificationRead('TEST26'),
    'notifications/readAll':
        TeacherNotificationsApi.markAllTeacherNotificationsRead,
    'notifications/unread': TeacherNotificationsApi.teacherUnreadCount,
    'notifications/registerDevice': () =>
        TeacherNotificationsApi.registerTeacherDevice('test-device'),
    'notifications/revokeDevice': () =>
        TeacherNotificationsApi.revokeTeacherDevice('test-device'),
    'conversations/list': () => TeacherConversationsApi.listCached('open'),
    'conversations/unread': TeacherConversationsApi.unreadCount,
    'conversations/thread': () => TeacherConversationsApi.thread('TEST26'),
    'conversations/send': () => TeacherConversationsApi.send('TEST26', 'Test'),
    'conversations/resolve': () => TeacherConversationsApi.resolve('TEST26'),
    'conversations/create': () =>
        TeacherConversationsApi.create(mssv: 'TEST260001', message: 'Test'),
    'cases/list': StudentCasesApi.myOpenStudentCases,
    'cases/answer': () => StudentCasesApi.answerStudentCase('TEST26', 'Test'),
    'auth/student': () => AuthApi.studentLogin('TEST260001', 'test-password'),
    'auth/teacher': () => AuthApi.teacherLogin('TEST26T001', 'test-password'),
    'auth/studentPassword': () => AuthApi.changeStudentPassword(
      currentPassword: 'test-current',
      newPassword: 'test-next',
    ),
    'auth/teacherPassword': () => AuthApi.changeTeacherPassword(
      currentPassword: 'test-current',
      newPassword: 'test-next',
    ),
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = EmsApiService.client;
    originalProbe = EmsApiService.probe;
    EmsApiService.probe = () async {};
    EmsApiService.resetConnectionState();
    AppSession.instance
      ..emsToken = 'test-session'
      ..role = CrmRole.teacher
      ..teacherId = 'TEST26T001'
      ..mssv = 'TEST260001';
  });
  tearDown(() {
    EmsApiService.client = original;
    EmsApiService.probe = originalProbe;
    AppSession.instance.emsToken = null;
  });

  for (final call in calls.entries) {
    for (final failure in [
      'offline',
      'timeout',
      '500',
      '401',
      'malformed JSON',
      'wrong JSON shape',
    ]) {
      test('${call.key}: $failure', () async {
        var sent = 0;
        EmsApiService.client = MockClient((_) async {
          sent++;
          switch (failure) {
            case 'offline':
              throw http.ClientException('test-offline');
            case 'timeout':
              throw TimeoutException('test-timeout');
            case '500':
              return http.Response(
                jsonEncode({'error': 'internal_error'}),
                500,
              );
            case '401':
              return http.Response('unauthorized', 401);
            case 'wrong JSON shape':
              return http.Response('"unexpected"', 200);
            default:
              return http.Response('{broken', 200);
          }
        });
        await expectLater(
          call.value(),
          throwsA(
            isA<EmsException>().having(
              (e) => e.message,
              'Vietnamese message',
              matches(RegExp(r'[À-ỹĐđ]')),
            ),
          ),
        );
        expect(sent, 1);
      });
    }
  }
}
