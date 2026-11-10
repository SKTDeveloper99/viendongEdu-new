/// Exam-morning list (T3): one status per student of my class, never an
/// amount (M-18, M-32). Source: CRM `GET /api/teacher/me/classes/:id/
/// exam-money` (the web page `teacher-exam-money.html`). Only `no` blocks an
/// exam (M-32); no data means the student still sits it.
///
/// Parsing keeps the status, the semester CODES a debt sits in, `as_of` and
/// `stale`. Every figure (`ims_balance`, `money_one`, per-semester amounts)
/// is dropped here and never reaches memory, the phone's disk or a widget.
library;

enum ExamMoneyStatus { allowed, owes, noData }

class ExamStudentStatus {
  final String mssv;
  final String fullName;
  final ExamMoneyStatus status;

  /// Semester codes of the debt (e.g. `261`), newest first; may be empty.
  final List<String> owesSemesters;

  const ExamStudentStatus({
    required this.mssv,
    required this.fullName,
    required this.status,
    this.owesSemesters = const [],
  });

  static ExamMoneyStatus parseStatus(Object? raw) => switch (raw) {
    'no' => ExamMoneyStatus.owes,
    'het_no' || 'du' => ExamMoneyStatus.allowed,
    _ => ExamMoneyStatus.noData,
  };

  factory ExamStudentStatus.fromJson(Map<String, dynamic> j) {
    final status = parseStatus(j['status']);
    final codes = <String>[];
    void add(Object? c) {
      final s = c?.toString().trim() ?? '';
      if (s.isNotEmpty && !codes.contains(s)) codes.add(s);
    }

    final listed = j['owes_semesters'];
    if (listed is List) {
      listed.forEach(add);
    } else if (j['semesters'] is List) {
      for (final row in j['semesters'] as List) {
        if (row is Map) add(row['semester_code']); // code only, no figures
      }
    }
    return ExamStudentStatus(
      mssv: j['mssv']?.toString() ?? '',
      fullName: j['full_name']?.toString() ?? '',
      status: status,
      owesSemesters: status == ExamMoneyStatus.owes ? codes : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'mssv': mssv,
    'full_name': fullName,
    'status': switch (status) {
      ExamMoneyStatus.owes => 'no',
      ExamMoneyStatus.allowed => 'het_no',
      ExamMoneyStatus.noData => 'khong_co_du_lieu',
    },
    'owes_semesters': owesSemesters,
  };

  /// Pill text.
  String get label => switch (status) {
    ExamMoneyStatus.allowed => 'Được thi',
    ExamMoneyStatus.owes =>
      owesSemesters.isEmpty
          ? 'Còn nợ học phí'
          : 'Còn nợ HK ${owesSemesters.join(', ')}',
    ExamMoneyStatus.noData => 'Chưa có dữ liệu',
  };
}

class ExamRosterStatus {
  final List<ExamStudentStatus> students;

  /// When the school's fee data was last read from IMS.
  final DateTime? asOf;

  /// The fee mirror is older than a day (status still applies, M-32).
  final bool stale;

  /// Set when this is the phone's saved copy (no connection).
  final DateTime? savedAt;

  const ExamRosterStatus({
    required this.students,
    this.asOf,
    this.stale = false,
    this.savedAt,
  });

  factory ExamRosterStatus.fromJson(Map<String, dynamic> j) {
    final rows = j['students'];
    return ExamRosterStatus(
      students: rows is List
          ? rows
                .whereType<Map<String, dynamic>>()
                .map(ExamStudentStatus.fromJson)
                .where((s) => s.mssv.isNotEmpty)
                .toList()
          : const [],
      asOf: DateTime.tryParse(j['as_of']?.toString() ?? '')?.toLocal(),
      stale: j['stale'] == true,
    );
  }

  ExamRosterStatus withSavedAt(DateTime at) => ExamRosterStatus(
    students: students,
    asOf: asOf,
    stale: stale,
    savedAt: at,
  );

  Map<String, dynamic> toJson() => {
    'students': students.map((s) => s.toJson()).toList(),
    'as_of': ?asOf?.toUtc().toIso8601String(),
    'stale': stale,
  };

  int count(ExamMoneyStatus s) => students.where((x) => x.status == s).length;
}
