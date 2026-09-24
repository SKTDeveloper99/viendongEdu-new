/// Đăng ký môn học — `GET/POST/DELETE /api/student/me/registration*`.
///
/// `offering_id` = `ims_snapshot.tbl_qldt_tkb_lopmonhoc.id` (LMH) theo tài
/// liệu S5 (`docs/api/mobile-ims-replacement-S5.md`) — KHÔNG phải `mhid` IMS
/// cũ (`monhocid`) mà app cũ dùng.
library;

int? _numOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

String? _strOrNull(dynamic v) {
  final s = v?.toString();
  if (s == null || s.isEmpty) return null;
  return s;
}

/// Một đợt đăng ký (`GET .../registration/periods`).
class CrmRegistrationPeriod {
  final String? periodId;
  final String? periodCode;
  final String? periodName;
  final String? note;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isOpen;
  final String? semesterCode;
  final String? semesterName;

  const CrmRegistrationPeriod({
    this.periodId,
    this.periodCode,
    this.periodName,
    this.note,
    this.startAt,
    this.endAt,
    this.isOpen = false,
    this.semesterCode,
    this.semesterName,
  });

  factory CrmRegistrationPeriod.fromJson(Map<String, dynamic> j) =>
      CrmRegistrationPeriod(
        periodId: _strOrNull(j['period_id']),
        periodCode: _strOrNull(j['period_code']),
        periodName: _strOrNull(j['period_name']),
        note: _strOrNull(j['note']),
        startAt: DateTime.tryParse(j['start_at']?.toString() ?? '')?.toLocal(),
        endAt: DateTime.tryParse(j['end_at']?.toString() ?? '')?.toLocal(),
        // Máy chủ đã tính is_open (now() giữa start_at/end_at) — app KHÔNG
        // tự tính lại từ hai mốc thời gian như bản IMS cũ.
        isOpen: j['is_open'] == true,
        semesterCode: _strOrNull(j['semester_code']),
        semesterName: _strOrNull(j['semester_name']),
      );
}

/// Một lớp môn học mở đăng ký (`GET .../registration/offerings`).
///
/// [inMyCurriculum]: server đánh dấu lớp có thuộc chương trình học của
/// chính học viên và CHƯA đạt hay không. Khi [CrmRegistrationOfferingsPage.
/// curriculumResolved] là `false`, server không lọc được theo chương trình
/// (trả nguyên danh sách) nên trường này không đáng tin — app không được tự
/// suy diễn "trong chương trình" trong trường hợp đó.
class CrmRegistrationOffering {
  final String offeringId;
  final String? classCode;
  final String? subjectId;
  final String? subjectCode;
  final String? subjectName;
  final int? credits;
  final int? creditsLt;
  final int? creditsTh;
  final String? teacherName;
  final String? facilityName;
  final int? maxSize;
  final int? registeredCount;
  final bool? inMyCurriculum;

  const CrmRegistrationOffering({
    required this.offeringId,
    this.classCode,
    this.subjectId,
    this.subjectCode,
    this.subjectName,
    this.credits,
    this.creditsLt,
    this.creditsTh,
    this.teacherName,
    this.facilityName,
    this.maxSize,
    this.registeredCount,
    this.inMyCurriculum,
  });

  factory CrmRegistrationOffering.fromJson(Map<String, dynamic> j) =>
      CrmRegistrationOffering(
        offeringId: _strOrNull(j['offering_id']) ?? '',
        classCode: _strOrNull(j['class_code']),
        subjectId: _strOrNull(j['subject_id']),
        subjectCode: _strOrNull(j['subject_code']),
        subjectName: _strOrNull(j['subject_name']),
        credits: _numOrNull(j['credits']),
        creditsLt: _numOrNull(j['credits_lt']),
        creditsTh: _numOrNull(j['credits_th']),
        teacherName: _strOrNull(j['teacher_name']),
        facilityName: _strOrNull(j['facility_name']),
        maxSize: _numOrNull(j['max_size']),
        registeredCount: _numOrNull(j['registered_count']),
        inMyCurriculum: j['in_my_curriculum'] as bool?,
      );
}

/// `GET .../registration/offerings` nguyên trang — bọc cả cờ
/// `curriculum_resolved` lẫn danh sách, vì ý nghĩa của [CrmRegistrationOffering
/// .inMyCurriculum] phụ thuộc vào cờ này.
///
/// `curriculum_resolved == false` nghĩa là server KHÔNG lọc được theo
/// chương trình của học viên (không rõ khung chương trình) và đã trả về
/// TOÀN BỘ danh sách thay vì lọc — app phải hiện rõ điều này, không được
/// ngầm hiểu "đây là danh sách đã lọc theo chương trình của tôi".
class CrmRegistrationOfferingsPage {
  final String? periodId;
  final String? semesterCode;
  final bool curriculumResolved;
  final List<CrmRegistrationOffering> offerings;

  const CrmRegistrationOfferingsPage({
    this.periodId,
    this.semesterCode,
    this.curriculumResolved = true,
    this.offerings = const [],
  });

  factory CrmRegistrationOfferingsPage.fromJson(Map<String, dynamic> j) {
    final list = j['offerings'];
    return CrmRegistrationOfferingsPage(
      periodId: _strOrNull(j['period_id']),
      semesterCode: _strOrNull(j['semester_code']),
      // Vắng field = coi như đã lọc được (hành vi cũ trước khi server có
      // cờ này) — chỉ khi server NÓI RÕ false mới hiện cảnh báo "chưa lọc".
      curriculumResolved: j['curriculum_resolved'] != false,
      offerings: (list is List)
          ? list
              .whereType<Map<String, dynamic>>()
              .map(CrmRegistrationOffering.fromJson)
              .toList()
          : const [],
    );
  }
}

/// Một dòng kết quả (`GET .../registration/results`) — hợp nhất từ hai
/// nguồn: `source == 'ems_request'` (học viên tự gửi qua app, chưa chắc đã
/// lên lớp) và `source == 'ims_roster'` (đã có tên trong danh sách lớp IMS).
/// Hai nhãn PHẢI hiện tách biệt cho học viên — không gộp mập mờ.
class CrmRegistrationResult {
  final String? id;
  final String? lmhId;
  final String? classCode;
  final String? subjectId;
  final String? subjectCode;
  final String? subjectName;
  final int? credits;
  final String? status;
  final String? offeringId;
  final DateTime? submittedAt;
  final String source; // 'ems_request' | 'ims_roster'
  final bool syncedToIms;

  const CrmRegistrationResult({
    this.id,
    this.lmhId,
    this.classCode,
    this.subjectId,
    this.subjectCode,
    this.subjectName,
    this.credits,
    this.status,
    this.offeringId,
    this.submittedAt,
    this.source = 'ims_roster',
    this.syncedToIms = false,
  });

  bool get isEmsRequest => source == 'ems_request';

  /// Nhãn tiếng Việt cho hai nguồn — trung thực, không giấu học viên việc
  /// đăng ký EMS chưa lên IMS.
  String get sourceLabel =>
      isEmsRequest ? 'Đã gửi (EMS)' : 'Đã xếp lớp';

  factory CrmRegistrationResult.fromJson(Map<String, dynamic> j) =>
      CrmRegistrationResult(
        id: _strOrNull(j['id']),
        lmhId: _strOrNull(j['lmh_id']),
        classCode: _strOrNull(j['class_code']),
        subjectId: _strOrNull(j['subject_id']),
        subjectCode: _strOrNull(j['subject_code']),
        subjectName: _strOrNull(j['subject_name']),
        credits: _numOrNull(j['credits']),
        status: _strOrNull(j['status']),
        offeringId: _strOrNull(j['offering_id']),
        submittedAt:
            DateTime.tryParse(j['submitted_at']?.toString() ?? '')?.toLocal(),
        source: _strOrNull(j['source']) ?? 'ims_roster',
        syncedToIms: j['synced_to_ims'] == true,
      );
}

/// Phản hồi `POST /api/student/me/registration` — bản ghi vừa tạo.
class CrmRegistrationRequestResult {
  final String recordedIn;
  final bool syncedToIms;
  final String? id;
  final String? mssv;
  final String? semesterCode;
  final String? offeringId;
  final String? status;
  final DateTime? submittedAt;

  const CrmRegistrationRequestResult({
    this.recordedIn = 'ems',
    this.syncedToIms = false,
    this.id,
    this.mssv,
    this.semesterCode,
    this.offeringId,
    this.status,
    this.submittedAt,
  });

  factory CrmRegistrationRequestResult.fromJson(Map<String, dynamic> j) =>
      CrmRegistrationRequestResult(
        recordedIn: _strOrNull(j['recorded_in']) ?? 'ems',
        syncedToIms: j['synced_to_ims'] == true,
        id: _strOrNull(j['id']),
        mssv: _strOrNull(j['mssv']),
        semesterCode: _strOrNull(j['semester_code']),
        offeringId: _strOrNull(j['offering_id']),
        status: _strOrNull(j['status']),
        submittedAt:
            DateTime.tryParse(j['submitted_at']?.toString() ?? '')?.toLocal(),
      );
}

/// Phản hồi `DELETE /api/student/me/registration/:id`.
class CrmRegistrationCancelResult {
  final bool alreadyWithdrawn;
  final String? id;
  final String? status;

  const CrmRegistrationCancelResult({
    this.alreadyWithdrawn = false,
    this.id,
    this.status,
  });

  factory CrmRegistrationCancelResult.fromJson(Map<String, dynamic> j) =>
      CrmRegistrationCancelResult(
        alreadyWithdrawn: j['already_withdrawn'] == true,
        id: _strOrNull(j['id']),
        status: _strOrNull(j['status']),
      );
}
