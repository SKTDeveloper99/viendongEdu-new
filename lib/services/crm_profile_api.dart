import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_session.dart';
import 'ems_api_service.dart';
import '../models/crm_profile_models.dart';

/// Sửa hồ sơ cá nhân — thay cho `ApiService.updateUserInfo` (IMS
/// `user/info/update`). Xem `docs/api/mobile-ims-replacement-S5.md` §2.
///
/// Mọi câu trả lời sửa hồ sơ mang `recorded_in: 'ems', synced_to_ims:
/// false` — ghi vào CRM, CHƯA gửi lên IMS. Màn hình gọi hàm này phải nói rõ
/// điều đó cho người dùng, không giấu.
///
/// `EmsApiService.send()` chỉ hỗ trợ GET/POST/DELETE (không có PATCH) và
/// đây là file KHÔNG được sửa `ems_api_service.dart` — hai route hồ sơ ở
/// đây là `router.patch(...)` thật sự trên máy chủ (không phải POST), nên
/// [_patch] tự gọi `EmsApiService.client.patch` (client đã có thể thay được
/// trong test, giống mọi service EMS khác) và tự dựng lỗi giống
/// [EmsException] cho nơi gọi bắt như bình thường.
class CrmProfileApi {
  static const Duration _timeout = Duration(seconds: 15);

  static Map<String, String> _headers() {
    final h = <String, String>{'Content-Type': 'application/json'};
    final t = AppSession.instance.emsToken;
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    return h;
  }

  static Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${EmsApiService.baseUrl}$path');
    http.Response res;
    try {
      res = await EmsApiService.client
          .patch(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);
    } catch (_) {
      throw EmsException('Không cập nhật được hồ sơ. Vui lòng thử lại.');
    }

    Map<String, dynamic>? decoded;
    try {
      final d = jsonDecode(res.body);
      if (d is Map<String, dynamic>) decoded = d;
    } catch (_) {
      decoded = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded == null) {
        throw EmsException(
          'Máy chủ trả về dữ liệu không đọc được.',
          statusCode: res.statusCode,
        );
      }
      return decoded;
    }

    final rawError = decoded?['error']?.toString();
    final rawMessage = decoded?['message']?.toString();
    throw EmsException(
      rawMessage ?? rawError ?? 'Không kết nối được máy chủ thông tin.',
      code: rawError,
      statusCode: res.statusCode,
    );
  }

  /// `GET /api/student/me` — điền sẵn form. Không có `cccd`/`cmnd` ở endpoint
  /// này (xem [CrmStudentProfile.fromGetMeJson]).
  static Future<CrmStudentProfile> getStudentMe() async {
    final body = await EmsApiService.send('GET', '/student/me');
    return CrmStudentProfile.fromGetMeJson(body as Map<String, dynamic>);
  }

  /// `GET /api/teacher/me` — điền sẵn form.
  static Future<CrmTeacherProfile> getTeacherMe() async {
    final body = await EmsApiService.send('GET', '/teacher/me');
    return CrmTeacherProfile.fromGetMeJson(body as Map<String, dynamic>);
  }

  /// `PATCH /api/student/me/profile {email?, sdt?, cmnd?}`. Chỉ gửi trường
  /// nào có giá trị — server chỉ cập nhật trường có mặt trong body. Thông
  /// điệp lỗi validate (email/sdt/cmnd sai định dạng) là NGUYÊN VĂN của
  /// server, không tự dịch lại ở app.
  static Future<CrmStudentProfile> updateStudentProfile({
    String? email,
    String? sdt,
    String? cmnd,
  }) async {
    final body = <String, dynamic>{
      if (email != null && email.isNotEmpty) 'email': email,
      if (sdt != null && sdt.isNotEmpty) 'sdt': sdt,
      if (cmnd != null && cmnd.isNotEmpty) 'cmnd': cmnd,
    };
    final res = await _patch('/student/me/profile', body);
    return CrmStudentProfile.fromPatchJson(res);
  }

  /// `PATCH /api/teacher/me/profile {email?, sdt?}`.
  static Future<CrmTeacherProfile> updateTeacherProfile({
    String? email,
    String? sdt,
  }) async {
    final body = <String, dynamic>{
      if (email != null && email.isNotEmpty) 'email': email,
      if (sdt != null && sdt.isNotEmpty) 'sdt': sdt,
    };
    final res = await _patch('/teacher/me/profile', body);
    return CrmTeacherProfile.fromPatchJson(res);
  }
}
