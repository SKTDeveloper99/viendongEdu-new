/// Mô hình cho `GET /api/teacher/me` và các trường `teacher` lồng trong
/// `GET /api/teacher/me/overview`.
///
/// Nguồn: `repositories/portals-teacher-portal-repo.js#getTeacherProfile` /
/// `#getOverviewTeacher` (bảng `teachers` của CRM). KHÔNG còn model
/// `GiangVien` (IMS) — từ 6.1.0 không màn hình nào ghi vào nó nữa nên nó
/// luôn null, xem `lib/services/app_session.dart`.
class CrmTeacherProfile {
  final String teacherId;
  final String? teacherCode;
  final String name;
  final String? email;
  final String? phone;

  /// 'gvch' | 'gvtg' | ... — `teachers.type` của CRM. `'gvch'` nghĩa là CƠ
  /// HỮU (không phải chủ nhiệm — xem CLAUDE.md "Known state").
  final String? type;
  final bool? isActive;
  final String? imsId;

  const CrmTeacherProfile({
    required this.teacherId,
    required this.name,
    this.teacherCode,
    this.email,
    this.phone,
    this.type,
    this.isActive,
    this.imsId,
  });

  bool get isCoHuu => type == 'gvch';

  factory CrmTeacherProfile.fromJson(Map<String, dynamic> j) =>
      CrmTeacherProfile(
        teacherId: j['teacher_id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        teacherCode: j['teacher_code']?.toString(),
        email: j['email']?.toString(),
        phone: j['phone']?.toString(),
        type: j['type']?.toString(),
        isActive: j['is_active'] as bool?,
        imsId: j['ims_id']?.toString(),
      );

  Map<String, dynamic> toJson() => {
    'teacher_id': teacherId,
    'name': name,
    'teacher_code': ?teacherCode,
    'email': ?email,
    'phone': ?phone,
    'type': ?type,
    'is_active': ?isActive,
    'ims_id': ?imsId,
  };
}

/// Một học kỳ — cùng hình dạng với `GET /api/teacher/me/semesters` (mirror
/// của IMS `GET /hocky`): `{id, ma, ten, ngaybatdau, ngayketthuc}`.
class CrmSemester {
  final int id;
  final String ma;
  final String ten;
  final String? ngayBatDau;
  final String? ngayKetThuc;

  const CrmSemester({
    required this.id,
    required this.ma,
    required this.ten,
    this.ngayBatDau,
    this.ngayKetThuc,
  });

  factory CrmSemester.fromJson(Map<String, dynamic> j) => CrmSemester(
    id: (j['id'] as num?)?.toInt() ?? int.tryParse('${j['id']}') ?? 0,
    ma: j['ma']?.toString() ?? '',
    ten: j['ten']?.toString() ?? '',
    ngayBatDau: j['ngaybatdau']?.toString(),
    ngayKetThuc: j['ngayketthuc']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ma': ma,
    'ten': ten,
    'ngaybatdau': ?ngayBatDau,
    'ngayketthuc': ?ngayKetThuc,
  };
}

/// Số liệu tổng hợp cho một học kỳ trong `GET /api/teacher/me/overview`.
class CrmTeacherSummary {
  final int sectionCount;
  final int studentCount;
  final int subjectCount;
  final int sessionCount;

  const CrmTeacherSummary({
    this.sectionCount = 0,
    this.studentCount = 0,
    this.subjectCount = 0,
    this.sessionCount = 0,
  });

  factory CrmTeacherSummary.fromJson(Map<String, dynamic> j) =>
      CrmTeacherSummary(
        sectionCount: (j['section_count'] as num?)?.toInt() ?? 0,
        studentCount: (j['student_count'] as num?)?.toInt() ?? 0,
        subjectCount: (j['subject_count'] as num?)?.toInt() ?? 0,
        sessionCount: (j['session_count'] as num?)?.toInt() ?? 0,
      );
}
