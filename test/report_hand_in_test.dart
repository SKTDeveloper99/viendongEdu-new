import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/work/hand_in_sheet.dart';
import 'package:viendongedu2_flutter/features/work/report_sheet.dart';
import 'package:viendongedu2_flutter/features/work/work_api.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

void main() {
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
  });

  test('names go plain for the report path', () {
    expect(asciiName('Ảnh 19-11 (2).jpg'), 'Anh 19-11 (2).jpg');
    expect(asciiName('Đường đi ✓.png'), 'Duong di _.png');
  });

  test('words are counted as the server counts them', () {
    expect(wordCount(''), 0);
    expect(wordCount('  một   hai\nba\tbốn  '), 4);
  });

  test('a duty report needs the report sheet; an ordinary piece does not', () {
    final duty = ReportRule.of({
      'is_report': true,
      'min_words': 200,
      'min_photos': 2,
      'max_photos': 8,
    });
    expect(duty.needsReportSheet, isTrue);
    expect(duty.photoCap, 8);
    expect(ReportRule.of({'is_report': false}).needsReportSheet, isFalse);
    expect(ReportRule.of({'min_words': '50'}).needsReportSheet, isTrue);
    expect(ReportRule.of({'max_photos': 20}).photoCap, 8);
  });

  test(
    'the rule comes from my own list, where the template is folded in',
    () async {
      EmsApiService.client = MockClient(
        (_) async => http.Response(
          '{"tasks":[{"assignment_id":"A1","is_report":true,'
          '"min_words":200,"min_photos":2,"max_photos":8}]}',
          200,
        ),
      );
      final r = await WorkApi.ruleFor({'report_min_words': null}, 'A1');
      expect(r.isReport, isTrue);
      expect(r.minWords, 200);
      expect(r.minPhotos, 2);
    },
  );

  test('a report goes in one request: note and photos to /report', () async {
    AppSession.instance.emsToken = 'tok';
    late http.Request seen;
    EmsApiService.client = MockClient((req) async {
      seen = req;
      return http.Response('{"ok":true}', 200);
    });
    await WorkApi.submitReport(
      'A1',
      note: 'nội dung',
      photos: [
        (bytes: [1], filename: 'a.jpg'),
        (bytes: [2], filename: 'Ảnh 19-11 15.08.jpg'),
      ],
    );
    expect(seen.url.path, endsWith('/v1/teacher/tasks/A1/report'));
    expect(seen.body, contains('name="note"'));
    expect(seen.body, contains('nội dung'));
    expect('name="photos"'.allMatches(seen.body).length, 2);
    expect(seen.body, contains('filename="Anh 19-11 15.08.jpg"'));
  });

  testWidgets('the sheet holds Nộp until 200 words and 2 photos are there', (
    t,
  ) async {
    HandInResult? got;
    await t.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async => got = await showReportSheet(
                ctx,
                assignmentId: 'A9',
                rule: const ReportRule(
                  isReport: true,
                  minWords: 200,
                  minPhotos: 2,
                  maxPhotos: 8,
                ),
                photosOnPart: 1,
                pickPhotos: () async => [
                  (name: 'x.jpg', size: 1, read: () async => <int>[1]),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    FilledButton send() =>
        t.widget<FilledButton>(find.byKey(const ValueKey('report-send')));
    expect(send().onPressed, isNull);
    await t.enterText(
      find.byKey(const ValueKey('report-text')),
      List.filled(200, 'từ').join(' '),
    );
    await t.pump();
    expect(find.text('200/200 từ'), findsOneWidget);
    // One photo is already on the part; one more makes the minimum.
    expect(send().onPressed, isNull);
    await t.ensureVisible(find.byKey(const ValueKey('report-add-photo')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('report-add-photo')));
    await t.pumpAndSettle();
    expect(send().onPressed, isNotNull);
    await t.ensureVisible(find.byKey(const ValueKey('report-send')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('report-send')));
    await t.pumpAndSettle();
    expect(got?.files.single.name, 'x.jpg');
    expect(wordCount(got!.note), 200);
  });
}
