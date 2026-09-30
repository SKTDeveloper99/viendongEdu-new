import '../services/app_session.dart';
import '../services/crm_teacher_api.dart';
import '../services/ems_api_service.dart';

typedef CachedOverview = ({
  CrmTeacherOverview data,
  DateTime savedAt,
  bool fresh,
});

/// Wraps the calls the teacher home screen makes, unchanged:
/// `GET /api/teacher/me/overview` (ETag-cached on disk) and
/// `GET /api/teacher/notifications/unread-count`, plus the session identity.
/// Any failure surfaces as the original exception.
class TeacherHomeRepository {
  const TeacherHomeRepository();

  /// Profile + today's sessions; [onStored] paints the stored copy first.
  Future<CachedOverview> overview({
    void Function(CrmTeacherOverview o, DateTime savedAt)? onStored,
  }) => CrmTeacherApi.overviewCached(onStored: onStored);

  Future<int> unreadCount() => EmsApiService.teacherUnreadCount();

  // Identity always comes from the CRM login session (no network needed).
  String get teacherId => AppSession.instance.teacherId ?? '';
  String? get fullName => AppSession.instance.fullName;
  String? get teacherCode => AppSession.instance.teacherCode;
  bool get hasEms => AppSession.instance.hasEms;

  Future<void> clearSession() => AppSession.instance.clear();
}
