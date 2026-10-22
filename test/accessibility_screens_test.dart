// Every route is exercised at 320×640 with fictional data and intercepted HTTP.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/components/notification_banner.dart';
import 'package:viendongedu2_flutter/data/infinite_repository.dart';
import 'package:viendongedu2_flutter/data/teacher_attendance_repository.dart';
import 'package:viendongedu2_flutter/features/class_manager/class_manager_screen.dart';
import 'package:viendongedu2_flutter/features/classes/class_detail_screen.dart';
import 'package:viendongedu2_flutter/features/classes/class_models.dart';
import 'package:viendongedu2_flutter/features/classes/classes_screen.dart';
import 'package:viendongedu2_flutter/features/grades/grades_screen.dart';
import 'package:viendongedu2_flutter/features/infinite/infinite_screen.dart';
import 'package:viendongedu2_flutter/features/infinite/widgets/map_pin.dart';
import 'package:viendongedu2_flutter/features/infinite/widgets/qr_scan_sheet.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/roster_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/teacher_attendance_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/widgets/absence_check_dialog.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/widgets/reasons_dialog.dart';
import 'package:viendongedu2_flutter/features/teacher_conversations/conversation_inbox_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_conversations/conversation_thread_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_conversations/new_conversation_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_home/teacher_home_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_students/class_students_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_students/student_detail_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_students/teacher_students_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_students/teacher_students_view_model.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/screens/capbu_screen.dart';
import 'package:viendongedu2_flutter/screens/change_password_screen.dart';
import 'package:viendongedu2_flutter/screens/ems_attendance_student_screen.dart';
import 'package:viendongedu2_flutter/screens/exam_screen.dart';
import 'package:viendongedu2_flutter/screens/gv_lichthi_screen.dart';
import 'package:viendongedu2_flutter/screens/gv_lophoc_screen.dart';
import 'package:viendongedu2_flutter/screens/gv_profile_info_screen.dart';
import 'package:viendongedu2_flutter/screens/gv_schedule_screen.dart';
import 'package:viendongedu2_flutter/screens/hv_profile_info_screen.dart';
import 'package:viendongedu2_flutter/screens/lephi_screen.dart';
import 'package:viendongedu2_flutter/screens/login_screen.dart';
import 'package:viendongedu2_flutter/screens/notifications_screen.dart';
import 'package:viendongedu2_flutter/screens/profile_edit_screen.dart';
import 'package:viendongedu2_flutter/screens/registration_screen.dart';
import 'package:viendongedu2_flutter/screens/schedule_screen.dart';
import 'package:viendongedu2_flutter/screens/splash_screen.dart';
import 'package:viendongedu2_flutter/screens/student_board_screen.dart';
import 'package:viendongedu2_flutter/screens/student_questions_screen.dart';
import 'package:viendongedu2_flutter/screens/teacher_my_day_screen.dart';
import 'package:viendongedu2_flutter/screens/tuition_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';
import 'helpers/accessibility_fixture.dart';
import 'helpers/teacher_care_fixture.dart';

class _ModalPreview extends StatelessWidget {
  const _ModalPreview(this.open);
  final void Function(BuildContext) open;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => open(context),
        child: const Text('Mở kiểm thử'),
      ),
    ),
  );
}

class _LocalGame extends InfiniteRepository {
  @override
  Future<Set<String>> unlocked() async => {
    'frame_blue',
    'frame_gold',
    'title_explorer',
  };
  @override
  Future<Map<String, String?>> equipped() async => {
    'frame': 'frame_gold',
    'title': 'title_explorer',
  };

  @override
  Future<Set<String>> cloudClaimed() async => {};
}

// Nested viewports sometimes expose a clipped semantic rectangle as a tiny
// target. Skip only controls whose full widget is not hit-testable at both edges.
class _VisibleTapTargets extends MinimumTapTargetGuideline {
  const _VisibleTapTargets()
    : super(
        size: const Size(48, 48),
        link: 'https://support.google.com/accessibility/android/answer/7101858',
      );
  @override
  bool shouldSkipNode(SemanticsNode node) {
    if (super.shouldSkipNode(node)) return true;
    final finder = find.bySemanticsLabel(node.getSemanticsData().label);
    final top = finder.hitTestable(at: Alignment.topCenter).evaluate().toSet();
    final bottom = finder
        .hitTestable(at: Alignment.bottomCenter)
        .evaluate()
        .toSet();
    return top.intersection(bottom).isEmpty;
  }
}

class _VisibleTextContrast extends MinimumTextContrastGuideline {
  @override
  bool shouldSkipNode(SemanticsData data) {
    if (super.shouldSkipNode(data)) return true;
    final text = data.label.isEmpty ? data.value : data.label;
    final finder = find.text(text);
    final top = finder.hitTestable(at: Alignment.topCenter).evaluate().toSet();
    final bottom = finder
        .hitTestable(at: Alignment.bottomCenter)
        .evaluate()
        .toSet();
    return top.intersection(bottom).isEmpty;
  }

  @override
  double targetContrastRatio(double? fontSize, {required bool bold}) => 4.5;
}

void main() {
  setUpAll(() async {
    final font = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
    }
    await font.load();
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
          (call) async => switch (call.method) {
            'state' => 0,
            'request' => false,
            _ => null,
          },
        );
    for (final channel in ['event', 'deviceOrientation']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('dev.steenbakker.mobile_scanner/scanner/$channel'),
            (_) async => null,
          );
    }
    SharedPreferences.setMockInitialValues({});
    EmsApiService.client = MockClient(
      (_) async => http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    AppSession.instance
      ..emsToken = 'fictional-test-token'
      ..role = CrmRole.teacher
      ..teacherId = 'TEST26GV'
      ..teacherCode = 'TEST26GV'
      ..mssv = 'TEST260001'
      ..fullName = 'THUNGHIEM';
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..teacherId = null
      ..teacherCode = null
      ..mssv = null
      ..fullName = null;
  });
  final screens = <String, Widget Function()>{
    'NotificationBanner': () => Scaffold(
      body: Stack(
        children: [
          NotificationBanner(
            title: 'Thông báo thử nghiệm',
            body: 'Nội dung thử nghiệm',
            onTap: () {},
            onDismiss: () {},
          ),
        ],
      ),
    ),
    'QrScanner': () => _ModalPreview((context) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const QrScanSheet(hint: 'Mã thử nghiệm'),
      );
    }),
    'AttendanceReasons': () => _ModalPreview((context) {
      showReasonsDialog(
        context,
        people: const [EmsPunchedStudent(mssv: 'TEST260001')],
        initial: {},
        nameOf: (_) => 'Sinh viên thử nghiệm',
      );
    }),
    'AttendanceConfirmation': () => _ModalPreview((context) {
      showAbsenceCheckDialog(context, absent: 2, other: 1);
    }),
    'GvLopHocScreen': () => const GvLopHocScreen(),
    'ScheduleScreen': () => const ScheduleScreen(),
    'TuitionScreen': () => const TuitionScreen(),
    'ProfileEditScreen': () => const ProfileEditScreen(),
    'HvProfileInfoScreen': () => const HvProfileInfoScreen(),
    'NotificationsScreen': () => const NotificationsScreen(),
    'GvScheduleScreen': () => const GvScheduleScreen(),
    'TeacherMyDayScreen': () => const TeacherMyDayScreen(),
    'RegistrationScreen': () => const RegistrationScreen(),
    'EmsAttendanceStudentScreen': () => const EmsAttendanceStudentScreen(),
    'GvLichThiScreen': () => const GvLichThiScreen(),
    'ChangePasswordScreen': () => const ChangePasswordScreen(),
    'LoginScreen': () => const LoginScreen(),
    'StudentBoardScreen': () => const StudentBoardScreen(),
    'StudentQuestionsScreen': () => const StudentQuestionsScreen(),
    'ExamScreen': () => const ExamScreen(),
    'CapBuScreen': () => const CapBuScreen(),
    'LePhiScreen': () => const LePhiScreen(),
    'ClassesScreen': () => const ClassesScreen(),
    'GradesScreen': () => const GradesScreen(),
    'GvQuanLyLopScreen': () => const GvQuanLyLopScreen(),
    'GvHomeScreen': () => const GvHomeScreen(),
    'HomeScreen': () => const HomeScreen(),
    'TeacherStudentsScreen': () => const TeacherStudentsScreen(),
    'EmsAttendanceTeacherScreen': () => const EmsAttendanceTeacherScreen(),
    'TeacherConversationsScreen': () => const TeacherConversationsScreen(),
    'NewConversationScreen': () => const NewConversationScreen(),
    'GvProfileInfoScreen': () => const GvProfileInfoScreen(
      profile: null,
      fallbackName: 'THUNGHIEM',
      teacherCode: 'TEST26GV',
    ),
  };
  screens.addAll({
    'InfiniteScreen': () => InfiniteScreen(repository: _LocalGame()),
    'ClassDetailScreen': () => const ClassDetailScreen(
      item: ClassItem(
        sectionId: 1,
        lmhma: 'TEST26',
        mhma: 'TEST26',
        mhten: 'Môn thử nghiệm',
        sotinchi: 3,
        gvten: 'THUNGHIEM',
        tongdiem: 7,
        diemgk: 7,
        diemck: 7,
      ),
      semTen: 'Học kỳ thử nghiệm',
    ),
    'TeacherRosterScreen': () => const TeacherRosterScreen(
      repository: TeacherAttendanceRepository(),
      session: EmsSession(
        sectionId: 'TEST26',
        sectionCode: 'TEST26',
        sessionDate: '2026-10-22',
        sessionKey: 'TEST26',
        subjectName: 'Môn thử nghiệm',
      ),
    ),
    'ClassStudentsScreen': () => ClassStudentsScreen(
      careClass: CareClass(
        sectionId: careSectionId,
        title: 'Lớp thử nghiệm',
        students: [careStudent()],
      ),
    ),
    'StudentDetailScreen': () => StudentDetailScreen(
      student: careStudent(),
      sectionId: careSectionId,
      backLabel: 'Lớp thử nghiệm',
    ),
    'ConversationThreadScreen': () =>
        const ConversationThreadScreen(conversationId: 'TEST26'),
    'ForcedPassword': () => const ChangePasswordScreen(forced: true),
  });
  final steps = <String, List<String>>{
    'QrScanner': ['Mở kiểm thử'],
    'AttendanceReasons': ['Mở kiểm thử'],
    'AttendanceConfirmation': ['Mở kiểm thử'],
    'NewConversationScreen/keyboard': ['Sinh viên thử nghiệm'],
    'GvHomeScreen/profile': ['Cá nhân'],
    'HomeScreen/profile': ['Cá nhân'],
    'GvHomeScreen/theme': ['Cá nhân', 'Giao diện'],
    'HomeScreen/theme': ['Cá nhân', 'Giao diện'],
    'HomeScreen/qr': ['@Mã QR cá nhân'],
    'GradesScreen/detail': ['Chi tiết'],
    'GradesScreen/unscored': ['Môn học'],
    'GradesScreen/remaining': ['Môn học', 'Chưa học'],
    'GvQuanLyLopScreen/detail': ['TN261A'],
    'GvQuanLyLopScreen/students': ['TN261A', 'Danh sách'],
    'GvQuanLyLopScreen/attendance': ['TN261A', 'Điểm danh'],
    'StudentBoardScreen/detail': ['Thông báo thử nghiệm A'],
    'StudentQuestionsScreen/new': ['Đặt câu hỏi'],
    'StudentQuestionsScreen/thread': ['Câu hỏi thử nghiệm'],
    'NotificationsScreen/detail': ['Thông báo thử nghiệm'],
    'CapBuScreen/detail': ['Cấp bù thử nghiệm'],
    'InfiniteScreen/quiz': ['@Vườn cây: Câu đố vườn cây'],
    'TeacherRosterScreen/student': ['An Thử Nghiệm'],
    'TeacherRosterScreen/unmark': ['!Bỏ điểm danh'],
    'GvQuanLyLopScreen/summary': ['TN261A', 'Điểm danh', 'Tổng hợp'],
    'GvLichThiScreen/detail': ['Môn thử nghiệm'],
    'TeacherMyDayScreen/answer': ['Phản hồi ca sinh viên'],
    'NewConversationScreen/compose': ['Sinh viên thử nghiệm'],
    'ScheduleScreen/datepicker': [
      '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
    ],
    'GvScheduleScreen/datepicker': [
      '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
    ],
  };
  for (final key in steps.keys) {
    screens[key] = screens[key.split('/').first]!;
  }
  screens['SplashScreen'] = () =>
      SplashScreen(checkUpdate: (_) => Completer<bool>().future);
  for (final populated in [false, true]) {
    for (final dark in [false, true]) {
      for (final scale in [1.3, 2.0]) {
        for (final screen in screens.entries) {
          if (!populated && screen.key.contains('/')) continue;
          testWidgets(
            '${screen.key} populated=$populated dark=$dark scale=$scale at 320px',
            (tester) async {
              if (populated) {
                EmsApiService.client = MockClient(
                  (req) async => accessibilityResponse(req),
                );
              }
              final teacher =
                  screen.key.startsWith('Gv') ||
                  screen.key.startsWith('Teacher') ||
                  [
                    'NotificationsScreen',
                    'NewConversationScreen',
                    'ConversationThreadScreen',
                    'ClassStudentsScreen',
                    'StudentDetailScreen',
                  ].contains(screen.key);
              AppSession.instance.role = teacher
                  ? CrmRole.teacher
                  : CrmRole.student;
              tester.view.physicalSize = const Size(320, 640);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              final semantics = tester.ensureSemantics();
              final previous = FlutterError.onError!;
              try {
                final errors = <FlutterErrorDetails>[];
                FlutterError.onError = (details) {
                  errors.add(details);
                  previous(details);
                };
                await tester.pumpWidget(
                  MaterialApp(
                    localizationsDelegates: const [
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    supportedLocales: const [Locale('vi', 'VN')],
                    locale: const Locale('vi', 'VN'),
                    theme: dark ? VdTheme.dark() : VdTheme.light(),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        viewInsets: screen.key.endsWith('/keyboard')
                            ? const EdgeInsets.only(bottom: 300)
                            : EdgeInsets.zero,
                      ),
                      child: child!,
                    ),
                    routes: {
                      '/student_board': (_) => const StudentBoardScreen(),
                    },
                    home: screen.value(),
                  ),
                );
                await tester.pump();
                await tester.pump(const Duration(seconds: 4));
                await tester.pump(const Duration(seconds: 4));
                for (final step in steps[screen.key] ?? <String>[]) {
                  final target = step.startsWith('!')
                      ? find.byTooltip(step.substring(1))
                      : step.startsWith('@')
                      ? find.bySemanticsLabel(step.substring(1))
                      : find.text(step);
                  for (
                    var attempt = 0;
                    target.evaluate().isEmpty && attempt < 20;
                    attempt++
                  ) {
                    await tester.drag(
                      find.byType(Scrollable).first,
                      const Offset(0, -240),
                    );
                    await tester.pump(const Duration(milliseconds: 300));
                  }
                  expect(
                    target,
                    findsWidgets,
                    reason: 'Open ${screen.key}: $step',
                  );
                  await tester.ensureVisible(target.first);
                  await tester.pump();
                  await tester.tap(target.first);
                  await tester.pump();
                  await tester.pump(const Duration(seconds: 4));
                  await tester.pump(const Duration(seconds: 4));
                }
                if (screen.key == 'QrScanner') {
                  expect(
                    find.text(
                      'Không mở được camera. Nhập dòng chữ dưới mã QR.',
                    ),
                    findsOneWidget,
                  );
                }
                if (populated && screen.key == 'TeacherRosterScreen') {
                  expect(find.text('Lưu điểm danh'), findsOneWidget);
                }
                expect(
                  tester.takeException(),
                  isNull,
                  reason: errors.map((e) => e.toString()).join('\n'),
                );
                // The pannable map intentionally clips edge pins. Their full hit-box
                // dimensions are checked independently below; ordinary routes use the SDK guideline.
                if (!screen.key.startsWith('InfiniteScreen')) {
                  await expectLater(
                    tester,
                    meetsGuideline(androidTapTargetGuideline),
                  );
                } else {
                  for (final pin in find.byType(MapPin).evaluate()) {
                    expect(
                      (pin.renderObject as RenderBox).size.width,
                      greaterThanOrEqualTo(48),
                    );
                    expect(
                      (pin.renderObject as RenderBox).size.height,
                      greaterThanOrEqualTo(48),
                    );
                  }
                }
                await expectLater(
                  tester,
                  meetsGuideline(labeledTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(textContrastGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(_VisibleTextContrast()),
                );
                // Visit content below the fold as well as the initial viewport.
                final scrollables = find.byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                );
                for (final element in scrollables.evaluate().toList()) {
                  final state =
                      (element as StatefulElement).state as ScrollableState;
                  if (!state.mounted || !state.position.hasContentDimensions) {
                    continue;
                  }
                  final max = state.position.maxScrollExtent;
                  for (var offset = 500.0; offset < max + 500; offset += 500) {
                    state.position.jumpTo(offset.clamp(0, max));
                    await tester.pump();
                    expect(
                      tester.takeException(),
                      isNull,
                      reason: errors.map((e) => e.toString()).join('\n'),
                    );
                    // The SDK skips clipped targets at scroll boundaries.
                    await expectLater(
                      tester,
                      meetsGuideline(const _VisibleTapTargets()),
                    );
                    // Screenshot contrast sampling needs fully visible paragraphs.
                    await expectLater(
                      tester,
                      meetsGuideline(labeledTapTargetGuideline),
                    );
                    await expectLater(
                      tester,
                      meetsGuideline(_VisibleTextContrast()),
                    );
                  }
                }
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pump(const Duration(seconds: 5));
              } finally {
                FlutterError.onError = previous;
                semantics.dispose();
              }
            },
          );
        }
      }
    }
  }
}
