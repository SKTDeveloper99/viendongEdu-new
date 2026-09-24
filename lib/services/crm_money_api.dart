import 'ems_api_service.dart';
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
  static Future<CrmTuitionResponse> getTuition() async {
    final body = await EmsApiService.send('GET', '/student/me/tuition');
    return CrmTuitionResponse.fromJson(body as Map<String, dynamic>);
  }

  /// `GET /api/student/me/cong-no` → sổ công nợ IMS sống, nguồn RIÊNG với
  /// [getTuition] — không gộp hai bên.
  static Future<CrmCongNo> getCongNo() async {
    final body = await EmsApiService.send('GET', '/student/me/cong-no');
    return CrmCongNo.fromJson(body as Map<String, dynamic>);
  }

  /// `GET /api/student/me/fees` → lệ phí/miễn giảm/hoàn phí (không phải học
  /// phí), thay `ApiService.getLePhi`.
  static Future<CrmFeesResponse> getFees() async {
    final body = await EmsApiService.send('GET', '/student/me/fees');
    return CrmFeesResponse.fromJson(body as Map<String, dynamic>);
  }

  /// `GET /api/student/me/capbu` → hóa đơn cấp bù, mirror IMS nguyên văn,
  /// thay `ApiService.getCapBu`.
  static Future<CrmCapBuResponse> getCapBu() async {
    final body = await EmsApiService.send('GET', '/student/me/capbu');
    return CrmCapBuResponse.fromJson(body as Map<String, dynamic>);
  }
}
