/// Danh tính đăng nhập CRM (EMS) — thay cho các model IMS (`HocVien`,
/// `GiangVien`) làm nguồn sự thật cho phiên đăng nhập.
///
/// IMS vẫn còn trong app (các màn hình khác dùng `ApiService`/`HocVien`/
/// `GiangVien` cho tới sóng 2), nhưng ĐĂNG NHẬP không còn đi qua IMS: một
/// phiên hợp lệ bây giờ là một [CrmIdentity], không phải một token IMS.
/// [staff]: an office account with no teacher profile (Overlord slice).
enum CrmRole { student, teacher, staff }

class CrmIdentity {
  final CrmRole role;
  final String token;

  /// Chỉ có khi [role] là student.
  final String? mssv;

  /// Chỉ có khi [role] là teacher.
  final String? teacherId;
  final String? teacherCode;

  final String fullName;
  final bool mustChangePassword;

  /// Viva user id and what the server says the person is (`kinds`:
  /// teacher, staff or both) — from `POST /auth/app/login`.
  final String? userId;
  final bool isStaff;

  /// Display hints from the server's capabilities; the server re-checks.
  final bool canAssign;
  final bool trienKhai;

  const CrmIdentity({
    this.userId,
    this.isStaff = false,
    this.canAssign = false,
    this.trienKhai = false,
    required this.role,
    required this.token,
    required this.fullName,
    this.mssv,
    this.teacherId,
    this.teacherCode,
    this.mustChangePassword = false,
  });

  bool get isStudent => role == CrmRole.student;
  bool get isTeacher => role == CrmRole.teacher;
  bool get isStaffOnly => role == CrmRole.staff;

  /// `POST /auth/app/login` (any active Viva account): `{token, teacher|null,
  /// user:{id, full_name, role}, kinds:[teacher|staff], permissions, counts}`.
  /// A teacher-linked account is a teacher here (teacher home, attendance)
  /// and also staff when `kinds` says so.
  factory CrmIdentity.fromAppLogin(Map<String, dynamic> body) {
    final t = (body['teacher'] as Map?)?.cast<String, dynamic>();
    final u = (body['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final kinds = ((body['kinds'] as List?) ?? const [])
        .map((e) => '$e')
        .toSet();
    final p =
        (body['permissions'] as Map?)?.cast<String, dynamic>() ?? const {};
    final teacher = t != null && kinds.contains('teacher');
    return CrmIdentity(
      role: teacher ? CrmRole.teacher : CrmRole.staff,
      token: body['token']?.toString() ?? '',
      teacherId: t?['teacher_id']?.toString(),
      teacherCode: t?['teacher_code']?.toString(),
      fullName: (t?['full_name'] ?? u['full_name'])?.toString() ?? '',
      mustChangePassword: body['must_change_password'] == true,
      userId: u['id']?.toString(),
      isStaff: kinds.contains('staff'),
      canAssign: p['canAssignTasks'] == true,
      trienKhai: p['trienKhai'] == true,
    );
  }

  /// Dựng từ phản hồi `POST /auth/student/login`:
  /// `{token, student:{mssv, full_name, must_change_password}}`.
  factory CrmIdentity.fromStudentLogin(Map<String, dynamic> body) {
    final s = (body['student'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CrmIdentity(
      role: CrmRole.student,
      token: body['token']?.toString() ?? '',
      mssv: s['mssv']?.toString(),
      fullName: s['full_name']?.toString() ?? '',
      mustChangePassword: s['must_change_password'] == true,
    );
  }

  /// Dựng từ phản hồi `POST /auth/teacher/login`:
  /// `{token, teacher:{teacher_id, teacher_code, full_name,
  /// must_change_password}, user:{...}}`.
  factory CrmIdentity.fromTeacherLogin(Map<String, dynamic> body) {
    final t = (body['teacher'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CrmIdentity(
      role: CrmRole.teacher,
      token: body['token']?.toString() ?? '',
      teacherId: t['teacher_id']?.toString(),
      teacherCode: t['teacher_code']?.toString(),
      fullName: t['full_name']?.toString() ?? '',
      mustChangePassword: t['must_change_password'] == true,
    );
  }

  /// Định danh dùng để đăng ký/huỷ đăng ký FCM token và cho log — theo đúng
  /// tiền tố 'hv_'/'gv_' mà server thông báo cũ (`_notiBase`) đã dùng.
  String get notificationId => isStudent
      ? 'hv_${mssv ?? ''}'
      : (isStaffOnly ? 'st_${userId ?? ''}' : 'gv_${teacherCode ?? ''}');

  /// MSSV hoặc mã giáo viên — dùng khi màn hình cần MỘT chuỗi định danh
  /// chung, không quan tâm vai trò.
  String get loginId => isStudent ? (mssv ?? '') : (teacherCode ?? '');

  CrmIdentity copyWith({bool? mustChangePassword, String? token}) =>
      CrmIdentity(
        role: role,
        token: token ?? this.token,
        mssv: mssv,
        teacherId: teacherId,
        teacherCode: teacherCode,
        fullName: fullName,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
        userId: userId,
        isStaff: isStaff,
        canAssign: canAssign,
        trienKhai: trienKhai,
      );

  Map<String, dynamic> toPrefsJson() => {
    'role': role.name,
    'mssv': mssv,
    'teacher_id': teacherId,
    'teacher_code': teacherCode,
    'full_name': fullName,
    'must_change_password': mustChangePassword,
    'user_id': userId,
    'is_staff': isStaff,
    'can_assign': canAssign,
    'trien_khai': trienKhai,
  };

  /// Dựng lại từ SharedPreferences. [token] tới từ khoá 'ems_token' riêng
  /// (đã có sẵn từ trước khi CRM là danh tính chính).
  static CrmIdentity? fromPrefsJson(Map<String, dynamic>? j, String? token) {
    if (j == null || token == null || token.isEmpty) return null;
    final roleStr = j['role']?.toString();
    final role = switch (roleStr) {
      'teacher' => CrmRole.teacher,
      'staff' => CrmRole.staff,
      _ => CrmRole.student,
    };
    return CrmIdentity(
      role: role,
      token: token,
      mssv: j['mssv']?.toString(),
      teacherId: j['teacher_id']?.toString(),
      teacherCode: j['teacher_code']?.toString(),
      fullName: j['full_name']?.toString() ?? '',
      mustChangePassword: j['must_change_password'] == true,
      userId: j['user_id']?.toString(),
      isStaff: j['is_staff'] == true,
      canAssign: j['can_assign'] == true,
      trienKhai: j['trien_khai'] == true,
    );
  }
}
