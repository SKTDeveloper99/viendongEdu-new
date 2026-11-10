import '../models/teaching_report_models.dart';
import '../services/ems_api_service.dart';
import '../services/offline_snapshot.dart';
import 'api/teaching_report_api.dart';

enum TeachingReportResult {
  /// The server stored it.
  sent,

  /// The server already had a report for this session (counts as done).
  alreadyReported,

  /// Kept on the phone ("chưa gửi"); sent later by [TeachingReportRepository.drain].
  queued,
}

/// T-28 teaching reports: the pending list, sending, and an account-scoped
/// queue for reports made without a connection. The queue is matched to the
/// server's session by section + date + start time when it is sent.
class TeachingReportRepository {
  const TeachingReportRepository();

  static const _queueKey = 'teaching_report_queue';
  static bool _draining = false;

  Future<List<TeachingReportSession>> pending() => TeachingReportApi.pending();

  /// The pending session matching an attendance session, or null.
  static TeachingReportSession? match(
    List<TeachingReportSession> pending,
    String key,
  ) => pending.where((s) => s.key == key).firstOrNull;

  Future<List<QueuedTeachingReport>> queued() async {
    final raw = (await OfflineSnapshot.load(_queueKey))?.data;
    if (raw is! List) return const [];
    return raw
        .map(QueuedTeachingReport.tryParse)
        .whereType<QueuedTeachingReport>()
        .toList();
  }

  Future<void> _write(List<QueuedTeachingReport> items) =>
      OfflineSnapshot.save(_queueKey, items.map((q) => q.toJson()).toList());

  /// Adds or replaces the queued report of the same session.
  Future<void> enqueue(QueuedTeachingReport report) async {
    final items = (await queued()).where((q) => q.key != report.key).toList()
      ..add(report);
    await _write(items);
  }

  Future<void> discard(String key) async =>
      _write((await queued()).where((q) => q.key != key).toList());

  /// Sends [report] now when possible, else keeps it queued. Throws an
  /// [EmsException] only when the server refuses it outright (4xx).
  Future<TeachingReportResult> report(
    QueuedTeachingReport report, {
    List<TeachingReportSession>? known,
  }) async {
    try {
      final list = known ?? await pending();
      final session = match(list, report.key);
      if (session == null) {
        await enqueue(report.withProblem(_notFound));
        return TeachingReportResult.queued;
      }
      final result = await _send(session.id, report.choice);
      await discard(report.key);
      return result;
    } on EmsException catch (e) {
      if (_refused(e)) rethrow;
      await enqueue(report.withProblem(null));
      return TeachingReportResult.queued;
    } catch (_) {
      await enqueue(report.withProblem(null));
      return TeachingReportResult.queued;
    }
  }

  /// One pass over the queue; returns how many left the phone. Safe to call
  /// at any time (from the attendance outbox triggers).
  Future<int> drain() async {
    if (_draining) return 0;
    _draining = true;
    var done = 0;
    try {
      final items = await queued();
      if (items.isEmpty) return 0;
      final list = await pending();
      for (final q in items) {
        final session = match(list, q.key);
        if (session == null) {
          if (q.problem != _notFound) await enqueue(q.withProblem(_notFound));
          continue;
        }
        try {
          await _send(session.id, q.choice);
          await discard(q.key);
          done++;
        } on EmsException catch (e) {
          if (!_refused(e)) return done; // offline / server busy: later
          await enqueue(q.withProblem(e.message));
        }
      }
    } catch (_) {
      // Offline or unreadable: the next trigger retries.
    } finally {
      _draining = false;
    }
    return done;
  }

  Future<TeachingReportResult> _send(String id, TeachingReportChoice c) async {
    try {
      await TeachingReportApi.submit(id, c);
      return TeachingReportResult.sent;
    } on EmsException catch (e) {
      // A retry after a lost reply: the first send already stored it.
      if (e.statusCode == 409) return TeachingReportResult.alreadyReported;
      rethrow;
    }
  }

  static bool _refused(EmsException e) {
    final s = e.statusCode;
    return s != null && s >= 400 && s < 500 && s != 401 && s != 408;
  }

  static const _notFound =
      'Máy chủ chưa có buổi này trong danh sách chờ báo cáo; sẽ thử lại.';
}
