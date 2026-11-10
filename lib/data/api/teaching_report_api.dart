import '../../models/teaching_report_models.dart';
import '../../services/ems_api_service.dart';

/// LAW T-28, CRM `routes/teaching-reports.js` (teacher tokens accepted
/// through `requireAuth`, like `/api/attendance`).
abstract final class TeachingReportApi {
  /// My sessions up to today that still need a report (current semester).
  static Future<List<TeachingReportSession>> pending() async {
    final body = await EmsApiService.sendMap('GET', '/teaching-reports');
    final rows = EmsApiService.rows(body['pending'] ?? const []);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (r) => EmsApiService.parse(() => TeachingReportSession.fromJson(r)),
        )
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  static Future<void> submit(String sessionId, TeachingReportChoice c) async {
    await EmsApiService.sendMap(
      'POST',
      '/teaching-reports/${Uri.encodeComponent(sessionId)}',
      body: {
        'outcome': c.outcome.name,
        'actual_periods': c.periods,
        if (c.note?.trim().isNotEmpty == true) 'content': c.note!.trim(),
      },
    );
  }
}
