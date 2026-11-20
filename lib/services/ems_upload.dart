import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'app_session.dart';
import 'ems_api_service.dart';
import 'upload_sender.dart';

export 'upload_sender.dart' show UploadStatus, PhotoShrink;

/// Files to and from the CRM with the person's session: one file up as
/// multipart (the web's FormData call), one file down into the app's cache.
abstract final class EmsUpload {
  /// Time limit of a download (uploads take theirs from the size).
  static Duration timeout = const Duration(seconds: 60);

  /// Every attempt failed on the network.
  static const networkMessage =
      'Không gửi được tệp. Kiểm tra mạng rồi thử lại.';

  /// The connection broke while the server was answering: it may have the
  /// file already, so nothing is resent on its own.
  static const answerLostMessage =
      'Mạng chập chờn lúc máy chủ đang trả lời, chưa rõ tệp đã lên chưa. '
      'Tải lại để xem trước khi gửi lại.';

  /// The server's per-file ceiling (CRM lib/tasks/uploads.js MAX_SIZE_BYTES).
  /// Checked before sending: on Android the server's early 413 arrives as a
  /// broken connection, so the person saw "Kiểm tra mạng" instead of "quá lớn".
  static const int maxFileBytes = 25 * 1024 * 1024;

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
    void Function(UploadStatus)? onStatus,
  }) => files(
    path,
    files: [(bytes: bytes, filename: filename)],
    field: field,
    fields: fields,
    onStatus: onStatus,
  );

  /// `POST path` with every file under the same [field] (+ [fields]), e.g. a
  /// duty report's `photos` and `note` in one request. No file is fine.
  /// [maxBytes]: the per-file ceiling when the server named one (a Nhóm
  /// table's `file_rules`). [onProgress]: bytes handed to the connection so
  /// far, of the whole request. [onStatus]: the same with the attempt, for
  /// "Mạng yếu, đang gửi lại (lần 2/3)…". Sent through [UploadSender]: a
  /// time limit by size and two resends after a network failure; any answer
  /// of the server is final.
  static Future<Map<String, dynamic>> files(
    String path, {
    required List<({List<int> bytes, String filename})> files,
    String field = 'file',
    Map<String, String> fields = const {},
    int maxBytes = maxFileBytes,
    void Function(int sent, int total)? onProgress,
    void Function(UploadStatus)? onStatus,
  }) async {
    if (files.any((f) => f.bytes.length > maxBytes)) {
      throw EmsException(refusal('file_too_large', 413), statusCode: 413);
    }
    final t = AppSession.instance.emsToken;
    // A fresh request for every attempt: a multipart body is read once.
    http.MultipartRequest build() {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${EmsApiService.baseUrl}$path'),
      );
      if (t != null && t.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $t';
      }
      req.fields.addAll(fields);
      for (final f in files) {
        final head = f.bytes.length > 32 ? f.bytes.sublist(0, 32) : f.bytes;
        req.files.add(
          http.MultipartFile.fromBytes(
            field,
            f.bytes,
            filename: f.filename,
            contentType: MediaType.parse(typeOf(f.filename, head)),
          ),
        );
      }
      return req;
    }

    final size = files.fold<int>(0, (n, f) => n + f.bytes.length);
    http.Response res;
    try {
      res = await UploadSender.send(
        build,
        client: EmsApiService.client,
        timeout: UploadSender.timeoutFor(size),
        onStatus: (s) {
          onStatus?.call(s);
          if (onProgress != null && s.total > 0) onProgress(s.sent, s.total);
        },
      );
    } on UploadAnswerLost {
      throw EmsException(answerLostMessage);
    } catch (_) {
      throw EmsException(networkMessage);
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
    final dir = Directory('$filesRoot/$key');
    await dir.create(recursive: true);
    final safe = filename.replaceAll(RegExp(r'[/\\:\0]'), '_');
    final f = File('${dir.path}/$safe');
    await f.writeAsBytes(res.bodyBytes, flush: true);
    return f;
  }

  /// Where opened attachments are saved (one folder per attachment id).
  @visibleForTesting
  static String filesRoot = '${Directory.systemTemp.path}/vd_files';

  /// Deletes every saved attachment and the picker's temporary copies. Never
  /// throws and is not awaited by sign-out.
  static Future<void> purgeSavedFiles() async {
    try {
      final d = Directory(filesRoot);
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
    try {
      await FilePicker.clearTemporaryFiles();
    } catch (_) {}
  }

  static bool _purgeHooked = false;

  /// Registers [purgeSavedFiles] to run at sign-out (call once at startup).
  static void registerSignOutPurge() {
    if (_purgeHooked) return;
    _purgeHooked = true;
    AppSession.clearHooks.add(() => unawaited(purgeSavedFiles()));
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
