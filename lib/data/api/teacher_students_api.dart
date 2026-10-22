import '../../models/teacher_care_student.dart';
import '../../services/ems_api_service.dart';
import '../../services/offline_snapshot.dart';
import '../../services/app_session.dart';

/// Read every page before replacing the account's last complete copy.
class TeacherStudentsApi {
  static const _key = 'teacher_student_care';

  static int? _count(Object? raw) {
    final n = raw is num ? raw : num.tryParse('$raw');
    return n != null && n.isFinite && n >= 0 && n == n.roundToDouble()
        ? n.toInt()
        : null;
  }

  static EmsException _invalid() =>
      EmsException('Không tải được danh sách đầy đủ. Vui lòng thử lại.');

  static void _checkAccount(String? token, String? teacherId) {
    if (token != AppSession.instance.emsToken ||
        teacherId != AppSession.instance.teacherId) {
      throw EmsException('Phiên đăng nhập đã thay đổi.', statusCode: 403);
    }
  }

  static Future<({List<TeacherCareStudent> data, DateTime savedAt, bool fresh})>
  students() async {
    final token = AppSession.instance.emsToken;
    final teacherId = AppSession.instance.teacherId;
    try {
      final out = <TeacherCareStudent>[];
      final seen = <String>{};
      int? total;
      int? limit;
      for (var page = 1; ; page++) {
        final body = await EmsApiService.send(
          'GET',
          '/student-care',
          query: {'limit': '100', 'page': '$page'},
        );
        _checkAccount(token, teacherId);
        if (body is! Map<String, dynamic>) throw _invalid();
        final rows = body['students'];
        final nextTotal = _count(body['total']);
        final nextLimit = _count(body['limit']);
        if (rows is! List ||
            nextTotal == null ||
            nextLimit == null ||
            nextLimit < 1 ||
            nextLimit > 100 ||
            _count(body['page']) != page ||
            (total != null && total != nextTotal) ||
            (limit != null && limit != nextLimit)) {
          throw _invalid();
        }
        total = nextTotal;
        limit = nextLimit;
        final remaining = total - out.length;
        if (rows.length != (remaining < limit ? remaining : limit)) {
          throw _invalid();
        }
        for (final row in rows) {
          if (row is! Map<String, dynamic>) throw _invalid();
          final student = EmsApiService.parse(
            () => TeacherCareStudent.fromJson(row),
          );
          if (student.mssv.isEmpty || !seen.add(student.mssv)) {
            // A moving/repeated page must never become a plausible partial list.
            throw _invalid();
          }
          out.add(student);
        }
        if (out.length == total) break;
      }
      await OfflineSnapshot.save(_key, {
        'complete': true,
        'total': out.length,
        'students': out.map((s) => s.toJson()).toList(),
      });
      _checkAccount(token, teacherId);
      return (data: out, savedAt: DateTime.now(), fresh: true);
    } catch (e) {
      _checkAccount(token, teacherId);
      if (e is EmsException && (e.statusCode == 401 || e.statusCode == 403)) {
        if (token == AppSession.instance.emsToken &&
            teacherId == AppSession.instance.teacherId) {
          await OfflineSnapshot.remove(_key);
        }
        rethrow;
      }
      final stored = await OfflineSnapshot.load(_key);
      _checkAccount(token, teacherId);
      final blob = stored?.data;
      final rows = blob is Map ? blob['students'] : null;
      // Older flat caches may have been silently truncated at 20 pages.
      if (stored == null ||
          blob is! Map ||
          blob['complete'] != true ||
          rows is! List ||
          _count(blob['total']) != rows.length) {
        rethrow;
      }
      final out = <TeacherCareStudent>[];
      final seen = <String>{};
      for (final row in rows) {
        if (row is! Map<String, dynamic>) throw _invalid();
        final student = EmsApiService.parse(
          () => TeacherCareStudent.fromJson(row),
        );
        if (student.mssv.isEmpty || !seen.add(student.mssv)) throw _invalid();
        out.add(student);
      }
      return (data: out, savedAt: stored.savedAt, fresh: false);
    }
  }

  static Future<TeacherCareStudent> student(String mssv) async {
    final token = AppSession.instance.emsToken;
    final teacherId = AppSession.instance.teacherId;
    try {
      final body = await EmsApiService.send(
        'GET',
        '/student-care/student/${Uri.encodeComponent(mssv)}',
      );
      final row = body is Map<String, dynamic> ? body['student'] : null;
      _checkAccount(token, teacherId);
      if (row is! Map<String, dynamic> || body['available'] == false) {
        throw _invalid();
      }
      final student = EmsApiService.parse(
        () => TeacherCareStudent.fromJson(row),
      );
      if (student.mssv != mssv.trim()) throw _invalid();
      return student;
    } catch (e) {
      _checkAccount(token, teacherId);
      if (e is EmsException &&
          (e.statusCode == 401 || e.statusCode == 403) &&
          token == AppSession.instance.emsToken &&
          teacherId == AppSession.instance.teacherId) {
        await OfflineSnapshot.remove(_key);
      }
      rethrow;
    }
  }
}
