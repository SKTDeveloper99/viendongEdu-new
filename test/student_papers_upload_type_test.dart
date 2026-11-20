// Nộp hồ sơ upload: the server takes a PDF only when the multipart part says
// application/pdf AND the bytes start with %PDF-; JPEG/PNG must say image/*.
// These pin what the app actually sends, including a PDF whose picked name
// has no .pdf ending.
//
//   flutter test test/student_papers_upload_type_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/student_papers/papers_api.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

List<int> _pdf() => [...ascii.encode('%PDF-1.7\n'), ...List.filled(64, 32)];
List<int> _jpeg() => [0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(64, 0)];
List<int> _png() => [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ...List.filled(64, 0),
];

void main() {
  late http.Request seen;
  setUp(() {
    AppSession.instance.emsToken = 'crm-student-token';
    EmsApiService.client = MockClient((req) async {
      seen = req;
      return http.Response(jsonEncode({'ok': true}), 200);
    });
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
  });

  String partType() {
    final m = RegExp(
      r'content-type:\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(latin1.decode(seen.bodyBytes));
    return m!.group(1)!.trim();
  }

  for (final (name, bytes, type) in [
    ('Giay kham TEST26APP01.pdf', _pdf(), 'application/pdf'),
    ('document', _pdf(), 'application/pdf'),
    ('Ảnh 20-11 09.00.jpg', _jpeg(), 'image/jpeg'),
    ('Ảnh 20-11 09.01.png', _png(), 'image/png'),
  ]) {
    test('"$name" goes out as $type in field files[]', () async {
      await StudentPapersApi.send(
        'giay_kham',
        bytes: bytes,
        filename: name,
        maxBytes: 12 * 1024 * 1024,
      );
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/student/me/papers/giay_kham/files');
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));
      expect(latin1.decode(seen.bodyBytes), contains('name="files[]"'));
      expect(partType(), type);
    });
  }
}
