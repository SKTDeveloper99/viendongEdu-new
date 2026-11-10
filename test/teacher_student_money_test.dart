// Owner 2026-11-10 (P-03): one student's money in Sinh viên của tôi →
// student detail; no class-wide money on the phone (M-18). Fictional data.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/features/teacher_students/widgets/money_card.dart';
import 'package:viendongedu2_flutter/models/exam_status_models.dart';
import 'package:viendongedu2_flutter/models/teacher_care_student.dart';

import 'helpers/teacher_care_fixture.dart';

TeacherCareStudent _student(void Function(Map<String, dynamic> d) edit) {
  final json = careStudentJson();
  edit(json['dossier'] as Map<String, dynamic>);
  return TeacherCareStudent.fromJson(json);
}

Future<void> _card(
  WidgetTester t,
  TeacherCareStudent s, {
  bool loading = false,
}) => t.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MoneyCard(student: s, loadingFigures: loading),
      ),
    ),
  ),
);

void main() {
  test('current term: all three figures or none', () {
    final ok = CareTermMoney.fromJson({
      'semester_code': '261',
      'money_known': true,
      'owed': 9000000,
      'paid': 6000000,
      'remaining': 3000000,
    });
    expect(ok.known, isTrue);
    expect(ok.remaining, 3000000);
    for (final bad in [
      {
        'semester_code': '261',
        'money_known': false,
        'owed': 1,
        'paid': 1,
        'remaining': 0,
      },
      {
        'semester_code': '261',
        'money_known': true,
        'owed': 1,
        'paid': null,
        'remaining': 0,
      },
      {
        'semester_code': '261',
        'money_known': true,
        'owed': -1,
        'paid': 0,
        'remaining': 0,
      },
      'rác',
      null,
    ]) {
      expect(CareTermMoney.fromJson(bad).known, isFalse, reason: '$bad');
    }
  });

  test('exam gate: exam_gate, then the gate status, then owes', () {
    expect(
      _student(
        (d) => d['exam_gate'] = {
          'status': 'no',
          'owes_semesters': ['261'],
        },
      ).examOwesSemesters,
      ['261'],
    );
    expect(
      _student(
        (d) => d['money'] = {'status': 'het_no', 'ims_balance': 5},
      ).examStatus,
      ExamMoneyStatus.allowed,
    );
    // Lantern rows (25/26): the server drops `money` for teachers.
    expect(
      _student((d) {
        d.remove('money');
        d['money_one'] = careMoneyJson(owes: true);
      }).examStatus,
      ExamMoneyStatus.owes,
    );
    expect(
      _student((d) {
        d.remove('money');
        d['money_one'] = {'money_known': false};
      }).examStatus,
      ExamMoneyStatus.noData,
    );
  });

  test('list rows keep status, drop every amount (memory and saved copy)', () {
    final full = _student((d) {
      d['money_one'] = careMoneyJson(owes: true);
      d['money_term'] = {
        'semester_code': '261',
        'money_known': true,
        'owed': 9000000,
        'paid': 6000000,
        'remaining': 3000000,
      };
    });
    final row = full.forList();
    expect(row.money.known, isTrue);
    expect(row.money.owes, isTrue);
    expect(row.money.hasFigures, isFalse);
    expect(row.term.known, isFalse);
    final saved = jsonEncode(row.toJson());
    for (final n in ['4000000', '2500000', '1500000', '9000000', '3000000']) {
      expect(saved.contains(n), isFalse, reason: n);
    }
    final back = TeacherCareStudent.fromJson(
      jsonDecode(saved) as Map<String, dynamic>,
    );
    expect(back.money.owes, isTrue);
    expect(back.examStatus, ExamMoneyStatus.owes);
  });

  testWidgets('detail: Dự thi, current term and all terms', (t) async {
    await _card(
      t,
      _student((d) {
        d['money_one'] = careMoneyJson(owes: true);
        d['exam_gate'] = {
          'status': 'no',
          'owes_semesters': ['261'],
        };
        d['money_term'] = {
          'semester_code': '261',
          'money_known': true,
          'owed': 9000000,
          'paid': 6000000,
          'remaining': 3000000,
        };
      }),
    );
    expect(find.text('Còn nợ HK 261'), findsOneWidget);
    expect(find.text('Học kỳ 261 · phải nộp'), findsOneWidget);
    expect(find.text('9.000.000 đ'), findsOneWidget);
    expect(find.text('3.000.000 đ'), findsOneWidget);
    expect(find.text('Tất cả học kỳ · phải nộp'), findsOneWidget);
    expect(find.text('4.000.000 đ'), findsOneWidget);
  });

  testWidgets('no term data yet: Đang đối chiếu, never 0', (t) async {
    await _card(t, _student((d) => d['money_one'] = careMoneyJson()));
    expect(find.text('Học kỳ hiện tại'), findsOneWidget);
    expect(find.text('Đang đối chiếu'), findsOneWidget);
    expect(find.text('0 đ'), findsNothing);
  });

  testWidgets('no data: Chưa có dữ liệu, vẫn được thi', (t) async {
    await _card(
      t,
      _student((d) {
        d.remove('money');
        d['money_one'] = {'money_known': false};
      }),
    );
    expect(find.text('Chưa có dữ liệu'), findsOneWidget);
    expect(find.text('Theo quy định: vẫn được thi'), findsOneWidget);
    expect(find.text('Đang đối chiếu'), findsNWidgets(2));
  });

  testWidgets('list copy while the one-student read runs: Đang tải…', (
    t,
  ) async {
    final row = _student((d) => d['money_one'] = careMoneyJson()).forList();
    await _card(t, row, loading: true);
    expect(find.text('Đang tải…'), findsNWidgets(2));
    expect(find.textContaining(RegExp(r'\d đ')), findsNothing);
  });
}
