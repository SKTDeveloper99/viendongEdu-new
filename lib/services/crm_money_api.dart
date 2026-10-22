import 'app_session.dart';
import 'ems_api_service.dart';
import 'offline_snapshot.dart';
import '../models/crm_money_tuition.dart';
import '../models/crm_money_fees.dart';
import '../models/crm_money_capbu.dart';

/// Học phí / lệ phí / cấp bù — thay cho `ApiService.getTuition/getLePhi/
/// getCapBu` (IMS). Mọi hàm ở đây đi qua [EmsApiService.send]; không tự viết
/// http.get/post riêng.
///
/// LUẬT TIỀN (CLAUDE.md, nhắc lại ở đây vì đây là nơi màn hình đọc số):
/// hiển thị NGUYÊN VĂN số máy chủ trả — không cộng/trừ/gộp/suy luận trên
/// điện thoại. "chưa có luật" hiện đúng như vậy, không bao giờ hiện 0.
class CrmMoneyApi {
  /// `GET /api/student/me/tuition` → tổng học phí đã áp luật thu sẵn.
  /// Mất mạng thì trả bản tốt gần nhất đã lưu trên máy (kèm giờ lưu);
  /// lỗi đăng nhập (401) vẫn ném ra để màn hình đưa về trang đăng nhập.
  static Future<CrmTuitionResponse> getTuition() async {
    final token = AppSession.instance.emsToken;
    void checkSession() {
      if (token != AppSession.instance.emsToken) {
        throw EmsException('Phiên đăng nhập đã thay đổi.', statusCode: 403);
      }
    }

    try {
      final body = await EmsApiService.sendMap('GET', '/student/me/tuition');
      final result = EmsApiService.parse(
        () => CrmTuitionResponse.fromJson(body),
      );
      checkSession();
      await OfflineSnapshot.save('student_tuition', body);
      checkSession();
      return result;
    } catch (e) {
      checkSession();
      if (e is EmsException && (e.statusCode == 401 || e.statusCode == 403)) {
        await OfflineSnapshot.remove('student_tuition');
        rethrow;
      }
      final saved = await OfflineSnapshot.load('student_tuition');
      checkSession();
      if (saved == null || saved.data is! Map<String, dynamic>) rethrow;
      return EmsApiService.parse(
        () => CrmTuitionResponse.fromJson(saved.data),
      ).withOfflineSavedAt(saved.savedAt);
    }
  }

  /// `GET /api/student/me/cong-no` → sổ công nợ IMS sống, nguồn RIÊNG với
  /// [getTuition] — không gộp hai bên.
  static Future<CrmCongNo> getCongNo() async {
    final body = await EmsApiService.sendMap('GET', '/student/me/cong-no');
    return EmsApiService.parse(() => CrmCongNo.fromJson(body));
  }

  /// `GET /api/student/me/fees` → lệ phí/miễn giảm/hoàn phí (không phải học
  /// phí), thay `ApiService.getLePhi`.
  static Future<CrmFeesResponse> getFees() async {
    final body = await EmsApiService.sendMap('GET', '/student/me/fees');
    return EmsApiService.parse(() => CrmFeesResponse.fromJson(body));
  }

  /// `GET /api/student/me/capbu` → hóa đơn cấp bù, mirror IMS nguyên văn,
  /// thay `ApiService.getCapBu`.
  static Future<CrmCapBuResponse> getCapBu() async {
    final body = await EmsApiService.sendMap('GET', '/student/me/capbu');
    return EmsApiService.parse(() => CrmCapBuResponse.fromJson(body));
  }
}
