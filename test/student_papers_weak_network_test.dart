// Nộp hồ sơ on a weak network: the item shows "đang gửi lại (lần 2/3)",
// files that went stay sent and "Gửi tiếp" sends only the rest; a refusal
// is final; the server's max_file_mb still applies to the file sent.
//
//   flutter test test/student_papers_weak_network_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/features/student_papers/papers_api.dart';
import 'package:viendongedu2_flutter/features/student_papers/papers_screen.dart';
import 'package:viendongedu2_flutter/features/work/hand_in_sheet.dart'
    show PickedFile;
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/ems_upload.dart';
import 'package:viendongedu2_flutter/services/upload_sender.dart';

PapersPage _page() => PapersPage(
  [
    PaperItem.fromJson({
      'code': 'giay_kham',
      'label': 'Giấy khám sức khỏe',
      'accepts': 'photo_or_pdf',
      'accepts_label': 'Ảnh chụp hoặc tệp PDF',
      'state': 'none',
      'state_label': 'Còn thiếu',
      'files': [],
    }),
  ],
  'Hiện trường chưa yêu cầu bạn nộp giấy tờ nào.',
  1024 * 1024,
);

PickedFile _file(String name, int size) =>
    (name: name, size: size, read: () async => List<int>.filled(size, 1));

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.emsToken = 'tok-TEST26APP01';
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    UploadSender.sleep = Future<void>.delayed;
    AppSession.instance.emsToken = null;
  });

  String nameOf(http.Request r) =>
      RegExp(r'filename="([^"]+)"').firstMatch(r.body)![1]!;

  testWidgets('resends show; after the third failure "Gửi tiếp" sends the '
      'rest only', (tester) async {
    final posted = <String>[];
    final tries = <String, int>{};
    var down = true;
    EmsApiService.client = MockClient((req) async {
      final n = nameOf(req);
      tries[n] = (tries[n] ?? 0) + 1;
      if (n == 'trang2.pdf' && down) {
        throw const SocketException('Failed host lookup: example.test');
      }
      posted.add(n);
      return _json({'ok': true});
    });
    final gates = <Completer<void>>[];
    UploadSender.sleep = (_) {
      final c = Completer<void>();
      gates.add(c);
      return c.future;
    };
    Future<void> some() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await tester.pumpWidget(
      MaterialApp(
        home: StudentPapersScreen(
          load: () async => _page(),
          pickFiles: (_) async => [
            _file('trang1.pdf', 10),
            _file('trang2.pdf', 10),
            _file('trang3.pdf', 10),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paper-add-giay_kham')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paper-source-file')));
    await some();
    expect(
      find.text('Tệp 2/3: Mạng yếu, đang gửi lại (lần 2/3)…'),
      findsOneWidget,
    );
    gates.last.complete();
    await some();
    expect(
      find.text('Tệp 2/3: Mạng yếu, đang gửi lại (lần 3/3)…'),
      findsOneWidget,
    );
    gates.last.complete();
    await tester.pumpAndSettle();
    expect(tries['trang2.pdf'], 3);
    expect(
      find.text('${EmsUpload.networkMessage} Đã gửi 1 tệp.'),
      findsOneWidget,
    );
    expect(find.text('Gửi tiếp 2 tệp chưa gửi'), findsOneWidget);

    down = false;
    await tester.tap(find.byKey(const Key('paper-resume-giay_kham')));
    await tester.pumpAndSettle();
    expect(posted, ['trang1.pdf', 'trang2.pdf', 'trang3.pdf']);
    expect(tries['trang1.pdf'], 1);
    expect(find.byKey(const Key('paper-resume-giay_kham')), findsNothing);
    expect(find.text('Đã gửi 2 tệp.'), findsOneWidget);
  });

  testWidgets('a refusal is final: once, its words, nothing kept to resend', (
    tester,
  ) async {
    var tries = 0;
    EmsApiService.client = MockClient((_) async {
      tries++;
      return _json({'error': 'Chỉ nhận ảnh hoặc tệp PDF.'}, 415);
    });
    var paused = 0;
    UploadSender.sleep = (_) async => paused++;
    await tester.pumpWidget(
      MaterialApp(
        home: StudentPapersScreen(
          load: () async => _page(),
          pickFiles: (_) async => [_file('a.pdf', 10), _file('b.pdf', 10)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paper-add-giay_kham')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paper-source-file')));
    await tester.pumpAndSettle();
    expect(tries, 1);
    expect(paused, 0);
    expect(find.text('Chỉ nhận ảnh hoặc tệp PDF.'), findsOneWidget);
    expect(find.byKey(const Key('paper-resume-giay_kham')), findsNothing);
  });

  testWidgets('max_file_mb still applies to the file sent', (tester) async {
    var tries = 0;
    EmsApiService.client = MockClient((_) async {
      tries++;
      return _json({'ok': true});
    });
    await tester.pumpWidget(
      MaterialApp(
        home: StudentPapersScreen(
          load: () async => _page(), // 1 MB
          pickFiles: (_) async => [_file('to.pdf', 1024 * 1024 + 1)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paper-add-giay_kham')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paper-source-file')));
    await tester.pumpAndSettle();
    expect(tries, 0);
    expect(find.text('"to.pdf" quá lớn (tối đa 1 MB).'), findsOneWidget);
  });
}
