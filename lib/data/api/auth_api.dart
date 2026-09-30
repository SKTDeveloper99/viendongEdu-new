import '../../models/crm_identity.dart';
import '../../services/ems_api_service.dart';

abstract final class AuthApi {
  // ── Đăng nhập CRM ───────────────────────────────────────────────────────────
  // Không còn token IMS trung gian: học viên/giảng viên đăng nhập THẲNG vào
  // EMS bằng tài khoản EMS. Các endpoint này không cần Bearer (chưa có token).

  /// `POST /auth/student/login {mssv, password}`.
  /// Mật khẩu mặc định là MSSV (quyết định của chủ trường).
  static Future<CrmIdentity> studentLogin(String mssv, String password) async {
    final body = await EmsApiService.sendMap(
      'POST',
      '/auth/student/login',
      body: {'mssv': mssv, 'password': password},
      auth: false,
    );
    final identity = CrmIdentity.fromStudentLogin(body);
    if (identity.token.isEmpty) {
      throw EmsException('Máy chủ không cấp được phiên đăng nhập.');
    }
    return identity;
  }

  /// `POST /auth/teacher/login {teacher_code, password, fcm_token?, platform?}`.
  /// Mật khẩu mặc định là mã giáo viên.
  static Future<CrmIdentity> teacherLogin(
    String teacherCode,
    String password, {
    String? fcmToken,
    String? platform,
  }) async {
    final body = await EmsApiService.sendMap(
      'POST',
      '/auth/teacher/login',
      body: {
        'teacher_code': teacherCode,
        'password': password,
        'fcm_token': ?fcmToken,
        'platform': ?platform,
      },
      auth: false,
    );
    final identity = CrmIdentity.fromTeacherLogin(body);
    if (identity.token.isEmpty) {
      throw EmsException('Máy chủ không cấp được phiên đăng nhập.');
    }
    return identity;
  }

  /// Đổi mật khẩu bắt buộc/tự chọn của học viên.
  /// `POST /student/me/password {current_password, new_password}`.
  static Future<void> changeStudentPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await EmsApiService.sendMap(
      'POST',
      '/student/me/password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  /// Đổi mật khẩu của giảng viên (và mọi staff khác dùng chung route này).
  /// `POST /auth/change-password {current_password, new_password}`.
  ///
  /// Trả về token MỚI server cấp (không còn cờ must_change_password). Token
  /// cũ vẫn mang cờ đó nên mọi `/teacher/*` bị 403 — người gọi PHẢI thay
  /// token trong session (sự cố thử tải 2026-09-30).
  static Future<String?> changeTeacherPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final r = await EmsApiService.sendMap(
      'POST',
      '/auth/change-password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
    final token = r['token'];
    return token is String && token.isNotEmpty ? token : null;
  }
}
