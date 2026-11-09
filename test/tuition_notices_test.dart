import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/student_notices.dart';
import 'package:viendongedu2_flutter/components/tuition_notes.dart';
import 'package:viendongedu2_flutter/models/crm_money_tuition.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

final _now = DateTime.utc(2026, 11, 10, 2); // 10/11 09:00 Vietnam

Map<String, dynamic> _summary({required bool owes}) => {
  'source': 'bang_ke',
  'money_known': true,
  'owes': owes,
  'owedTotal': 1000,
  'paid': 0,
  'balance': 1000,
};

void main() {
  testWidgets('owes and no server notice → date-free fallback, no old date', (
    t,
  ) async {
    final r = CrmTuitionResponse.fromJson({'summary': _summary(owes: true)});
    await t.pumpWidget(_wrap(TuitionNotices(response: r, now: () => _now)));
    expect(find.text(TuitionNotices.debtFallback), findsOneWidget);
    expect(
      TuitionNotices.debtFallback,
      'Bạn còn nợ học phí. Vui lòng đóng trước buổi thi gần nhất để được dự thi.',
    );
    expect(find.textContaining('02/11'), findsNothing);
    expect(find.textContaining('giữa kỳ'), findsNothing);
    expect(find.textContaining('bản lưu'), findsNothing);
  });

  testWidgets('server notice replaces the fallback and is drawn as sent', (
    t,
  ) async {
    const text =
        'Bạn còn nợ học phí HK 261. Buổi thi gần nhất của bạn: Thứ Bảy 14/11. '
        'Vui lòng đóng trước ngày này để được dự thi.';
    final r = CrmTuitionResponse.fromJson({
      'summary': _summary(owes: true),
      'notices': [
        {
          'id': 'debt-261-2026-11-14',
          'level': 'urgent',
          'text': text,
          'until': '2026-11-14',
        },
      ],
    });
    await t.pumpWidget(_wrap(TuitionNotices(response: r, now: () => _now)));
    expect(find.text(text), findsOneWidget);
    expect(find.text(TuitionNotices.debtFallback), findsNothing);
    expect(find.byType(StudentNoticeBanner), findsOneWidget);
  });

  testWidgets('an expired server notice falls back to the date-free line', (
    t,
  ) async {
    final r = CrmTuitionResponse.fromJson({
      'summary': _summary(owes: true),
      'notices': [
        {'id': 'old', 'level': 'urgent', 'text': 'Cũ', 'until': '2026-11-08'},
      ],
    });
    await t.pumpWidget(_wrap(TuitionNotices(response: r, now: () => _now)));
    expect(find.text('Cũ'), findsNothing);
    expect(find.text(TuitionNotices.debtFallback), findsOneWidget);
  });

  testWidgets('not owing: no reminder; offline copy says when it was saved', (
    t,
  ) async {
    final r = CrmTuitionResponse.fromJson({
      'summary': {'source': 'bang_ke', 'money_known': true, 'owes': false},
    }).withOfflineSavedAt(DateTime(2026, 10, 13, 8, 5));
    await t.pumpWidget(_wrap(TuitionNotices(response: r, now: () => _now)));
    expect(find.text(TuitionNotices.debtFallback), findsNothing);
    expect(find.byType(StudentNoticeBanner), findsNothing);
    expect(find.textContaining('bản lưu lúc 08:05 13/10'), findsOneWidget);
  });

  test('offline copies keep the server notices', () {
    final r = CrmTuitionResponse.fromJson({
      'summary': _summary(owes: false),
      'notices': [
        {'id': 'n', 'level': 'info', 'text': 'Tin'},
      ],
    }).withOfflineSavedAt(DateTime(2026, 11, 10));
    expect(r.notices.single.id, 'n');
  });
}
