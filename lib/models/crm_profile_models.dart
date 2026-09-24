/// Hồ sơ cá nhân — `GET/PATCH /api/student/me` và `GET/PATCH
/// /api/teacher/me/profile`. Xem `docs/api/mobile-ims-replacement-S5.md` §2.
library;

String? _strOrNull(dynamic v) {
  final s = v?.toString();
  if (s == null || s.isEmpty) return null;
  return s;
}

/// `student` trong `GET /api/student/me` — dùng để điền sẵn form sửa hồ sơ.
///
/// LƯU Ý: máy chủ hiện KHÔNG trả `cccd`/`cmnd` ở endpoint đọc này (chỉ có ở
/// phản hồi PATCH) — [cmnd] vì vậy thường là `null` lúc điền sẵn; màn hình
/// phải để trống ô CMND/CCCD thay vì đoán, chứ không phải một lỗi parse.
class CrmStudentProfile {
  final String? mssv;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? cmnd;

  const CrmStudentProfile({
    this.mssv,
    this.fullName,
    this.email,
    this.phone,
    this.cmnd,
  });

  /// Dựng từ `{student: {...}}` (GET /api/student/me).
  factory CrmStudentProfile.fromGetMeJson(Map<String, dynamic> j) {
    final s = (j['student'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CrmStudentProfile(
      mssv: _strOrNull(s['mssv']),
      fullName: _strOrNull(s['full_name']),
      email: _strOrNull(s['email']),
      phone: _strOrNull(s['phone']),
      cmnd: _strOrNull(s['cccd']),
    );
  }

  /// Dựng từ phản hồi `PATCH /api/student/me/profile`
  /// `{recorded_in, synced_to_ims, mssv, email, sdt, cmnd}`.
  factory CrmStudentProfile.fromPatchJson(Map<String, dynamic> j) =>
      CrmStudentProfile(
        mssv: _strOrNull(j['mssv']),
        email: _strOrNull(j['email']),
        phone: _strOrNull(j['sdt']),
        cmnd: _strOrNull(j['cmnd']),
      );
}

/// `teacher` trong `GET /api/teacher/me`.
class CrmTeacherProfile {
  final String? teacherId;
  final String? teacherCode;
  final String? fullName;
  final String? email;
  final String? phone;

  const CrmTeacherProfile({
    this.teacherId,
    this.teacherCode,
    this.fullName,
    this.email,
    this.phone,
  });

  /// Dựng từ `{teacher: {...}}` (GET /api/teacher/me).
  factory CrmTeacherProfile.fromGetMeJson(Map<String, dynamic> j) {
    final t = (j['teacher'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CrmTeacherProfile(
      teacherId: _strOrNull(t['teacher_id']),
      teacherCode: _strOrNull(t['teacher_code']),
      fullName: _strOrNull(t['name']),
      email: _strOrNull(t['email']),
      phone: _strOrNull(t['phone']),
    );
  }

  /// Dựng từ phản hồi `PATCH /api/teacher/me/profile`
  /// `{recorded_in, synced_to_ims, teacher_id, email, sdt}`.
  factory CrmTeacherProfile.fromPatchJson(Map<String, dynamic> j) =>
      CrmTeacherProfile(
        teacherId: _strOrNull(j['teacher_id']),
        email: _strOrNull(j['email']),
        phone: _strOrNull(j['sdt']),
      );
}
