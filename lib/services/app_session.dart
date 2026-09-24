import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crm_identity.dart';
import '../models/hoc_vien_model.dart';
import '../models/giang_vien_model.dart';
import 'api_service.dart';
import 'ems_api_service.dart';
import 'notification_service.dart';

/// Singleton giữ trạng thái đăng nhập trong toàn app.
///
/// CRM (EMS) giờ là danh tính CHÍNH — [identity]/[emsToken] là điều kiện để
/// coi là đã đăng nhập. [token]/[userid]/[hocVien]/[giangVien] là tàn dư của
/// IMS: vẫn tồn tại vì một số màn hình (sóng 2) còn gọi [ApiService], nhưng
/// từ 6.1.0 không có màn hình đăng nhập nào ghi vào chúng nữa.
class AppSession {
  AppSession._();
  static final AppSession instance = AppSession._();

  // ── IMS (tàn dư — sóng 2 sẽ gỡ) ────────────────────────────────────────────
  String? token;
  String? userid;
  HocVien? hocVien;
  GiangVien? giangVien;

  // ── CRM / EMS — danh tính đăng nhập chính ──────────────────────────────────

  /// Token Bearer của CRM. Tên giữ nguyên 'emsToken' (không đổi thành
  /// 'crmToken') vì đã được dùng khắp app (EmsApiService.authHeaders, ảnh,
  /// v.v.) — đổi tên sẽ là một lượt sửa không cần thiết.
  String? emsToken;

  CrmRole? role;
  String? mssv;
  String? teacherId;
  String? teacherCode;
  String? fullName;
  bool mustChangePassword = false;

  /// EMS đã từ chối có chủ đích (tài khoản bị khoá / chưa được tạo).
  bool emsDenied = false;

  bool get hasEms => emsToken != null && emsToken!.isNotEmpty;

  bool get isGiangVien => role == CrmRole.teacher;

  /// Đã đăng nhập = có một danh tính CRM hợp lệ. (Token IMS không còn cấp
  /// quyền vào app kể từ 6.1.0 — xem [login_screen.dart].)
  bool get isLoggedIn => hasEms;

  /// Danh tính CRM hiện tại, dựng từ các trường rời ở trên. Trả `null` khi
  /// chưa đăng nhập.
  CrmIdentity? get identity {
    final t = emsToken;
    final r = role;
    if (t == null || t.isEmpty || r == null) return null;
    return CrmIdentity(
      role: r,
      token: t,
      mssv: mssv,
      teacherId: teacherId,
      teacherCode: teacherCode,
      fullName: fullName ?? '',
      mustChangePassword: mustChangePassword,
    );
  }

  /// Áp danh tính vừa đăng nhập/đổi mật khẩu vào session hiện tại.
  void applyIdentity(CrmIdentity id) {
    emsToken = id.token;
    role = id.role;
    mssv = id.mssv;
    teacherId = id.teacherId;
    teacherCode = id.teacherCode;
    fullName = id.fullName;
    mustChangePassword = id.mustChangePassword;
    emsDenied = false;
  }

  /// Lưu toàn bộ session vào SharedPreferences
  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) await prefs.setString('auth_token', token!);
    if (userid != null) await prefs.setString('userid', userid!);
    if (emsToken != null && emsToken!.isNotEmpty) {
      await prefs.setString('ems_token', emsToken!);
    } else {
      await prefs.remove('ems_token');
    }
    if (giangVien != null) {
      await prefs.setString('user_type', 'gv');
      await prefs.setString('user_data', jsonEncode(giangVien!.toJson()));
    } else if (hocVien != null) {
      await prefs.setString('user_type', 'hv');
      await prefs.setString('user_data', jsonEncode(hocVien!.toJson()));
    }
    final id = identity;
    if (id != null) {
      await prefs.setString('crm_identity', jsonEncode(id.toPrefsJson()));
    } else {
      await prefs.remove('crm_identity');
    }
  }

  /// Khôi phục session khi mở lại app.
  ///
  /// Đăng nhập hợp lệ bây giờ nghĩa là có [emsToken] + [role] — KHÔNG phải có
  /// token IMS (không còn được cấp từ 6.1.0). Một bản cài đặt cũ khôi phục
  /// một token IMS trơ trọi (không có 'crm_identity') bị coi là CHƯA đăng
  /// nhập: nó không cầm được API nào của CRM.
  Future<bool> tryRestore() async {
    final prefs = await SharedPreferences.getInstance();

    token = prefs.getString('auth_token');
    userid = prefs.getString('userid');
    emsToken = prefs.getString('ems_token');
    emsDenied = false;

    final userType = prefs.getString('user_type');
    final userDataStr = prefs.getString('user_data');
    if (userType != null && userDataStr != null) {
      try {
        final json = jsonDecode(userDataStr) as Map<String, dynamic>;
        if (userType == 'gv') {
          giangVien = GiangVien.fromJson(json);
          hocVien = null;
        } else {
          hocVien = HocVien.fromJson(json);
          giangVien = null;
        }
      } catch (_) {}
    }

    final identityStr = prefs.getString('crm_identity');
    Map<String, dynamic>? identityJson;
    if (identityStr != null) {
      try {
        identityJson = jsonDecode(identityStr) as Map<String, dynamic>;
      } catch (_) {}
    }
    final id = CrmIdentity.fromPrefsJson(identityJson, emsToken);
    if (id == null) {
      // Không có danh tính CRM đầy đủ — dọn nốt token IMS mồ côi để
      // isLoggedIn/persist không mâu thuẫn nhau ở lần lưu kế tiếp.
      role = null;
      mssv = null;
      teacherId = null;
      teacherCode = null;
      fullName = null;
      mustChangePassword = false;
      return false;
    }
    role = id.role;
    mssv = id.mssv;
    teacherId = id.teacherId;
    teacherCode = id.teacherCode;
    fullName = id.fullName;
    mustChangePassword = id.mustChangePassword;
    return true;
  }

  /// Xóa session khi đăng xuất, hoặc khi EMS trả 401 (phiên hết hạn).
  Future<void> clear() async {
    // Xóa FCM token trước khi clear session.
    final id = identity?.notificationId;
    if (id != null && id.isNotEmpty) {
      await NotificationService.instance.unregisterToken(id);
    }
    token = null;
    userid = null;
    emsToken = null;
    emsDenied = false;
    hocVien = null;
    giangVien = null;
    role = null;
    mssv = null;
    teacherId = null;
    teacherCode = null;
    fullName = null;
    mustChangePassword = false;
    ApiService.clearCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('ems_token');
    await prefs.remove('userid');
    await prefs.remove('user_type');
    await prefs.remove('user_data');
    await prefs.remove('crm_identity');
  }

  /// Tàn dư tương thích cho các màn hình sóng 2 chưa được sửa
  /// ([splash_screen.dart] gọi khi khôi phục phiên cũ chưa có token EMS,
  /// [schedule_screen.dart]/[gv_schedule_screen.dart] gọi khi kéo-để-làm-mới).
  ///
  /// TRƯỚC: đối chiếu token IMS lấy token EMS mới (identity mirror).
  /// NAY: không còn token IMS để đối chiếu — trả thẳng [hasEms]. Một 401 thật
  /// sự (phiên EMS hết hạn) phải được xử lý ở nơi gọi bằng cách bắt
  /// `EmsException(statusCode: 401)`, gọi [clear] rồi điều hướng về
  /// '/login' — không có cách nào "làm mới" một token đã hết hạn nữa vì
  /// không còn phiên IMS đứng sau nó.
  Future<bool> refreshEmsToken({bool force = false}) async {
    if (force) emsDenied = false;
    return hasEms;
  }

  Future<void> registerStudentDeviceToken(String fcmToken) async {
    if (role != CrmRole.student || !hasEms) return;
    await EmsApiService.registerStudentDevice(
      fcmToken,
      platform: defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : defaultTargetPlatform == TargetPlatform.android
          ? 'android'
          : 'web',
    );
  }

  Future<void> revokeStudentDeviceToken(String fcmToken) async {
    if (role != CrmRole.student || !hasEms) return;
    await EmsApiService.revokeStudentDevice(fcmToken);
  }
}
