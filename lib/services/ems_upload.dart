import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'app_session.dart';
import 'ems_api_service.dart';

/// One file to the CRM as multipart (the web's FormData call), e.g.
/// `POST /v1/tasks/:id/attachments` with field `file` (+ `assignment_id`).
abstract final class EmsUpload {
  static Duration timeout = const Duration(seconds: 60);

  static Future<Map<String, dynamic>> file(
    String path, {
    required String filePath,
    String field = 'file',
    String? filename,
    Map<String, String> fields = const {},
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${EmsApiService.baseUrl}$path'),
    );
    final t = AppSession.instance.emsToken;
    if (t != null && t.isNotEmpty) req.headers['Authorization'] = 'Bearer $t';
    req.fields.addAll(fields);
    // The real name and type, so the server stores e.g. image/jpeg or
    // application/pdf instead of application/octet-stream.
    final name = filename ?? filePath.split('/').last;
    final type = lookupMimeType(name) ?? 'application/octet-stream';
    req.files.add(
      await http.MultipartFile.fromPath(
        field,
        filePath,
        filename: name,
        contentType: MediaType.parse(type),
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
    Map<String, dynamic> body = const {};
    try {
      body = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    } catch (_) {}
    if (res.statusCode >= 400) {
      throw EmsException(
        refusal(body['error'] ?? body['message'], res.statusCode),
        statusCode: res.statusCode,
        requestToken: t,
      );
    }
    return body;
  }

  /// The server's refusal in plain words (codes from lib/tasks/uploads.js;
  /// its own Vietnamese messages pass through unchanged).
  static String refusal(Object? error, int status) =>
      switch ('${error ?? ''}') {
        'file_too_large' => 'Tệp quá lớn (tối đa 25 MB mỗi tệp).',
        'unsupported_type' => 'Máy chủ không nhận loại tệp này.',
        'too_many_files' => 'Quá nhiều tệp cho việc này.',
        'upload_failed' || '' => 'Không gửi được tệp ($status).',
        final m => m,
      };
}
