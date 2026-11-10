/// Money of one student in the teacher view (split from
/// teacher_care_student.dart): the M-54 one number, the current term and
/// the exam-gate status. Unknown is "Đang đối chiếu", never 0.
library;

import 'exam_status_models.dart';

num? _num(Object? v) {
  if (v is num) return v.isFinite ? v : null;
  if (v is String) {
    final n = num.tryParse(v.trim());
    return (n != null && n.isFinite) ? n : null;
  }
  return null;
}

/// Học phí theo `dossier.money_one`. Hoặc biết đủ cả ba số, hoặc không biết.
class CareMoney {
  final bool known;
  final num? owedTotal;
  final num? paid;
  final num? balance;

  /// Còn nợ tính tới hạn giữa kỳ — chỉ khi máy chủ nói `owes: true`.
  final bool owes;
  final DateTime? asOf;
  final bool stale;

  /// False on list rows: the list keeps status only (owner 2026-11-10, no
  /// class-wide money on the phone); the figures come with the one-student
  /// read of the detail screen.
  bool get hasFigures => known && owedTotal != null;

  bool get overpaid => hasFigures && balance == 0 && paid! > owedTotal!;

  /// Same status, no amounts.
  CareMoney withoutFigures() =>
      CareMoney._(known, null, null, null, owes, asOf, stale);

  const CareMoney._(
    this.known,
    this.owedTotal,
    this.paid,
    this.balance,
    this.owes,
    this.asOf,
    this.stale,
  );

  static const unknown = CareMoney._(
    false,
    null,
    null,
    null,
    false,
    null,
    false,
  );

  factory CareMoney.fromJson(Object? raw) {
    if (raw is! Map) return unknown;
    final j = raw.cast<String, dynamic>();
    if (j['money_known'] != true) return unknown;
    if (j['status_only'] == true) {
      // A saved list row: status without amounts.
      return CareMoney._(
        true,
        null,
        null,
        null,
        j['owes'] == true,
        DateTime.tryParse('${j['as_of'] ?? ''}'),
        j['stale'] == true,
      );
    }
    final owed = _num(j['owedTotal']);
    final paid = _num(j['paid']);
    final bal = _num(j['balance']);
    if ([
      owed,
      paid,
      bal,
    ].any((n) => n == null || n < 0 || n != n.roundToDouble())) {
      return unknown;
    }
    return CareMoney._(
      true,
      owed,
      paid,
      bal,
      j['owes'] == true,
      DateTime.tryParse('${j['as_of'] ?? ''}'),
      j['stale'] == true,
    );
  }

  Map<String, dynamic> toJson() => known
      ? {
          'money_known': true,
          'status_only': ?(hasFigures ? null : true),
          'owedTotal': ?owedTotal,
          'paid': ?paid,
          'balance': ?balance,
          'owes': owes,
          'as_of': ?asOf?.toUtc().toIso8601String(),
          'stale': stale,
        }
      : {'money_known': false};
}

/// Current-term money of one student (`dossier.money_term`, asked of the
/// server lane, A4): `{semester_code, money_known, owed, paid, remaining}`.
/// Either all three figures are known or none is shown ("Đang đối chiếu").
class CareTermMoney {
  final String? semesterCode;
  final num? owed;
  final num? paid;
  final num? remaining;

  bool get known => owed != null;

  const CareTermMoney._(
    this.semesterCode,
    this.owed,
    this.paid,
    this.remaining,
  );

  static const unknown = CareTermMoney._(null, null, null, null);

  factory CareTermMoney.fromJson(Object? raw) {
    if (raw is! Map) return unknown;
    final code = raw['semester_code']?.toString();
    final figures = [
      _num(raw['owed']),
      _num(raw['paid']),
      _num(raw['remaining']),
    ];
    if (raw['money_known'] != true ||
        figures.any((n) => n == null || n < 0 || n != n.roundToDouble())) {
      return CareTermMoney._(code, null, null, null);
    }
    return CareTermMoney._(code, figures[0], figures[1], figures[2]);
  }
}

/// Exam-gate status of one student (status only, M-32): `dossier.exam_gate`
/// when the server sends it (A4), else the gate status inside
/// `dossier.money`, else the one-voice figure's `owes`.
({ExamMoneyStatus status, List<String> owesSemesters}) careExamGate(
  Map<String, dynamic> dossier,
  CareMoney money,
) {
  final gate = dossier['exam_gate'];
  if (gate is Map) {
    final row = ExamStudentStatus.fromJson({
      'mssv': '-',
      'status': gate['status'],
      'owes_semesters': gate['owes_semesters'],
    });
    return (status: row.status, owesSemesters: row.owesSemesters);
  }
  final legacy = dossier['money'];
  if (legacy is Map && legacy['status'] is String) {
    return (
      status: ExamStudentStatus.parseStatus(legacy['status']),
      owesSemesters: const <String>[],
    );
  }
  if (!money.known) {
    return (status: ExamMoneyStatus.noData, owesSemesters: const <String>[]);
  }
  return (
    status: money.owes ? ExamMoneyStatus.owes : ExamMoneyStatus.allowed,
    owesSemesters: const <String>[],
  );
}

/// Một lớp học phần của sinh viên (`dossier.sections[]`).
