import 'ems_api_service.dart';
import '../models/crm_profile_models.dart';

/// Sửa hồ sơ cá nhân — thay cho `ApiService.updateUserInfo` (IMS
/// `user/info/update`). Xem `docs/api/mobile-ims-replacement-S5.md` §2.
///
/// Mọi câu trả lời sửa hồ sơ mang `recorded_in: 'ems', synced_to_ims:
/// false` — ghi vào CRM, CHƯA gửi lên IMS. Màn hình gọi hàm này phải nói rõ
/// điều đó cho người dùng, không giấu.
///
/// Đi qua [EmsApiService.send] (nay hỗ trợ PATCH) như mọi service EMS khác —
/// không tự mở `http.Client`/tự dựng lỗi nữa (bot A5, 2026-09-25: gỡ workaround
/// `_patch` cũ, từ khi `send()`/`_decode()` chưa hỗ trợ PATCH).
class CrmProfileApi {
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
    final res = await EmsApiService.send('PATCH', '/student/me/profile', body: body)
        as Map<String, dynamic>;
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
    final res = await EmsApiService.send('PATCH', '/teacher/me/profile', body: body)
        as Map<String, dynamic>;
    return CrmTeacherProfile.fromPatchJson(res);
  }
}
