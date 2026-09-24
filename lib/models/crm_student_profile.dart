// lib/models/crm_student_profile.dart — typed shape of `GET /api/student/me`.
//
// Source: crm-clean routes/portals/student-portal.js `router.get('/me', …)`
// → lib/portals-student-portal-service.js#getProfile → repositories/
// portals-student-portal-repo.js#getStudent. Response is `{ student: {...} }`.
//
// Fields the CRM table (`students`) actually holds but this endpoint does
// NOT select (verified by reading the repo query, not guessed):
//   - `cccd` (CCCD/CMND number) — column exists on `students`, but
//     getStudent()'s SELECT list omits it. Shown as "—" in the profile
//     screen; documented as a gap in
//     docs/ims_to_crm_student_academic_map.md rather than invented.
//   - "chuyên ngành" (a narrower sub-major level the old IMS hierarchy had
//     under ngành) has no CRM equivalent — CRM only models one ngành level.
class CrmStudentProfile {
  final String mssv;
  final String lastName;
  final String firstName;
  final String fullName;
  final DateTime? dateOfBirth;
  final String? gender; // 'M' | 'F' | null
  final String? phone;
  final String? email;
  final String? status;
  final String? classId;
  final String? classCode;
  final String? khoa;
  final String? khoaLabel;
  final String? programName;
  final String? programCode;
  final String? nganhName;
  final String? nganhShort;
  final String? nganhCode;

  const CrmStudentProfile({
    required this.mssv,
    this.lastName = '',
    this.firstName = '',
    this.fullName = '',
    this.dateOfBirth,
    this.gender,
    this.phone,
    this.email,
    this.status,
    this.classId,
    this.classCode,
    this.khoa,
    this.khoaLabel,
    this.programName,
    this.programCode,
    this.nganhName,
    this.nganhShort,
    this.nganhCode,
  });

  String get genderLabel =>
      gender == 'M' ? 'Nam' : (gender == 'F' ? 'Nữ' : '–');

  /// "Khóa n" giống nhãn cũ; '–' khi CRM chưa gắn khóa cho học viên.
  String get khoaDisplay => khoa == null || khoa!.isEmpty ? '–' : 'Khóa $khoa';

  factory CrmStudentProfile.fromJson(Map<String, dynamic> j) =>
      CrmStudentProfile(
        mssv: j['mssv']?.toString() ?? '',
        lastName: j['last_name']?.toString() ?? '',
        firstName: j['first_name']?.toString() ?? '',
        fullName: j['full_name']?.toString() ?? '',
        dateOfBirth: DateTime.tryParse(j['date_of_birth']?.toString() ?? ''),
        gender: j['gender']?.toString(),
        phone: j['phone']?.toString(),
        email: j['email']?.toString(),
        status: j['status']?.toString(),
        classId: j['class_id']?.toString(),
        classCode: j['class_code']?.toString(),
        khoa: j['khoa']?.toString(),
        khoaLabel: j['khoa_label']?.toString(),
        programName: j['program_name']?.toString(),
        programCode: j['program_code']?.toString(),
        nganhName: j['nganh_name']?.toString(),
        nganhShort: j['nganh_short']?.toString(),
        nganhCode: j['nganh_code']?.toString(),
      );
}
