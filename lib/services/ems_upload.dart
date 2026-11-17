import 'dart:convert';

import 'package:http/http.dart' as http;

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
    req.files.add(
      await http.MultipartFile.fromPath(field, filePath, filename: filename),
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
        '${body['error'] ?? body['message'] ?? 'Không gửi được tệp (${res.statusCode}).'}',
        statusCode: res.statusCode,
        requestToken: t,
      );
    }
    return body;
  }
}
