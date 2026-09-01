import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_session.dart';

/// Lỗi từ EMS. `code` là mã máy ổn định (ví dụ 'account_deactivated'),
/// `message` là câu tiếng Việt hiển thị cho người dùng.
class EmsException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  EmsException(this.message, {this.code, this.statusCode});

  /// EMS đã trả lời và từ chối có chủ đích — KHÔNG phải lỗi mạng, không thử lại.
  bool get isDeliberateDenial =>
      statusCode == 403 || statusCode == 404 || statusCode == 401;

  @override
  String toString() => message;
}

/// Cầu nối tới EMS (CRM Viễn Đông).
///
/// Tách hẳn khỏi [ApiService] (IMS) vì hai hệ thống có hai token riêng và hai
/// vòng đời riêng: EMS hỏng thì màn hình IMS vẫn phải chạy bình thường.
///
/// Không hardcode IP/port, không bỏ qua kiểm tra TLS.
class EmsApiService {
  /// Production. Đổi khi build bằng:
  ///   flutter build --dart-define=EMS_API_BASE_URL=https://.../api
  static const String baseUrl = String.fromEnvironment(
    'EMS_API_BASE_URL',
    defaultValue: 'https://ems.viendong.edu.vn/api',
  );

  static const Duration _timeout = Duration(seconds: 15);

  /// Đường ra mạng. Thay được trong test để chạy màn hình Bảng tin với dữ liệu
  /// dựng sẵn; trong app thật luôn là client HTTP mặc định (giữ nguyên kiểm tra
  /// TLS — không có chế độ bỏ qua chứng chỉ).
  static http.Client client = http.Client();

  /// Header cho widget ảnh (Image.network) — ảnh cũng nằm sau Bearer token.
  static Map<String, String> get authHeaders {
    final t = AppSession.instance.emsToken;
    return (t == null || t.isEmpty) ? const {} : {'Authorization': 'Bearer $t'};
  }

  static Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final t = AppSession.instance.emsToken;
      if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  /// Đọc body JSON và dựng [EmsException] từ cả `error` lẫn `message`.
  ///
  /// Server trả `{error: <mã máy>, message: <tiếng Việt>}` cho các lỗi có mã,
  /// và `{error: <câu tiếng Việt>}` cho các lỗi do middleware dựng. Xử lý cả
  /// hai dạng, và cả trường hợp body KHÔNG phải JSON (nginx/Cloudflare chen vào
  /// một trang HTML) — lúc đó vẫn phải là một lỗi đọc được, không phải crash.
  static Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body == null) {
        throw EmsException('Máy chủ trả về dữ liệu không đọc được.',
            statusCode: res.statusCode);
      }
      return body;
    }

    final rawError = body?['error']?.toString();
    final rawMessage = body?['message']?.toString();
    throw EmsException(
      rawMessage ?? rawError ?? 'Không kết nối được máy chủ thông tin.',
      code: rawError,
      statusCode: res.statusCode,
    );
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    http.Response res;
    try {
      final headers = _headers(auth: auth);
      final encoded = body == null ? null : jsonEncode(body);
      res = await (method == 'POST'
              ? client.post(uri, headers: headers, body: encoded)
              : client.get(uri, headers: headers))
          .timeout(_timeout);
    } catch (e) {
      // Mạng hỏng / quá hạn / DNS — không có statusCode, nên không bị coi là
      // từ chối có chủ đích và màn hình sẽ hiện nút "Thử lại".
      throw EmsException('Không tải được bảng tin. Vui lòng thử lại.');
    }
    return _decode(res);
  }

  // ── Identity mirror ────────────────────────────────────────────────────────
  // Token IMS CHÍNH LÀ giấy thông hành ở đây; các endpoint này không cần Bearer.

  /// Đổi token IMS của học viên lấy token EMS. Trả về token EMS.
  static Future<String> mirrorStudent(String imsToken) async {
    final body = await _send('POST', '/v1/identity/mirror',
        body: {'ims_token': imsToken}, auth: false);
    final token = body['crm_token']?.toString();
    if (token == null || token.isEmpty) {
      throw EmsException('Máy chủ thông tin không cấp được phiên đăng nhập.');
    }
    return token;
  }

  /// Bản đối chiếu cho giảng viên.
  static Future<String> mirrorTeacher(
    String imsToken, {
    String? fcmToken,
    String? platform,
    String? appVersion,
  }) async {
    final body = await _send('POST', '/v1/identity/teacher-mirror', body: {
      'ims_token': imsToken,
      // Null-aware entries: bỏ hẳn khoá khi giá trị null, không gửi null.
      'fcm_token': ?fcmToken,
      'platform': ?platform,
      'app_version': ?appVersion,
    }, auth: false);
    final token = body['crm_token']?.toString();
    if (token == null || token.isEmpty) {
      throw EmsException('Máy chủ thông tin không cấp được phiên đăng nhập.');
    }
    return token;
  }

  // ── Bảng tin ───────────────────────────────────────────────────────────────
  //
  // Mỗi lời gọi đi qua [_withReMirror]: gặp 401 thì thử đối chiếu LẠI MỘT LẦN
  // bằng token IMS hiện có rồi gọi lại. Một lần, không lặp — 401 lần hai nghĩa
  // là phiên IMS cũng đã hết, và việc thử mãi chỉ tạo bão request.

  static Future<T> _withReMirror<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on EmsException catch (e) {
      if (e.statusCode != 401) rethrow;
      final ok = await AppSession.instance.refreshEmsToken();
      if (!ok) rethrow;
      return await call();
    }
  }

  static Future<List<AnnouncementItem>> board({int limit = 50}) {
    return _withReMirror(() async {
      final body = await _send('GET', '/v1/student/board?limit=$limit');
      final items = body['items'];
      if (items is! List) return <AnnouncementItem>[];
      return items
          .whereType<Map<String, dynamic>>()
          .map(AnnouncementItem.fromJson)
          .toList();
    });
  }

  static Future<BoardUnread> unreadCount() {
    return _withReMirror(() async {
      final body = await _send('GET', '/v1/student/board/unread-count');
      return BoardUnread(
        unread: (body['unread'] as num?)?.toInt() ?? 0,
        mustReadPending: (body['must_read_pending'] as num?)?.toInt() ?? 0,
      );
    });
  }

  /// Đóng dấu đã đọc. Idempotent ở phía server: gọi lại không đổi mốc thời gian.
  static Future<void> markRead(String id) {
    return _withReMirror(() => _send('POST', '/v1/student/board/$id/read'));
  }

  /// Xác nhận đã đọc và hiểu. Server đóng cả hai mốc trong một câu lệnh.
  static Future<void> acknowledge(String id) {
    return _withReMirror(
        () => _send('POST', '/v1/student/board/$id/acknowledge'));
  }
}

/// Một tấm ảnh kèm theo thông báo.
///
/// [url] là đường dẫn tương đối server trả về; [absoluteUrl] ghép với base để
/// widget ảnh dùng trực tiếp. Ảnh cần Bearer token nên phải kèm [authHeaders].
class AnnouncementImage {
  final String id;
  final String url;
  final int? width;
  final int? height;

  const AnnouncementImage({
    required this.id,
    required this.url,
    this.width,
    this.height,
  });

  factory AnnouncementImage.fromJson(Map<String, dynamic> j) => AnnouncementImage(
        id: j['id']?.toString() ?? '',
        url: j['url']?.toString() ?? '',
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
      );

  /// Server trả '/api/v1/...' còn baseUrl đã kết thúc bằng '/api' — cắt phần
  /// '/api' trùng để không thành '/api/api/v1/...'.
  String get absoluteUrl {
    final base = EmsApiService.baseUrl;
    final path = url.startsWith('/api') ? url.substring(4) : url;
    return '$base$path';
  }

  double? get aspectRatio =>
      (width != null && height != null && height! > 0) ? width! / height! : null;
}

class BoardUnread {
  final int unread;
  final int mustReadPending;
  const BoardUnread({required this.unread, required this.mustReadPending});
}

/// Một thông báo đã đến tay học viên này.
///
/// `body` là NGUYÊN VĂN server đã đóng băng lúc phát hành — app không ghép
/// trường, không dựng lại từ mẫu.
class AnnouncementItem {
  final String id;
  final String title;
  final String body;
  final String? category;
  final bool mustRead;
  final bool isCorrection;
  final DateTime? publishedAt;
  final List<AnnouncementImage> images;
  DateTime? readAt;
  DateTime? acknowledgedAt;

  AnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    this.category,
    this.mustRead = false,
    this.isCorrection = false,
    this.publishedAt,
    this.images = const [],
    this.readAt,
    this.acknowledgedAt,
  });

  bool get isUnread => readAt == null;
  bool get needsAcknowledgement => mustRead && acknowledgedAt == null;

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  factory AnnouncementItem.fromJson(Map<String, dynamic> j) => AnnouncementItem(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        category: j['category']?.toString(),
        mustRead: j['must_read'] == true,
        isCorrection: j['is_correction'] == true,
        publishedAt: _date(j['published_at']),
        images: (j['images'] is List)
            ? (j['images'] as List)
                .whereType<Map<String, dynamic>>()
                .map(AnnouncementImage.fromJson)
                .toList()
            : const [],
        readAt: _date(j['read_at']),
        acknowledgedAt: _date(j['acknowledged_at']),
      );

  static const Map<String, String> categoryLabels = {
    'general': 'Thông báo chung',
    'schedule': 'Lịch học / lịch thi',
    'deadline': 'Hạn chót',
    'urgent': 'Khẩn',
  };

  String get categoryLabel => categoryLabels[category] ?? 'Thông báo';
}
