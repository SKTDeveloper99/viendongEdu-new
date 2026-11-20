// Uploads on a weak network: a time limit by size, two resends after a
// network failure only (never after an answer of the server), a fresh
// request per attempt, and the line the person sees while it resends.
//
//   flutter test test/upload_sender_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/ems_upload.dart';
import 'package:viendongedu2_flutter/services/upload_sender.dart';

const _mb = 1024 * 1024;

http.MultipartRequest _req() =>
    http.MultipartRequest('POST', Uri.parse('https://example.test/up'))
      ..fields['note'] = 'Nguyễn Văn Thử'
      ..files.add(
        http.MultipartFile.fromBytes('file', [1, 2, 3], filename: 'a.jpg'),
      );

void main() {
  final pauses = <Duration>[];
  Future<void> instant(Duration d) async => pauses.add(d);

  setUp(() {
    pauses.clear();
    UploadSender.sleep = instant;
    AppSession.instance.emsToken = 'tok-TEST26APP01';
  });
  tearDown(() {
    UploadSender.sleep = Future<void>.delayed;
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
  });

  group('rule b: the time limit grows with the size', () {
    test('base plus seconds per MB, with a floor and a ceiling', () {
      expect(UploadSender.timeoutFor(0), const Duration(seconds: 60));
      expect(UploadSender.timeoutFor(1 * _mb), const Duration(seconds: 60));
      expect(UploadSender.timeoutFor(4 * _mb), const Duration(seconds: 90));
      expect(UploadSender.timeoutFor(25 * _mb), const Duration(seconds: 405));
      expect(UploadSender.timeoutFor(500 * _mb), const Duration(minutes: 10));
    });

    test('never shrinks as the file grows', () {
      var last = Duration.zero;
      for (var b = 0; b <= 60 * _mb; b += _mb ~/ 2) {
        final t = UploadSender.timeoutFor(b);
        expect(t >= last, isTrue, reason: '$b bytes');
        last = t;
      }
    });

    test('a stuck connection hits the limit and counts as a network '
        'failure', () async {
      var calls = 0;
      final client = MockClient.streaming((req, body) {
        calls++;
        return Completer<http.StreamedResponse>().future; // never answers
      });
      await expectLater(
        UploadSender.send(
          _req,
          client: client,
          timeout: const Duration(milliseconds: 20),
          pause: instant,
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, 3);
    });
  });

  group('rule c: two resends on network failures only', () {
    for (final (name, error) in <(String, Object)>[
      ('socket error', const SocketException('Network is unreachable')),
      ('DNS', const SocketException('Failed host lookup: example.test')),
      ('connection reset', http.ClientException('Connection reset by peer')),
      ('timeout', TimeoutException('slow')),
    ]) {
      test('$name: sent again with a fresh request, then it goes', () async {
        final bodies = <String>[];
        var calls = 0;
        final client = MockClient((req) async {
          calls++;
          bodies.add(req.body);
          if (calls < 3) throw error;
          return http.Response('{"ok":true}', 201);
        });
        final res = await UploadSender.send(
          _req,
          client: client,
          timeout: const Duration(seconds: 5),
        );
        expect(res.statusCode, 201);
        expect(calls, 3);
        // Each attempt carried the whole body (a stream is read only once).
        for (final b in bodies) {
          expect(b, contains('Nguyễn Văn Thử'));
          expect(b, contains('filename="a.jpg"'));
        }
        expect(pauses, UploadSender.pauses);
      });
    }

    test('three network failures: the last one is thrown', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        throw const SocketException('Connection timed out');
      });
      await expectLater(
        UploadSender.send(
          _req,
          client: client,
          timeout: const Duration(seconds: 5),
        ),
        throwsA(isA<SocketException>()),
      );
      expect(calls, 3);
      expect(pauses, hasLength(2));
    });

    for (final status in [400, 403, 413, 429, 500, 503]) {
      test('an answer $status is final: sent once', () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response('{"error":"x"}', status);
        });
        final res = await UploadSender.send(
          _req,
          client: client,
          timeout: const Duration(seconds: 5),
        );
        expect(res.statusCode, status);
        expect(calls, 1);
        expect(pauses, isEmpty);
      });
    }

    test('a broken answer is not resent (the server may have it)', () async {
      var calls = 0;
      final client = MockClient.streaming((req, body) async {
        calls++;
        await body.drain<void>();
        return http.StreamedResponse(
          Stream<List<int>>.error(const SocketException('reset')),
          200,
        );
      });
      await expectLater(
        UploadSender.send(
          _req,
          client: client,
          timeout: const Duration(seconds: 5),
        ),
        throwsA(isA<UploadAnswerLost>()),
      );
      expect(calls, 1);
    });

    test('anything else (a bug, not the network) is not resent', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        throw const FormatException('bad');
      });
      await expectLater(
        UploadSender.send(
          _req,
          client: client,
          timeout: const Duration(seconds: 5),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 1);
    });

    test('EmsUpload: a refusal shows the server\'s own words, once', () async {
      var calls = 0;
      EmsApiService.client = MockClient((_) async {
        calls++;
        return http.Response.bytes(
          utf8.encode('{"error":"Máy chủ đang bận, thử lại sau ít phút."}'),
          503,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await expectLater(
        EmsUpload.file('/v1/x', bytes: [1], filename: 'a.pdf'),
        throwsA(
          isA<EmsException>()
              .having(
                (e) => e.message,
                'message',
                'Máy chủ đang bận, thử lại sau ít phút.',
              )
              .having((e) => e.statusCode, 'status', 503),
        ),
      );
      expect(calls, 1);
    });

    test('EmsUpload: network down three times says so in Vietnamese', () async {
      var calls = 0;
      EmsApiService.client = MockClient((_) async {
        calls++;
        throw const SocketException('Network is unreachable');
      });
      await expectLater(
        EmsUpload.file('/v1/x', bytes: [1], filename: 'a.pdf'),
        throwsA(
          isA<EmsException>().having(
            (e) => e.message,
            'message',
            EmsUpload.networkMessage,
          ),
        ),
      );
      expect(calls, 3);
    });

    test('EmsUpload: the size checks still come before any sending', () async {
      var calls = 0;
      EmsApiService.client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      await expectLater(
        EmsUpload.files(
          '/v1/x',
          files: [(bytes: List<int>.filled(11, 0), filename: 'a.jpg')],
          maxBytes: 10,
        ),
        throwsA(isA<EmsException>().having((e) => e.statusCode, 's', 413)),
      );
      expect(calls, 0);
    });
  });

  group('rule d: the person sees it resend', () {
    test('status lines: progress, then "đang gửi lại (lần 2/3)"', () async {
      final lines = <String>[];
      var calls = 0;
      EmsApiService.client = MockClient((_) async {
        calls++;
        if (calls == 1) throw const SocketException('reset');
        return http.Response('{"ok":true}', 200);
      });
      await EmsUpload.file(
        '/v1/x',
        bytes: [1, 2, 3],
        filename: 'a.pdf',
        onStatus: (s) => lines.add(s.text),
      );
      expect(lines.first, 'Đang gửi… 0%');
      expect(lines, contains('Mạng yếu, đang gửi lại (lần 2/3)…'));
      expect(lines.last, 'Mạng yếu, đang gửi lại (lần 2/3)… 100%');
    });

    test('the third attempt says lần 3/3', () {
      expect(
        const UploadStatus(attempt: 3, attempts: 3).text,
        'Mạng yếu, đang gửi lại (lần 3/3)…',
      );
      expect(const UploadStatus(attempt: 1, attempts: 3).text, 'Đang gửi…');
      expect(
        const UploadStatus(attempt: 1, attempts: 3, sent: 1, total: 4).text,
        'Đang gửi… 25%',
      );
    });
  });

  test('rule a: one shared size for every photo pick', () {
    expect(PhotoShrink.maxEdge, 2000);
    expect(PhotoShrink.quality, 80);
  });
}
