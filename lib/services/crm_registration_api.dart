import 'ems_api_service.dart';
import '../models/crm_registration_models.dart';

/// Đăng ký môn học — thay cho `ApiService.getDotDangKy/getMonHocDuKien/
/// getKetQuaDangKy/postDangKyMon/deleteDangKyMon` (IMS).
///
/// Đọc: `docs/api/mobile-ims-replacement-S3.md`. Ghi: `.../S5.md`.
/// `offering_id` = `ims_snapshot.tbl_qldt_tkb_lopmonhoc.id` — không phải
/// `mhid` (monhocid) IMS cũ.
class CrmRegistrationApi {
  /// `GET /api/student/me/registration/periods?semester=`.
  /// [semester] bỏ trống = học kỳ hiện tại (máy chủ tự chọn).
  static Future<List<CrmRegistrationPeriod>> getPeriods({String? semester}) async {
    final body = await EmsApiService.send(
      'GET',
      '/student/me/registration/periods',
      query: (semester == null || semester.isEmpty) ? null : {'semester': semester},
    ) as Map<String, dynamic>;
    final list = body['periods'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CrmRegistrationPeriod.fromJson)
        .toList();
  }

  /// `GET /api/student/me/registration/offerings?period_id=&scope=`.
  ///
  /// Mặc định (không truyền [allSections]) server chỉ trả các lớp THUỘC
  /// chương trình học của chính học viên và học viên CHƯA đạt — mỗi dòng
  /// mang `in_my_curriculum`. Khi server không lọc được theo chương trình,
  /// nó trả `curriculum_resolved: false` cùng TOÀN BỘ danh sách (không lọc)
  /// — [CrmRegistrationOfferingsPage.curriculumResolved] mang cờ đó cho màn
  /// hình quyết định hiện cảnh báo. [allSections] = `true` gọi
  /// `scope=all` (nút "Xem tất cả lớp") — trả mọi lớp mở, không lọc theo
  /// chương trình, dùng khi học viên muốn tự tìm ngoài chương trình của mình.
  static Future<CrmRegistrationOfferingsPage> getOfferings({
    required String periodId,
    bool allSections = false,
  }) async {
    final body = await EmsApiService.send(
      'GET',
      '/student/me/registration/offerings',
      query: {
        'period_id': periodId,
        if (allSections) 'scope': 'all',
      },
    ) as Map<String, dynamic>;
    return CrmRegistrationOfferingsPage.fromJson(body);
  }

  /// `GET /api/student/me/registration/results?semester=`. [semester] bỏ
  /// trống trả về TOÀN BỘ lịch sử (không lọc theo học kỳ) — truyền
  /// [semester] để giới hạn về một học kỳ. Trả về cả kết quả gửi qua EMS
  /// (`source: 'ems_request'`) lẫn đã lên danh sách lớp IMS (`source:
  /// 'ims_roster'`) — màn hình phải hiện cả hai, có nhãn.
  static Future<List<CrmRegistrationResult>> getResults({String? semester}) async {
    final body = await EmsApiService.send(
      'GET',
      '/student/me/registration/results',
      query: (semester == null || semester.isEmpty) ? null : {'semester': semester},
    ) as Map<String, dynamic>;
    final list = body['results'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CrmRegistrationResult.fromJson)
        .toList();
  }

  /// `POST /api/student/me/registration {offering_id}`. Ném [EmsException]
  /// nguyên văn thông điệp máy chủ khi đợt đã đóng / lớp đầy / đã đăng ký —
  /// màn hình hiện đúng câu đó, không tự diễn giải lại.
  static Future<CrmRegistrationRequestResult> register(String offeringId) async {
    final body = await EmsApiService.send(
      'POST',
      '/student/me/registration',
      body: {'offering_id': offeringId},
    ) as Map<String, dynamic>;
    return CrmRegistrationRequestResult.fromJson(body);
  }

  /// `DELETE /api/student/me/registration/:id`.
  static Future<CrmRegistrationCancelResult> cancel(String id) async {
    final body = await EmsApiService.send(
      'DELETE',
      '/student/me/registration/$id',
    ) as Map<String, dynamic>;
    return CrmRegistrationCancelResult.fromJson(body);
  }
}
