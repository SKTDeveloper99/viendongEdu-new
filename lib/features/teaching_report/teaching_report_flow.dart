import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/teaching_report_repository.dart';
import '../../models/teaching_report_models.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import 'widgets/teaching_report_sheet.dart';

/// `2026-11-10` → `10/11/2026`.
String reportDate(String iso) {
  final p = iso.split('T').first.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}

/// After a teacher saves a session's attendance: ask for its T-28 report.
/// Nothing is asked when the server says the session has no pending report
/// (already reported, e.g. on the web) or one is already queued here.
Future<void> offerTeachingReport(
  BuildContext context,
  EmsSession session, {
  TeachingReportRepository repository = const TeachingReportRepository(),
  Duration lookupTimeout = const Duration(seconds: 4),
}) async {
  final start = hhmm(session.startTime);
  if (start == null || session.sectionCode.isEmpty) return;
  final key = teachingReportKey(
    session.sectionCode,
    session.sessionDate,
    start,
  );
  if ((await repository.queued()).any((q) => q.key == key)) return;
  List<TeachingReportSession>? pending;
  try {
    pending = await repository.pending().timeout(lookupTimeout);
  } catch (_) {
    pending = null; // offline: ask anyway, queue the answer
  }
  final match = pending == null
      ? null
      : TeachingReportRepository.match(pending, key);
  if (pending != null && match == null) return;
  if (!context.mounted) return;
  await askAndReport(
    context,
    report: (choice) => QueuedTeachingReport(
      sectionCode: session.sectionCode,
      meetingDate: session.sessionDate.split('T').first,
      startTime: start,
      subjectName: session.subjectName?.isNotEmpty == true
          ? session.subjectName!
          : session.sectionCode,
      choice: choice,
      createdAt: DateTime.now(),
    ),
    title: session.subjectName?.isNotEmpty == true
        ? '${session.subjectName} · ${session.sectionCode}'
        : session.sectionCode,
    when: '${reportDate(session.sessionDate)} · ${session.timeLabel}',
    scheduledPeriods: match?.scheduledPeriods,
    known: pending,
    repository: repository,
  );
}

/// Shows the sheet, sends or queues the answer and says which happened.
/// Returns true when the teacher answered (sent, already there or queued).
Future<bool> askAndReport(
  BuildContext context, {
  required QueuedTeachingReport Function(TeachingReportChoice) report,
  required String title,
  required String when,
  int? scheduledPeriods,
  List<TeachingReportSession>? known,
  TeachingReportRepository repository = const TeachingReportRepository(),
}) async {
  final choice = await showTeachingReportSheet(
    context,
    title: title,
    when: when,
    scheduledPeriods: scheduledPeriods,
  );
  if (choice == null || !choice.valid || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final vd = context.vd;
  void say(String text, {bool good = false}) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), backgroundColor: good ? vd.success : null),
    );
  try {
    final result = await repository.report(report(choice), known: known);
    say(switch (result) {
      TeachingReportResult.sent =>
        'Đã gửi báo cáo giảng dạy: ${choice.summary}.',
      TeachingReportResult.alreadyReported =>
        'Buổi này đã có báo cáo trên máy chủ.',
      TeachingReportResult.queued =>
        'CHƯA GỬI báo cáo. Đã giữ trên máy, sẽ tự gửi khi có mạng.',
    }, good: result != TeachingReportResult.queued);
    return true;
  } on EmsException catch (e) {
    say('Máy chủ từ chối báo cáo: ${e.message}');
    return false;
  }
}
