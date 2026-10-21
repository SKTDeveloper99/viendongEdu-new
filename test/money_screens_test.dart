import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:viendongedu2_flutter/components/skeleton.dart';
import 'package:viendongedu2_flutter/screens/capbu_screen.dart';
import 'package:viendongedu2_flutter/screens/lephi_screen.dart';
import 'package:viendongedu2_flutter/screens/tuition_screen.dart';

import 'helpers/screen_harness.dart';

const _tuition = {
  'summary': {
    'source': 'bang_ke',
    'money_known': true,
    'owedTotal': 1234567,
    'paid': 222222,
    'balance': 987654,
  },
  'payments': [
    {
      'phieu_thu_id': 'TEST26-RECEIPT',
      'so_tien': 12345,
      'loai_phieu_thu': 'Học phí thử nghiệm',
      'ngay_nop': '2026-10-20',
    },
  ],
};
const _fees = {
  'totals': {
    'le_phi_khac': 1234567,
    'mien_giam_khen_thuong': 222222,
    'paid_side_contaminated': true,
  },
  'items': [
    {
      'phieu_thu_id': 'TEST26-FEE',
      'so_tien': 12345,
      'loai_phieu_thu': 'Lệ phí thử nghiệm',
      'ngay_nop': '2026-10-20',
    },
  ],
};
const _capbu = {
  'items': [
    {
      'id': 'TEST26-COMP',
      'ma': 'TEST26-CB',
      'ten': 'Cấp bù thử nghiệm',
      'hocky_ten': 'Học kỳ thử nghiệm',
      'ngay_cap': '2026-10-20',
      'thanh_tien': 12345,
      'total': 23456,
      'ghi_chu': 'Ghi chú thử nghiệm',
    },
  ],
};

void main() {
  final cases = [
    (
      screen: const TuitionScreen(),
      path: '/api/student/me/tuition',
      title: 'Học phí',
      empty: 'Không có giao dịch',
      populated: 'Học phí thử nghiệm',
      body: _tuition,
    ),
    (
      screen: const LePhiScreen(),
      path: '/api/student/me/fees',
      title: 'Lệ phí',
      empty: 'Không có lệ phí',
      populated: 'Lệ phí thử nghiệm',
      body: _fees,
    ),
    (
      screen: const CapBuScreen(),
      path: '/api/student/me/capbu',
      title: 'Cấp bù',
      empty: 'Không có hóa đơn cấp bù',
      populated: 'Cấp bù thử nghiệm',
      body: _capbu,
    ),
  ];
  for (final c in cases) {
    for (final width in [320.0, 430.0]) {
      testWidgets('${c.title} loading, error, retry and empty at $width', (
        t,
      ) async {
        final pending = Completer<http.Response>();
        var calls = 0;
        fakeScreenSession((r) async {
          if (r.url.path == '/api/student/me/cong-no') return jsonResponse({});
          expect(r.url.path, c.path);
          expect(r.method, 'GET');
          calls++;
          return calls == 1 ? pending.future : jsonResponse({});
        });
        await openScreen(t, c.screen, width, settle: false);
        expect(find.text(c.title), findsOneWidget);
        expect(
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
              find.byType(Skeleton).evaluate().isNotEmpty,
          isTrue,
        );
        expect(find.text(c.empty), findsNothing);
        expect(t.takeException(), isNull);
        pending.complete(jsonResponse({'error': 'Lỗi tải thử nghiệm'}, 500));
        await t.pumpAndSettle();
        expect(find.textContaining('Lỗi tải thử nghiệm'), findsOneWidget);
        expect(find.text(c.empty), findsNothing);
        expect(t.takeException(), isNull);
        await t.tap(find.text('Thử lại'));
        await t.pumpAndSettle();
        expect(calls, 2);
        expect(find.text(c.empty), findsOneWidget);
        if (c.screen is TuitionScreen) {
          expect(find.text('Đang đối chiếu'), findsWidgets);
          expect(find.text('0 đ'), findsNothing);
        }
        expect(t.takeException(), isNull);
        await expectBack(t);
      });

      testWidgets('${c.title} populated, refresh and back at $width', (
        t,
      ) async {
        var calls = 0;
        fakeScreenSession((r) async {
          if (r.url.path == '/api/student/me/cong-no') return jsonResponse({});
          expect(r.url.path, c.path);
          expect(r.method, 'GET');
          calls++;
          return jsonResponse(c.body);
        });
        await openScreen(t, c.screen, width);
        expect(find.text(c.populated), findsOneWidget);
        expect(find.text('Sổ công nợ (IMS)'), findsNothing);
        expect(t.takeException(), isNull);
        if (c.screen is TuitionScreen) {
          expect(find.text('1.234.567 đ'), findsOneWidget);
          expect(find.text('987.654 đ'), findsOneWidget);
        } else if (c.screen is LePhiScreen) {
          expect(find.text('1.234.567 đ'), findsOneWidget);
          expect(find.textContaining('số liệu cần rà soát'), findsOneWidget);
        } else {
          await t.tap(find.text(c.populated));
          await t.pumpAndSettle();
          expect(find.text('Mã HĐ'), findsOneWidget);
          expect(find.text('23456 đ'), findsOneWidget);
          expect(find.text('Ghi chú thử nghiệm'), findsOneWidget);
          expect(t.takeException(), isNull);
          Navigator.of(t.element(find.text('Mã HĐ'))).pop();
          await t.pumpAndSettle();
        }
        final scrollable = find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(Scrollable),
        );
        await t.drag(scrollable, const Offset(0, 350));
        await t.pumpAndSettle();
        expect(calls, 2);
        expect(find.text(c.populated), findsOneWidget);
        expect(t.takeException(), isNull);
        await expectBack(t);
      });
    }
  }
}
