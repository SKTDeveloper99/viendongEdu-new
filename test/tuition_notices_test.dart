import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/tuition_notes.dart';
import 'package:viendongedu2_flutter/models/crm_money_tuition.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  testWidgets('M-53: bảng kê ghi nợ → hiện lời nhắc đóng trước giữa kỳ', (t) async {
    final r = CrmTuitionResponse.fromJson({
      'summary': {'source': 'bang_ke', 'money_known': true, 'owes': true, 'owedTotal': 1000, 'paid': 0, 'balance': 1000},
    });
    await t.pumpWidget(_wrap(TuitionNotices(response: r)));
    expect(find.textContaining('trước kỳ thi giữa kỳ 02/11'), findsOneWidget);
    expect(find.textContaining('bản lưu'), findsNothing);
  });

  testWidgets('không nợ thì không nhắc; bản lưu thì ghi rõ giờ lưu', (t) async {
    final r = CrmTuitionResponse.fromJson({
      'summary': {'source': 'bang_ke', 'money_known': true, 'owes': false},
    }).withOfflineSavedAt(DateTime(2026, 10, 13, 8, 5));
    await t.pumpWidget(_wrap(TuitionNotices(response: r)));
    expect(find.textContaining('giữa kỳ'), findsNothing);
    expect(find.textContaining('bản lưu lúc 08:05 13/10'), findsOneWidget);
  });
}
