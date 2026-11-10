import '../models/crm_teacher_class.dart';
import '../models/exam_status_models.dart';
import '../services/crm_teacher_api.dart';
import '../services/ems_api_service.dart';
import '../services/offline_snapshot.dart';
import 'api/teacher_exam_status_api.dart';

/// One of my classes with a known exam date from today on.
typedef UpcomingExamClass = ({CrmTeacherClass klass, DateTime examDay});

/// Exam-morning list (T3): my classes' upcoming exams and, per class, the
/// exam status of each student. Status-only copies are kept on the phone
/// for a weak connection on exam morning.
class ExamListRepository {
  const ExamListRepository();

  Future<List<UpcomingExamClass>> upcoming(DateTime today) async {
    final classes = await CrmTeacherApi.classes();
    final day = DateTime(today.year, today.month, today.day);
    final out = <UpcomingExamClass>[];
    for (final c in classes) {
      final d = examDay(c.ngayThi);
      if (d != null && !d.isBefore(day)) out.add((klass: c, examDay: d));
    }
    out.sort((a, b) => a.examDay.compareTo(b.examDay));
    return out;
  }

  /// The calendar day of `ngay_thi` (`yyyy-MM-dd…`), never shifted by zone.
  static DateTime? examDay(String? raw) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw ?? '');
    if (m == null) return null;
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  Future<ExamRosterStatus> roster(String sectionId) async {
    final key = 'exam_status_$sectionId';
    try {
      final r = await TeacherExamStatusApi.roster(sectionId);
      await OfflineSnapshot.save(key, r.toJson());
      return r;
    } on EmsException catch (e) {
      final s = e.statusCode;
      if (s != null && s < 500) {
        await OfflineSnapshot.remove(key); // access changed: never show old
        rethrow;
      }
      return await _saved(key) ?? (throw e);
    } catch (e) {
      return await _saved(key) ?? (throw e);
    }
  }

  Future<ExamRosterStatus?> _saved(String key) async {
    final v = await OfflineSnapshot.load(key);
    final data = v?.data;
    if (v == null || data is! Map<String, dynamic>) return null;
    return ExamRosterStatus.fromJson(data).withSavedAt(v.savedAt);
  }
}
