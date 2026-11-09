import '../models/crm_student_schedule.dart';
import '../models/crm_student_exams.dart';
import '../services/app_session.dart';
import '../services/crm_student_api.dart';
import '../services/ems_api_service.dart';
import 'api/board_api.dart';

typedef CachedSchedule = ({
  List<CrmScheduleItem> data,
  DateTime savedAt,
  bool fresh,
});

/// The schedule read with its "Môn chưa có lịch" list (`chua_co_lich`).
typedef CachedScheduleView = ({
  CrmStudentScheduleView data,
  DateTime savedAt,
  bool fresh,
});

typedef CachedBoard = ({
  List<AnnouncementItem> data,
  DateTime savedAt,
  bool fresh,
});

/// Wraps the calls the student home screen makes, unchanged:
/// `GET /api/student/me/schedule` and `GET /api/v1/student/board` (both
/// ETag-cached on disk), `GET /api/student/me`,
/// `GET /api/v1/student/board/unread-count`, plus the session identity.
/// Any failure surfaces as the original exception.
class StudentHomeRepository {
  const StudentHomeRepository();

  /// Full schedule (every semester) plus the subjects whose timetable is not
  /// published yet; [onStored] paints the stored copy first.
  Future<CachedScheduleView> schedule({
    void Function(CrmStudentScheduleView view, DateTime savedAt)? onStored,
  }) => CrmStudentApi.scheduleViewCached(onStored: onStored);

  Future<({CrmStudentExamsView data, DateTime savedAt, bool fresh})> exams() =>
      CrmStudentApi.examsCached();

  /// The 20 latest board items; [onStored] paints the stored copy first.
  Future<CachedBoard> board({
    void Function(List<AnnouncementItem> items, DateTime savedAt)? onStored,
  }) => BoardApi.boardCached(limit: 20, onStored: onStored);

  Future<BoardUnread> unreadCount() => BoardApi.unreadCount();

  /// Class code for the header (not part of the login session).
  Future<String?> classCode() async => (await CrmStudentApi.me()).classCode;

  // Identity always comes from the CRM login session.
  String? get fullName => AppSession.instance.fullName;
  String? get mssv => AppSession.instance.mssv;
  bool get hasEms => AppSession.instance.hasEms;

  /// True when EMS DELIBERATELY denied this student (no account/deactivated).
  bool get emsDenied => AppSession.instance.emsDenied;

  Future<void> clearSession() => AppSession.instance.clear();
}
