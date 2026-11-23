// Buổi học (server LAW A-29): báo nghỉ, học bù, dạy thay and changed
// meetings on the teacher and student cards. Fictional data.
//
//   flutter test test/buoi_hoc_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/student_schedule_card.dart';
import 'package:viendongedu2_flutter/core/schedule/buoi.dart';
import 'package:viendongedu2_flutter/features/teacher_home/next_up.dart';
import 'package:viendongedu2_flutter/features/teacher_home/widgets/gv_class_chip.dart';
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';
import 'package:viendongedu2_flutter/models/crm_teacher_class.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

Widget _wrap(Widget w) => MaterialApp(theme: VdTheme.light(), home: Scaffold(body: w));

void main() {
  group('teacher rows', () {
    test('structured fields win; the title is the plain subject', () {
      final b = teacherBuoiOf({
        'mhten': 'Báo nghỉ · Động cơ', 'mhten_goc': 'Động cơ',
        'baonghiyn': true, 'buoi_status': 'bao_nghi', 'buoi_note': 'Nghỉ lễ',
      });
      expect(b.kind, BuoiKind.cancelled);
      expect(b.title, 'Động cơ');
      expect(b.note, 'Nghỉ lễ');
      expect(teacherBuoiOf({'mhten': 'X', 'buoi_status': 'hoc_bu'}).kind, BuoiKind.makeup);
      expect(teacherBuoiOf({'mhten': 'X', 'buoi_status': 'day_thay'}).kind, BuoiKind.standIn);
    });

    test('older servers: read from baonghiyn and the worded subject', () {
      expect(teacherBuoiOf({'mhten': 'Báo nghỉ · A', 'baonghiyn': true}).title, 'A');
      final mk = teacherBuoiOf({'mhten': 'Học bù · B'});
      expect((mk.kind, mk.title), (BuoiKind.makeup, 'B'));
      final cov = teacherBuoiOf({'mhten': 'Dạy thay: Th.S Lan · C'});
      expect((cov.kind, cov.title, cov.note), (BuoiKind.coveredBy, 'C', 'Th.S Lan'));
      expect(teacherBuoiOf({'mhten': 'Dạy thay · D'}).kind, BuoiKind.standIn);
      final plain = teacherBuoiOf({'mhten': 'Trang bị điện · ô tô'});
      expect((plain.kind, plain.title), (BuoiKind.normal, 'Trang bị điện · ô tô'));
    });

    test('the model keeps the new fields through toJson', () {
      final j = CrmScheduleSlot.fromJson({
        'lmhid': '1', 'lmhma': 'L1', 'mhten': 'Học bù · X', 'mhten_goc': 'X', 'buoi_status': 'hoc_bu', 'buoi_note': null,
      }).toJson();
      expect(j['mhten_goc'], 'X');
      expect(j['buoi_status'], 'hoc_bu');
    });

    test('a báo nghỉ meeting is never "Tiếp theo"', () {
      final now = DateTime(2026, 11, 24, 7, 0);
      final up = nextUp([
        {'mhten': 'Báo nghỉ · A', 'baonghiyn': true, 'thoigianbd': '07:30', 'thoigiankt': '10:45'},
        {'mhten': 'B', 'thoigianbd': '13:00', 'thoigiankt': '16:15'},
      ], now);
      expect(up.entry?.subject, 'B');
    });

    testWidgets('teacher card: grey, "Báo nghỉ", the reason and the plain title', (tester) async {
      await tester.pumpWidget(_wrap(const GvClassChip(data: {
        'mhten': 'Báo nghỉ · Thương mại điện tử', 'mhten_goc': 'Thương mại điện tử', 'lmhma': 'GEP37_261',
        'baonghiyn': true, 'buoi_status': 'bao_nghi', 'buoi_note': 'Ngày văn hóa Việt Nam',
        'thoigianbd': '13:00', 'thoigiankt': '2026-11-24T16:15:00', 'phongten': 'Curie 12',
      })));
      expect(find.text('Thương mại điện tử'), findsOneWidget);
      expect(find.text('Báo nghỉ'), findsOneWidget);
      expect(find.text('Lý do: Ngày văn hóa Việt Nam'), findsOneWidget);
      final time = tester.widget<Text>(find.text('13:00 – 16:15'));
      expect(time.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('teacher card: học bù and dạy thay badges', (tester) async {
      await tester.pumpWidget(_wrap(const Column(children: [
        GvClassChip(data: {'mhten': 'Học bù · A', 'buoi_status': 'hoc_bu', 'thoigianbd': '07:30'}),
        GvClassChip(data: {'mhten': 'Dạy thay: Cô Lan · B', 'buoi_status': 'co_nguoi_day_thay', 'buoi_note': 'Cô Lan', 'thoigianbd': '13:00'}),
      ])));
      expect(find.text('Học bù'), findsOneWidget);
      expect(find.text('GV khác dạy'), findsOneWidget);
      expect(find.text('Dạy thay: Cô Lan'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('student day', () {
    final view = CrmStudentScheduleView.fromJson({
      'schedule': [
        {'section_code': 'S-A', 'subject_name': 'Động cơ đốt trong', 'day_code': '3', 'start_time': '07:30:00', 'end_time': '10:45:00', 'room_name': 'Xưởng 1', 'teacher_name': 'Th.S Hùng'},
        {'section_code': 'S-B', 'subject_name': 'Anh văn', 'day_code': '3', 'start_time': '13:00:00', 'end_time': '16:15:00', 'room_name': 'Curie 5'},
      ],
      'buoi_changes': [
        {'date': '2026-11-24', 'section_code': 'S-A', 'status': 'cancelled', 'planned_start': '07:30', 'start_time': '07:30', 'reason': 'Ngày văn hóa Việt Nam'},
        {'date': '2026-11-24', 'section_code': 'S-B', 'status': 'changed', 'planned_start': '13:00', 'start_time': '14:00', 'end_time': '17:15', 'room': 'Curie 12'},
        {'date': '2026-11-27', 'section_code': 'S-A', 'status': 'makeup', 'subject_name': 'Động cơ đốt trong', 'start_time': '07:30', 'end_time': '10:45', 'room': 'Xưởng 2', 'makeup_for': '2026-11-24'},
        {'date': '', 'section_code': 'S-A', 'status': 'cancelled'},
      ],
    });

    test('changes parsed; a row with no date is dropped', () {
      expect(view.buoiChanges.length, 3);
    });

    test('the day: cancelled keeps its card, changed room and time applied', () {
      final day = view.classesOn(DateTime(2026, 11, 24));
      expect(day.length, 2);
      expect(day[0].buoi?.isCancelled, true);
      expect(day[1].room, 'Curie 12');
      expect(day[1].startTime, '14:00');
    });

    test('a makeup appears on its own date; a normal week is untouched', () {
      final fri = view.classesOn(DateTime(2026, 11, 27));
      expect(fri.length, 1);
      expect(fri[0].buoi?.isMakeup, true);
      expect(fri[0].room, 'Xưởng 2');
      final next = view.classesOn(DateTime(2026, 12, 1));
      expect(next.every((c) => c.buoi == null), true);
    });

    test('older servers without buoi_changes: same as the weekly pattern', () {
      final v = CrmStudentScheduleView.fromJson({'schedule': [
        {'section_code': 'S-A', 'day_code': '3', 'start_time': '07:30:00'},
      ]});
      expect(v.classesOn(DateTime(2026, 11, 24)).single.buoi, isNull);
    });

    testWidgets('student card: "Nghỉ", struck time and the reason, whatever attendance says', (tester) async {
      final c = view.classesOn(DateTime(2026, 11, 24)).first;
      await tester.pumpWidget(_wrap(StudentScheduleCard(data: c, status: 'upcoming')));
      expect(find.text('Nghỉ'), findsOneWidget);
      expect(find.text('Sắp tới'), findsNothing);
      expect(find.text('Lý do: Ngày văn hóa Việt Nam'), findsOneWidget);
    });

    testWidgets('student card: makeup badge and what it makes up for', (tester) async {
      final c = view.classesOn(DateTime(2026, 11, 27)).first;
      await tester.pumpWidget(_wrap(StudentScheduleCard(data: c, status: 'upcoming')));
      expect(find.text('Học bù'), findsOneWidget);
      expect(find.text('Bù cho buổi 24/11'), findsOneWidget);
    });
  });
}
