/// LAW T-28 teaching reports (Báo cáo giảng dạy), CRM
/// `routes/teaching-reports.js`:
///   GET  /api/teaching-reports              → { semester, pending: [...] }
///   POST /api/teaching-reports/:sessionId   { outcome, actual_periods, content? }
/// A report states the periods actually taught: held/late 1–15, cancelled or
/// no-show 0. The timetable is never copied in; the teacher always taps.
library;

import 'json_values.dart';

/// One past or today's session of mine with no report yet.
class TeachingReportSession {
  final String id;
  final String meetingDate; // yyyy-MM-dd
  final String startTime; // HH:mm
  final String? endTime;
  final String? room;
  final String sectionCode;
  final String subjectName;

  /// Timetable periods for this meeting, when the server sends them
  /// (`scheduled_periods`, asked of the server lane); null = unknown.
  final int? scheduledPeriods;

  const TeachingReportSession({
    required this.id,
    required this.meetingDate,
    required this.startTime,
    required this.sectionCode,
    required this.subjectName,
    this.endTime,
    this.room,
    this.scheduledPeriods,
  });

  factory TeachingReportSession.fromJson(Map<String, dynamic> j) {
    final periods = jsonInt(j['scheduled_periods']);
    return TeachingReportSession(
      id: j['id']?.toString() ?? '',
      meetingDate: (j['meeting_date']?.toString() ?? '').split('T').first,
      startTime: hhmm(j['start_time']?.toString()) ?? '',
      endTime: hhmm(j['end_time']?.toString()),
      room: j['room']?.toString(),
      sectionCode: j['section_code']?.toString() ?? '',
      subjectName: j['subject_name']?.toString() ?? '',
      scheduledPeriods: periods != null && periods >= 1 && periods <= 15
          ? periods
          : null,
    );
  }

  /// The natural key an attendance session and a queued report share.
  String get key => teachingReportKey(sectionCode, meetingDate, startTime);
}

/// `07:30:00` / `07:30` → `07:30`; anything else → null.
String? hhmm(String? raw) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw?.trim() ?? '');
  if (m == null) return null;
  return '${m[1]!.padLeft(2, '0')}:${m[2]}';
}

String teachingReportKey(String sectionCode, String date, String start) =>
    '$sectionCode|${date.split('T').first}|${hhmm(start) ?? start}';

enum TeachingOutcome { held, cancelled }

/// What the teacher chose on the sheet.
class TeachingReportChoice {
  final TeachingOutcome outcome;
  final int periods;
  final String? note;
  const TeachingReportChoice({
    required this.outcome,
    required this.periods,
    this.note,
  });

  /// T-28: held needs 1–15 periods, cancelled records 0.
  bool get valid => outcome == TeachingOutcome.cancelled
      ? periods == 0
      : periods >= 1 && periods <= 15;

  String get summary => outcome == TeachingOutcome.cancelled
      ? 'Buổi học nghỉ'
      : 'Đã dạy $periods tiết';
}

/// A report kept on the phone until the server confirms it.
class QueuedTeachingReport {
  final String sectionCode;
  final String meetingDate;
  final String startTime;
  final String subjectName;
  final TeachingReportChoice choice;
  final DateTime createdAt;

  /// Why the server would not take it (shown; the teacher may discard it).
  final String? problem;

  const QueuedTeachingReport({
    required this.sectionCode,
    required this.meetingDate,
    required this.startTime,
    required this.subjectName,
    required this.choice,
    required this.createdAt,
    this.problem,
  });

  String get key => teachingReportKey(sectionCode, meetingDate, startTime);

  QueuedTeachingReport withProblem(String? p) => QueuedTeachingReport(
    sectionCode: sectionCode,
    meetingDate: meetingDate,
    startTime: startTime,
    subjectName: subjectName,
    choice: choice,
    createdAt: createdAt,
    problem: p,
  );

  Map<String, dynamic> toJson() => {
    'section_code': sectionCode,
    'meeting_date': meetingDate,
    'start_time': startTime,
    'subject_name': subjectName,
    'outcome': choice.outcome.name,
    'periods': choice.periods,
    'note': ?choice.note,
    'created_at': createdAt.toIso8601String(),
    'problem': ?problem,
  };

  static QueuedTeachingReport? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final outcome = TeachingOutcome.values
        .where((o) => o.name == raw['outcome'])
        .firstOrNull;
    final periods = jsonInt(raw['periods']);
    final section = raw['section_code'];
    final date = raw['meeting_date'];
    final start = raw['start_time'];
    if (outcome == null ||
        periods == null ||
        section is! String ||
        date is! String ||
        start is! String) {
      return null;
    }
    final choice = TeachingReportChoice(
      outcome: outcome,
      periods: periods,
      note: raw['note'] is String ? raw['note'] as String : null,
    );
    if (!choice.valid) return null;
    return QueuedTeachingReport(
      sectionCode: section,
      meetingDate: date,
      startTime: start,
      subjectName: raw['subject_name']?.toString() ?? section,
      choice: choice,
      createdAt:
          DateTime.tryParse(raw['created_at']?.toString() ?? '') ??
          DateTime.now(),
      problem: raw['problem'] is String ? raw['problem'] as String : null,
    );
  }
}
