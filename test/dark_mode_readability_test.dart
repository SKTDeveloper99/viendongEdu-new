// Dark-mode readability: no hard-coded black text on dark cards, and the
// attendance QR stays dark-on-light in both themes. Fixtures fictional.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:viendongedu2_flutter/components/student_exam_card.dart';
import 'package:viendongedu2_flutter/components/student_schedule_card.dart';
import 'package:viendongedu2_flutter/data/student_home_repository.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_view_model.dart';
import 'package:viendongedu2_flutter/features/student_home/widgets/qr_tab.dart';
import 'package:viendongedu2_flutter/models/crm_student_exams.dart';
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';
import 'package:viendongedu2_flutter/screens/exam_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';
import 'package:viendongedu2_flutter/theme/vd_tokens.dart';

const _black = Color(0xFF000000);

Widget _dark(Widget child) => MaterialApp(
  theme: VdTheme.dark(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Color? _colorOf(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style?.color;

void main() {
  testWidgets('exam card text uses the theme ink in dark mode', (t) async {
    final exam = CrmStudentExam.fromJson({
      'exam_id': 'E1',
      'subject_name': 'Môn thử nghiệm',
      'exam_date': '2026-11-14',
      'start_time': '07:30',
      'duration_minutes': 90,
      'room': 'P.101',
      'exam_type': 'Cuối kỳ',
      'semester_code': '261',
    });
    await t.pumpWidget(_dark(StudentExamCard(exam: ExamItem(exam))));
    for (final text in ['14/11/2026', '07:30', '90 phút', 'P.101']) {
      expect(_colorOf(t, text), VdTokens.dark.ink, reason: text);
    }
  });

  testWidgets('schedule card time, teacher, room use the theme ink', (t) async {
    await t.pumpWidget(
      _dark(
        const StudentScheduleCard(
          data: CrmScheduleItem(
            subjectName: 'Môn thử nghiệm',
            startTime: '07:30',
            endTime: '09:30',
            teacherName: 'GV Thử Nghiệm',
            room: 'P.101',
          ),
          status: 'awaiting',
        ),
      ),
    );
    for (final text in ['GV Thử Nghiệm', 'P.101']) {
      expect(_colorOf(t, text), VdTokens.dark.ink, reason: text);
    }
    expect(find.text('Chờ điểm danh'), findsOneWidget);
  });

  testWidgets('QR is black on a white tile in dark mode', (t) async {
    AppSession.instance.mssv = '2600000001';
    addTearDown(() => AppSession.instance.mssv = null);
    final vm = StudentHomeViewModel(
      const StudentHomeRepository(),
      tickEvery: null,
    );
    addTearDown(vm.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: VdTheme.dark(),
        home: Scaffold(body: QrTab(vm: vm)),
      ),
    );
    final qr = t.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.backgroundColor, const Color(0xFFFFFFFF));
    expect(qr.dataModuleStyle.color, _black);
    expect(qr.eyeStyle.color, _black);
  });

  group('Lịch thi states in dark mode', () {
    tearDown(() => EmsApiService.client = http.Client());

    testWidgets('empty: readable text, not black', (t) async {
      AppSession.instance.emsToken = 'test-token';
      EmsApiService.client = MockClient(
        (_) async => http.Response(
          jsonEncode({'exams': []}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await t.pumpWidget(
        MaterialApp(theme: VdTheme.dark(), home: const ExamScreen()),
      );
      await t.pumpAndSettle();
      expect(_colorOf(t, 'Không có lịch thi'), VdTokens.dark.ink);
    });

    testWidgets('error: Vietnamese message, readable', (t) async {
      AppSession.instance.emsToken = 'test-token';
      EmsApiService.client = MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'Máy chủ đang bảo trì, vui lòng thử lại sau.'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      );
      await t.pumpWidget(
        MaterialApp(theme: VdTheme.dark(), home: const ExamScreen()),
      );
      await t.pumpAndSettle();
      final msg = find.textContaining('Máy chủ');
      expect(msg, findsOneWidget);
      expect(t.widget<Text>(msg).style?.color, VdTokens.dark.ink);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
