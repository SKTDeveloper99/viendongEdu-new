import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'app_session.dart';
import 'ems_api_service.dart';

/// Files to and from the CRM with the person's session: one file up as
/// multipart (the web's FormData call), one file down into the app's cache.
abstract final class EmsUpload {
  static Duration timeout = const Duration(seconds: 60);

  /// Content type from the file name (and first bytes); octet-stream if unknown.
  static String typeOf(String name, [List<int>? head]) =>
      lookupMimeType(name, headerBytes: head) ?? 'application/octet-stream';

  /// `POST path` with field `file` (+ [fields]), e.g.
  /// `/v1/tasks/:id/attachments` + `assignment_id`. Sends the real name and
  /// content type, so the server stores e.g. application/pdf.
  static Future<Map<String, dynamic>> file(
    String path, {
    required List<int> bytes,
    required String filename,
    String field = 'file',
    Map<String, String> fields = const {},
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${EmsApiService.baseUrl}$path'),
    );
    final t = AppSession.instance.emsToken;
    if (t != null && t.isNotEmpty) req.headers['Authorization'] = 'Bearer $t';
    req.fields.addAll(fields);
    final head = bytes.length > 32 ? bytes.sublist(0, 32) : bytes;
    req.files.add(
      http.MultipartFile.fromBytes(
        field,
        bytes,
        filename: filename,
        contentType: MediaType.parse(typeOf(filename, head)),
      ),
    );
    http.Response res;
    try {
      res = await http.Response.fromStream(
        await EmsApiService.client.send(req).timeout(timeout),
      );
    } catch (_) {
      throw EmsException('Không gửi được tệp. Kiểm tra mạng rồi thử lại.');
    }
    final body = _json(res.body);
    if (res.statusCode >= 400) {
      throw EmsException(
        refusal(body['error'] ?? body['message'], res.statusCode),
        statusCode: res.statusCode,
        requestToken: t,
      );
    }
    return body;
  }

  /// `GET path` with the session into `<cache>/vd_files/<key>/<name>` (the
  /// phone's viewer shows the plain file name as its title).
  static Future<File> download(
    String path, {
    required String filename,
    required String key,
  }) async {
    final t = AppSession.instance.emsToken;
    http.Response res;
    try {
      res = await EmsApiService.client
          .get(
            Uri.parse('${EmsApiService.baseUrl}$path'),
            headers: {
              if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
            },
          )
          .timeout(timeout);
    } catch (_) {
      throw EmsException('Không tải được tệp. Kiểm tra mạng rồi thử lại.');
    }
    if (res.statusCode >= 400) {
      final body = _json(res.body);
      throw EmsException(
        refusal(body['error'] ?? body['message'], res.statusCode),
        statusCode: res.statusCode,
        requestToken: t,
      );
    }
    final dir = Directory('${Directory.systemTemp.path}/vd_files/$key');
    await dir.create(recursive: true);
    final safe = filename.replaceAll(RegExp(r'[/\\:\0]'), '_');
    final f = File('${dir.path}/$safe');
    await f.writeAsBytes(res.bodyBytes, flush: true);
    return f;
  }

  static Map<String, dynamic> _json(String s) {
    try {
      return (jsonDecode(s) as Map).cast<String, dynamic>();
    } catch (_) {
      return const {};
    }
  }

  /// The server's refusal in plain words (codes from lib/tasks/uploads.js;
  /// its own Vietnamese messages pass through unchanged).
  static String refusal(Object? error, int status) =>
      switch ('${error ?? ''}') {
        'file_too_large' => 'Tệp quá lớn (tối đa 25 MB mỗi tệp).',
        'unsupported_type' => 'Máy chủ không nhận loại tệp này.',
        'too_many_files' => 'Quá nhiều tệp cho việc này.',
        'file_missing' => 'Tệp không còn trên máy chủ.',
        'upload_failed' || '' => 'Không gửi được tệp ($status).',
        final m => m,
      };
}
