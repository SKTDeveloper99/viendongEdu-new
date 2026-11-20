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
    final identity = EmsApiService.parse(
      () => CrmIdentity.fromStudentLogin(body),
    );
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
    final identity = EmsApiService.parse(
      () => CrmIdentity.fromTeacherLogin(body),
    );
    if (identity.token.isEmpty) {
      throw EmsException('Máy chủ không cấp được phiên đăng nhập.');
    }
    return identity;
  }

  /// `POST /auth/app/login {login, password, fcm_token?, platform?}` — any
  /// active Viva account: Viva username (office) or mã GV (Overlord slice).
  static Future<CrmIdentity> appLogin(
    String login,
    String password, {
    String? fcmToken,
    String? platform,
  }) async {
    final body = await EmsApiService.sendMap(
      'POST',
      '/auth/app/login',
      body: {
        'login': login,
        'password': password,
        'fcm_token': ?fcmToken,
        'platform': ?platform,
      },
      auth: false,
    );
    final identity = EmsApiService.parse(() => CrmIdentity.fromAppLogin(body));
    if (identity.token.isEmpty) {
      throw EmsException('Máy chủ không cấp được phiên đăng nhập.');
    }
    return identity;
  }

  /// Học viên quên mật khẩu: `POST /auth/student/forgot-password
  /// {mssv, date_of_birth?}` (LAW P-51, đề xuất). Đúng thì máy chủ đặt lại
  /// mật khẩu thành MSSV và bắt đổi ở lần đăng nhập sau; trả về câu báo của
  /// máy chủ. Sai thì [EmsException] mang đúng một câu chung cho mọi trường hợp.
  /// [dateOfBirth] dạng YYYY-MM-DD; null khi màn hình không hỏi ngày sinh.
  static Future<String> forgotStudentPassword(
    String mssv, {
    String? dateOfBirth,
  }) async {
    final body = await EmsApiService.sendMap(
      'POST',
      '/auth/student/forgot-password',
      body: {'mssv': mssv, 'date_of_birth': ?dateOfBirth},
      auth: false,
    );
    final message = body['message']?.toString() ?? '';
    return message.isNotEmpty
        ? message
        : 'Đã đặt lại mật khẩu. Hãy đăng nhập bằng mã số sinh viên.';
  }

  /// Đổi mật khẩu bắt buộc/tự chọn của học viên.
  /// `POST /student/me/password {current_password, new_password}`.
  static Future<void> changeStudentPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // The server answers a wrong current password with 401 ("Mật khẩu hiện
    // tại không đúng."). That is this form's own refusal, not an ended
    // session: without this the student was signed out for a typing slip.
    try {
      final data = await EmsApiService.send(
        'POST',
        '/student/me/password',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        expireOn401: false,
      );
      EmsApiService.parse(() => data as Map<String, dynamic>);
    } on EmsException catch (e) {
      // A session the server itself ended (its text starts "Phiên đăng nhập")
      // still signs the student out.
      if (e.statusCode == 401 && e.message.startsWith('Phiên đăng nhập')) {
        EmsApiService.onUnauthorized?.call(e);
      }
      rethrow;
    }
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
    // A 401 here means "Mật khẩu hiện tại không đúng", not an ended session.
    final data = await EmsApiService.send(
      'POST',
      '/auth/change-password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
      expireOn401: false,
    );
    final r = EmsApiService.parse(() => data as Map<String, dynamic>);
    final token = r['token'];
    return token is String && token.isNotEmpty ? token : null;
  }
}
