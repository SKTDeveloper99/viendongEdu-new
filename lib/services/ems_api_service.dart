import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
export '../core/network/ems_exception.dart';
export '../models/board_models.dart';
export '../models/ems_attendance_models.dart';
export '../models/student_case_models.dart';
import '../core/network/ems_exception.dart';
import 'app_session.dart';
import 'offline_snapshot.dart';

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

  static const Duration _readTimeout = Duration(seconds: 7);
  static const Duration _writeTimeout = Duration(seconds: 15);

  /// Đường ra mạng. Thay được trong test để chạy màn hình Bảng tin với dữ liệu
  /// dựng sẵn; trong app thật luôn là client HTTP mặc định (giữ nguyên kiểm tra
  /// TLS — không có chế độ bỏ qua chứng chỉ).
  static http.Client client = http.Client();

  /// Header cho widget ảnh (Image.network) — ảnh cũng nằm sau Bearer token.
  static Map<String, String> get authHeaders {
    final t = AppSession.instance.emsToken;
    return (t == null || t.isEmpty) ? const {} : {'Authorization': 'Bearer $t'};
  }

  static final Random _rng = Random.secure();
  static String? _appVersion;
  static bool _appVersionRead = false;

  static Future<void> _loadAppVersion() async {
    if (_appVersionRead) return;
    _appVersionRead = true;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Header is diagnostic only; never block a request on it.
    }
  }

  static String _requestId() => List.generate(
    16,
    (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  /// Wait before the single GET retry: min(Retry-After, 5)s + 0–1s jitter.
  /// Replaceable in tests.
  static Duration Function(int retryAfterSeconds) retryDelay = (ra) =>
      Duration(seconds: min(ra, 5), milliseconds: _rng.nextInt(1000));

  static final Map<String, Future<dynamic>> _inflight = {};

  static Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'X-Request-Id': _requestId(),
    };
    final v = _appVersion;
    if (v != null) h['X-App-Version'] = v;
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
  ///
  /// Trả về `dynamic` (không chỉ `Map`) vì một số route trả thẳng một mảng
  /// JSON ở cấp cao nhất (vd. `GET /teacher/me/semesters`) — [send] không
  /// còn ép người gọi phải bọc route đó trong một client HTTP riêng chỉ để
  /// đọc mảng.
  static dynamic _decode(http.Response res) {
    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      body = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body == null) {
        throw EmsException(
          'Máy chủ trả về dữ liệu không đọc được.',
          statusCode: res.statusCode,
        );
      }
      return body;
    }

    final map = body is Map<String, dynamic> ? body : null;
    final rawError = map?['error']?.toString();
    final rawMessage = map?['message']?.toString();

    // 422 riêng của điểm danh: có học viên đã quẹt cổng mà bị ghi VẮNG không
    // kèm lý do. Không phải lỗi — là câu hỏi. Màn hình hỏi lý do rồi gửi lại,
    // nên nó cần biết ĐÍCH DANH ai, không chỉ là "lưu thất bại".
    if (map?['code'] == 'punch_conflict_needs_reason') {
      final raw = map?['students'];
      throw EmsPunchConflict(
        rawError ?? 'Cần nêu lý do.',
        students: (raw is List)
            ? raw
                  .whereType<Map<String, dynamic>>()
                  .map(
                    (e) => EmsPunchedStudent(
                      mssv: e['mssv']?.toString() ?? '',
                      punchedAt: DateTime.tryParse(
                        e['punched_at']?.toString() ?? '',
                      )?.toLocal(),
                    ),
                  )
                  .toList()
            : const [],
        statusCode: res.statusCode,
      );
    }

    if (res.statusCode == 503 &&
        (map?['code'] == 'server_busy' || rawError == 'server_busy')) {
      throw EmsException(
        'Máy chủ đang bận, vui lòng thử lại sau giây lát.',
        code: 'server_busy',
        statusCode: 503,
      );
    }

    throw EmsException(
      rawMessage ?? rawError ?? 'Không kết nối được máy chủ thông tin.',
      code: rawError,
      statusCode: res.statusCode,
    );
  }

  /// Đường ra mạng CHUNG cho toàn app — mọi feature-service khác (điểm danh,
  /// bảng tin, và các file các bot khác dựng thêm) đi qua đây thay vì tự viết
  /// http.post/get riêng. Giữ nguyên cách xử lý lỗi cũ: đọc body JSON dựng
  /// [EmsException] (kể cả 401), timeout thì báo lỗi mạng chứ không crash.
  ///
  /// [method] là 'GET' | 'POST' | 'PATCH' | 'DELETE'. [query] được ghép vào
  /// chuỗi query của URL; [body] được jsonEncode làm request body
  /// (POST/PATCH/DELETE).
  ///
  /// 401 KHÔNG còn được thử lại ở đây (không còn token IMS để đối chiếu lại):
  /// nó nghĩa là phiên đã hết hạn. Gọi nơi gọi tự bắt
  /// `EmsException(statusCode: 401)` và điều hướng về `/login` — xem
  /// `AppSession.clear()`.
  static Future<dynamic> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = _buildUri(path, query);
    if (method != 'GET') {
      // Đăng nhập (auth:false) và đăng ký thiết bị nhận thông báo không qua
      // cổng này: chúng tự báo lỗi riêng và không mang dữ liệu học vụ.
      if (auth && !path.contains('/devices')) await _ensureConnectionSure();
      return _decode(await _once(method, uri, body: body, auth: auth));
    }
    // Identical in-flight GETs (same token + URL) share one request.
    final key = '${auth ? AppSession.instance.emsToken : ''}|$uri';
    final existing = _inflight[key];
    if (existing != null) return existing;
    final future = () async {
      return _decode(await _getWithRetry(uri, auth: auth));
    }();
    _inflight[key] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(key);
    }
  }

  // ── Cổng "mạng chắc chắn" cho mọi lần GHI ────────────────────────────────
  // Quy tắc của chủ trường (2026-09-30): khi không chắc mạng, KHÔNG gửi gì lên
  // máy chủ. Một lần ghi trên mạng chập chờn có thể tới máy chủ mà câu trả lời
  // bị mất — thầy/cô không biết đã lưu hay chưa. Nên: nếu chưa có phản hồi
  // HTTP nào trong [_sureWindow] (hoặc lần gần nhất vừa lỗi mạng), hỏi thử một
  // endpoint công khai rất nhỏ; không có phản hồi trong [_probeTimeout] thì
  // KHÔNG gửi, ném lỗi `network_unsure` — màn hình giữ dữ liệu trên máy
  // (điểm danh hiện "CHƯA GỬI") để người dùng bấm gửi lại khi mạng ổn.
  // Đọc (GET) không qua cổng này: đọc được thì hiện bản đã lưu kèm giờ.
  static const Duration _sureWindow = Duration(seconds: 20);
  static const Duration _probeTimeout = Duration(seconds: 3);
  static DateTime? _lastContact; // lần gần nhất nhận được BẤT KỲ phản hồi HTTP
  static bool _lastFailed = false; // lần gần nhất lỗi mạng/quá hạn

  static bool get _connectionSure =>
      !_lastFailed &&
      _lastContact != null &&
      DateTime.now().difference(_lastContact!) < _sureWindow;

  /// Hỏi thử máy chủ. Bất kỳ phản hồi HTTP nào (kể cả 4xx/5xx) đều chứng minh
  /// có đường tới máy chủ; chỉ lỗi mạng hoặc quá 3 giây mới là "không chắc".
  static Future<void> defaultProbe() =>
      client.get(Uri.parse('$baseUrl/app/min-version')).timeout(_probeTimeout);

  /// Thay được trong test (test/flutter_test_config.dart coi máy là có mạng).
  static Future<void> Function() probe = defaultProbe;

  static Future<void> _ensureConnectionSure() async {
    if (_connectionSure) return;
    try {
      await probe();
      _lastContact = DateTime.now();
      _lastFailed = false;
    } catch (_) {
      _lastFailed = true;
      throw EmsException(
        'Mạng không ổn định nên CHƯA GỬI. Dữ liệu vẫn giữ trên máy — '
        'bấm gửi lại khi mạng ổn.',
        code: 'network_unsure',
      );
    }
  }

  /// Test-only: xoá trạng thái mạng giữa các test.
  static void resetConnectionState() {
    _lastContact = null;
    _lastFailed = false;
  }

  static Uri _buildUri(String path, Map<String, String>? query) {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    return uri;
  }

  static Future<http.Response> _once(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    bool auth = true,
    Map<String, String>? extraHeaders,
  }) async {
    // Not awaited: a slow/absent plugin must never delay or hang a request;
    // the header simply appears from the next request on.
    unawaited(_loadAppVersion());
    try {
      final headers = {..._headers(auth: auth), ...?extraHeaders};
      final encoded = body == null ? null : jsonEncode(body);
      final res =
          await (method == 'POST'
                  ? client.post(uri, headers: headers, body: encoded)
                  : method == 'PATCH'
                  ? client.patch(uri, headers: headers, body: encoded)
                  : method == 'DELETE'
                  ? client.delete(uri, headers: headers, body: encoded)
                  : client.get(uri, headers: headers))
              .timeout(method == 'GET' ? _readTimeout : _writeTimeout);
      _lastContact = DateTime.now();
      _lastFailed = false;
      return res;
    } catch (e) {
      _lastFailed = true;
      // Mạng hỏng / quá hạn / DNS — không có statusCode, nên không bị coi là
      // từ chối có chủ đích và màn hình sẽ hiện nút "Thử lại".
      throw EmsException(
        'Không có kết nối Internet hoặc máy chủ không phản hồi. Vui lòng thử lại.',
      );
    }
  }

  /// GET with ONE retry, only when the server answers 503 (busy). Offline and
  /// timeouts are not retried: offline cannot succeed a second later, and
  /// re-sending a timed-out read adds load exactly when the server is
  /// struggling. Writes never come here.
  static Future<http.Response> _getWithRetry(
    Uri uri, {
    bool auth = true,
    Map<String, String>? extraHeaders,
  }) async {
    Future<http.Response> attempt() =>
        _once('GET', uri, auth: auth, extraHeaders: extraHeaders);
    final res = await attempt();
    if (res.statusCode != 503) return res;
    final ra = int.tryParse(res.headers['retry-after'] ?? '') ?? 1;
    await Future<void>.delayed(retryDelay(ra < 0 ? 0 : ra));
    return attempt();
  }

  /// Opt-in disk-cached GET. Stores ETag + body per account (via
  /// [OfflineSnapshot], so logout clears it) and revalidates with
  /// If-None-Match. On failure returns the stored body with `fresh: false`.
  static Future<({dynamic data, DateTime savedAt, bool fresh})> sendCached(
    String path, {
    Map<String, String>? query,
    void Function(dynamic data, DateTime savedAt)? onStored,
  }) async {
    final uri = _buildUri(path, query);
    final resource = 'http_cache:${uri.path}?${uri.query}';
    final stored = await OfflineSnapshot.load(resource);
    final blob = stored?.data;
    final etag = blob is Map ? blob['etag']?.toString() : null;
    final hasBody = blob is Map && blob.containsKey('body');
    if (hasBody && onStored != null) onStored(blob['body'], stored!.savedAt);
    try {
      final res = await _getWithRetry(
        uri,
        extraHeaders: (etag != null && etag.isNotEmpty && hasBody)
            ? {'If-None-Match': etag}
            : null,
      );
      if (res.statusCode == 304 && hasBody) {
        final now = DateTime.now();
        await OfflineSnapshot.save(resource, blob);
        return (data: blob['body'], savedAt: now, fresh: true);
      }
      final data = _decode(res);
      final newTag = res.headers['etag'];
      if (newTag != null && newTag.isNotEmpty) {
        await OfflineSnapshot.save(resource, {'etag': newTag, 'body': data});
      }
      return (data: data, savedAt: DateTime.now(), fresh: true);
    } on EmsException catch (e) {
      // 401/403 mean the session/permission changed: never mask with old data.
      if (e.statusCode == 401 || e.statusCode == 403 || !hasBody) rethrow;
      return (data: blob['body'], savedAt: stored!.savedAt, fresh: false);
    }
  }

  /// [send] typed for endpoints that answer with a JSON object. Shared by the
  /// per-domain API files in `lib/data/api/`.
  static Future<Map<String, dynamic>> sendMap(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    return (await send(method, path, body: body, auth: auth))
        as Map<String, dynamic>;
  }
}
