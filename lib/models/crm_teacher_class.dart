/// Mô hình lịch dạy — dùng chung cho bốn endpoint có cùng khuôn dạng cột
/// (mirror của IMS `giangvien/tkbtheongay` / `tkbtheohocky`):
///   - `GET /api/teacher/me/schedule?date=`            (theo ngày)
///   - `GET /api/teacher/me/schedule/semester?semester=` (theo học kỳ, lặp lại)
///   - `today_sessions` / `semester_slots` lồng trong `GET .../me/overview`
///
/// Theo ngày có `thoigianbd/thoigiankt/ngay`; theo học kỳ có
/// `tgbatdau/tgketthuc` (không có `ngay` — đó là một khung giờ LẶP LẠI, không
/// phải một buổi cụ thể). Model gộp cả hai bộ trường (nullable) để một hàm
/// `toJson()` duy nhất nuôi được mọi widget đang đọc theo tên cột cũ.
class CrmScheduleSlot {
  /// `sec.ims_lop_mon_hoc_id` — vẫn là id IMS, nhưng đây là DỮ LIỆU đã đồng bộ
  /// vào CRM (cột `sections.ims_lop_mon_hoc_id`), không phải một lời gọi tới
  /// IMS. Cần để dựng `session_key` cho EMS
  /// (`EmsApiService.sessionKeyFor(lmhId: ...)`).
  final String lmhId;
  final String lmhMa;
  final String? mhTen;
  final int? soTinChi;
  final String? phongTen;
  final String? tietBd;
  final String? ngayMa;
  final String? ngayTen;
  final bool baoNghiYn;

  // Theo ngày cụ thể.
  final String? thoiGianBd;
  final String? thoiGianKt;
  final String? ngay;

  // Theo học kỳ (khung giờ lặp lại).
  final String? tgBatDau;
  final String? tgKetThuc;

  const CrmScheduleSlot({
    required this.lmhId,
    required this.lmhMa,
    this.mhTen,
    this.soTinChi,
    this.phongTen,
    this.tietBd,
    this.ngayMa,
    this.ngayTen,
    this.baoNghiYn = false,
    this.thoiGianBd,
    this.thoiGianKt,
    this.ngay,
    this.tgBatDau,
    this.tgKetThuc,
  });

  factory CrmScheduleSlot.fromJson(Map<String, dynamic> j) => CrmScheduleSlot(
    lmhId: j['lmhid']?.toString() ?? '',
    lmhMa: j['lmhma']?.toString() ?? '',
    mhTen: j['mhten']?.toString(),
    soTinChi: (j['sotinchi'] as num?)?.toInt(),
    phongTen: j['phongten']?.toString(),
    tietBd: j['tietbd']?.toString(),
    ngayMa: j['ngayma']?.toString(),
    ngayTen: j['ngayten']?.toString(),
    baoNghiYn: j['baonghiyn'] == true,
    thoiGianBd: j['thoigianbd']?.toString(),
    thoiGianKt: j['thoigiankt']?.toString(),
    ngay: j['ngay']?.toString(),
    tgBatDau: j['tgbatdau']?.toString(),
    tgKetThuc: j['tgketthuc']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'lmhid': lmhId,
    'lmhma': lmhMa,
    'mhten': ?mhTen,
    'sotinchi': ?soTinChi,
    'phongten': ?phongTen,
    'tietbd': ?tietBd,
    'ngayma': ?ngayMa,
    'ngayten': ?ngayTen,
    'baonghiyn': baoNghiYn,
    'thoigianbd': ?thoiGianBd,
    'thoigiankt': ?thoiGianKt,
    'ngay': ?ngay,
    'tgbatdau': ?tgBatDau,
    'tgketthuc': ?tgKetThuc,
  };
}

/// `GET /api/teacher/me/classes?semester=` — một dòng lớp môn học
/// (`sections` join `subjects`), thay cho IMS `giangvien/danhsachlop`.
///
/// Khác biệt lớn nhất so với IMS: [sectionId] là UUID của CRM (`sections.id`),
/// KHÔNG phải `lopmonhocid` số nguyên của IMS. Mọi lời gọi tiếp theo
/// (`/students`, `/attendance`, `/grades`) dùng [sectionId] này.
class CrmTeacherClass {
  final String sectionId;
  final String sectionCode;
  final String? semesterCode;
  final String? room;
  final int? siSo;
  final String? ngayBatDau;
  final String? ngayKetThuc;
  final String? ngayThi;
  final String? subjectCode;
  final String? subjectName;
  final int? credits;
  final int enrolledStudents;
  final int sessions;
  final int attendanceRows;
  final int gradeRows;

  const CrmTeacherClass({
    required this.sectionId,
    required this.sectionCode,
    this.semesterCode,
    this.room,
    this.siSo,
    this.ngayBatDau,
    this.ngayKetThuc,
    this.ngayThi,
    this.subjectCode,
    this.subjectName,
    this.credits,
    this.enrolledStudents = 0,
    this.sessions = 0,
    this.attendanceRows = 0,
    this.gradeRows = 0,
  });

  factory CrmTeacherClass.fromJson(Map<String, dynamic> j) => CrmTeacherClass(
    sectionId: j['section_id']?.toString() ?? '',
    sectionCode: j['section_code']?.toString() ?? '',
    semesterCode: j['semester_code']?.toString(),
    room: j['room']?.toString(),
    siSo: (j['si_so'] as num?)?.toInt(),
    ngayBatDau: j['ngay_bat_dau']?.toString(),
    ngayKetThuc: j['ngay_ket_thuc']?.toString(),
    ngayThi: j['ngay_thi']?.toString(),
    subjectCode: j['subject_code']?.toString(),
    subjectName: j['subject_name']?.toString(),
    credits: (j['credits'] as num?)?.toInt(),
    enrolledStudents: (j['enrolled_students'] as num?)?.toInt() ?? 0,
    sessions: (j['sessions'] as num?)?.toInt() ?? 0,
    attendanceRows: (j['attendance_rows'] as num?)?.toInt() ?? 0,
    gradeRows: (j['grade_rows'] as num?)?.toInt() ?? 0,
  );
}

/// `GET /api/teacher/me/classes/:sectionId/students`.
class CrmClassStudent {
  final String enrollmentId;
  final String mssv;
  final String fullName;
  final String? status;
  final String? classCode;
  final String? gradeId;
  final num? midtermScore;
  final num? finalExamScore;
  final num? finalScore;
  final String? gradeStatus;
  final int attendanceRows;
  final int presentRows;
  final int absentRows;

  const CrmClassStudent({
    required this.enrollmentId,
    required this.mssv,
    required this.fullName,
    this.status,
    this.classCode,
    this.gradeId,
    this.midtermScore,
    this.finalExamScore,
    this.finalScore,
    this.gradeStatus,
    this.attendanceRows = 0,
    this.presentRows = 0,
    this.absentRows = 0,
  });

  factory CrmClassStudent.fromJson(Map<String, dynamic> j) => CrmClassStudent(
    enrollmentId: j['enrollment_id']?.toString() ?? '',
    mssv: j['mssv']?.toString() ?? '',
    fullName: j['full_name']?.toString() ?? '',
    status: j['status']?.toString(),
    classCode: j['class_code']?.toString(),
    gradeId: j['grade_id']?.toString(),
    midtermScore: j['midterm_score'] as num?,
    finalExamScore: j['final_exam_score'] as num?,
    finalScore: j['final_score'] as num?,
    gradeStatus: j['grade_status']?.toString(),
    attendanceRows: (j['attendance_rows'] as num?)?.toInt() ?? 0,
    presentRows: (j['present_rows'] as num?)?.toInt() ?? 0,
    absentRows: (j['absent_rows'] as num?)?.toInt() ?? 0,
  );
}

/// Một dòng (buổi × học viên) từ `GET /api/teacher/me/classes/:id/attendance`
/// — phẳng, không nhóm theo buổi. Màn hình tự nhóm theo [sessionId] để dựng
/// danh sách "Buổi học" và tự gộp theo [mssv] để dựng "Tổng hợp".
///
/// LƯU Ý (CLAUDE.md "EMS write path"): đây là bảng `attendance` của CRM, một
/// bản chụp — KHÔNG phải điểm danh EMS (bảng `attendance_marks`, nguồn thật).
/// Màn hình vẫn phải hỏi EMS (`EmsApiService.sessionMarks`) cho trạng thái có
/// mặt/vắng thật của một buổi cụ thể, giống hệt bản trước khi gỡ IMS.
class CrmAttendanceRow {
  final String sessionId;
  final String? date;
  final String? startTime;
  final String? endTime;
  final String? room;
  final String? sessionStatus;
  final String? attendanceId;
  final String? mssv;
  final String? fullName;
  final String? status;
  final String? notes;

  const CrmAttendanceRow({
    required this.sessionId,
    this.date,
    this.startTime,
    this.endTime,
    this.room,
    this.sessionStatus,
    this.attendanceId,
    this.mssv,
    this.fullName,
    this.status,
    this.notes,
  });

  factory CrmAttendanceRow.fromJson(Map<String, dynamic> j) =>
      CrmAttendanceRow(
        sessionId: j['session_id']?.toString() ?? '',
        date: j['date']?.toString(),
        startTime: j['start_time']?.toString(),
        endTime: j['end_time']?.toString(),
        room: j['room']?.toString(),
        sessionStatus: j['session_status']?.toString(),
        attendanceId: j['attendance_id']?.toString(),
        mssv: j['mssv']?.toString(),
        fullName: j['full_name']?.toString(),
        status: j['status']?.toString(),
        notes: j['notes']?.toString(),
      );
}

/// `GET /api/teacher/me/exams?semester=` — thay IMS `giangvien/lichthi`.
/// Xem `docs/api/mobile-ims-replacement-S3.md` (bot S3) cho hình dạng đầy đủ
/// và các giới hạn dữ liệu (phòng thường null, coi thi là text tự do).
class CrmTeacherExam {
  final String examId;
  final String? examDate;
  final String? startTime;
  final int? durationMinutes;
  final String? examType;
  final String? examFormat;
  final int? classSize;
  final String? proctor1;
  final String? proctor2;
  final String? note;
  final String? room;
  final String? classCode;
  final String? subjectCode;
  final String? subjectName;
  final int? credits;
  final String? semesterCode;
  final String? semesterName;

  const CrmTeacherExam({
    required this.examId,
    this.examDate,
    this.startTime,
    this.durationMinutes,
    this.examType,
    this.examFormat,
    this.classSize,
    this.proctor1,
    this.proctor2,
    this.note,
    this.room,
    this.classCode,
    this.subjectCode,
    this.subjectName,
    this.credits,
    this.semesterCode,
    this.semesterName,
  });

  factory CrmTeacherExam.fromJson(Map<String, dynamic> j) => CrmTeacherExam(
    examId: j['exam_id']?.toString() ?? '',
    examDate: j['exam_date']?.toString(),
    startTime: j['start_time']?.toString(),
    durationMinutes: int.tryParse('${j['duration_minutes'] ?? ''}'),
    examType: j['exam_type']?.toString(),
    examFormat: j['exam_format']?.toString(),
    classSize: int.tryParse('${j['class_size'] ?? ''}'),
    proctor1: j['proctor_1']?.toString(),
    proctor2: j['proctor_2']?.toString(),
    note: j['note']?.toString(),
    room: j['room']?.toString(),
    classCode: j['class_code']?.toString(),
    subjectCode: j['subject_code']?.toString(),
    subjectName: j['subject_name']?.toString(),
    credits: int.tryParse('${j['credits'] ?? ''}'),
    semesterCode: j['semester_code']?.toString(),
    semesterName: j['semester_name']?.toString(),
  );
}
