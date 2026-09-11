import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hoc_vien_model.dart';
import '../models/giang_vien_model.dart';
import 'api_service.dart';
import 'ems_api_service.dart';
import 'notification_service.dart';

/// Singleton giữ trạng thái đăng nhập trong toàn app.
class AppSession {
  AppSession._();
  static final AppSession instance = AppSession._();

  String? token;
  String? userid;
  HocVien? hocVien;
  GiangVien? giangVien;

  /// Token của EMS (CRM). CỐ TÌNH tách khỏi [token] của IMS: hai hệ thống,
  /// hai vòng đời. Không bao giờ ghi đè lên `auth_token`, vì mất token IMS là
  /// mất toàn bộ app, còn mất token EMS chỉ mất Bảng tin.
  String? emsToken;

  /// EMS đã từ chối có chủ đích (tài khoản bị khoá / chưa được tạo).
  /// Khi bật, app ngừng thử đối chiếu lại — chỉ tắt riêng tính năng EMS.
  bool emsDenied = false;

  bool get hasEms => emsToken != null && emsToken!.isNotEmpty;

  bool get isGiangVien => giangVien != null && hocVien == null;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

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
  }

  /// Khôi phục session khi mở lại app
  Future<bool> tryRestore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    if (savedToken == null || savedToken.isEmpty) return false;

    token = savedToken;
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
    return true;
  }

  /// Xóa session khi đăng xuất
  Future<void> clear() async {
    // Xóa FCM token trước khi clear session
    // Phải khớp tiền tố dùng lúc đăng ký ('hv_' / 'gv_'), nếu không server
    // không tìm thấy bản ghi và thiết bị vẫn nhận notification sau khi logout
    final id = hocVien != null
        ? 'hv_${hocVien!.id}'
        : (giangVien != null ? 'gv_${giangVien!.id}' : null);
    if (id != null) {
      await NotificationService.instance.unregisterToken(id);
    }
    token = null;
    userid = null;
    emsToken = null;
    emsDenied = false;
    hocVien = null;
    giangVien = null;
    ApiService.clearCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('ems_token');
    await prefs.remove('userid');
    await prefs.remove('user_type');
    await prefs.remove('user_data');
  }

  /// Đối chiếu phiên IMS hiện tại sang EMS và lưu token EMS.
  ///
  /// KHÔNG BAO GIỜ ném lỗi ra ngoài: EMS hỏng thì màn hình IMS vẫn phải vào
  /// được. Trả về true nếu lấy được token.
  ///
  /// 403 `account_deactivated` và 404 `not_provisioned` là câu trả lời DỨT
  /// KHOÁT của EMS — đánh dấu [emsDenied] để không thử lại thành bão request.
  Future<bool> refreshEmsToken() async {
    final imsToken = token;
    if (imsToken == null || imsToken.isEmpty) return false;
    if (emsDenied) return false;

    try {
      final gv = giangVien;
      emsToken = gv != null
          ? await EmsApiService.mirrorTeacher(imsToken)
          : await EmsApiService.mirrorStudent(imsToken);
      await persist();
      return true;
    } on EmsException catch (e) {
      if (e.isDeliberateDenial) emsDenied = true;
      emsToken = null;
      return false;
    } catch (_) {
      emsToken = null;
      return false;
    }
  }
}
