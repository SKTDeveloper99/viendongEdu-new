import '../../services/ems_api_service.dart';
import '../../services/ems_attendance_cache.dart';

class OfflineRosterState {
  const OfflineRosterState(this.draft, this.banner);

  final EmsAttendanceDraft draft;
  final String banner;
}

/// Transport/server failures may use a non-empty draft for this exact session.
OfflineRosterState? offlineRosterFromFailure(
  EmsException error,
  EmsAttendanceDraft? draft,
  EmsSession session,
) {
  final status = error.statusCode;
  final transient = status == null || status >= 500 || error.code == 'invalid_response';
  if (!transient ||
      draft == null ||
      draft.students.isEmpty ||
      draft.session?.sessionKey != session.sessionKey) {
    return null;
  }
  final savedAt = draft.savedAt?.toLocal();
  final time = savedAt == null
      ? '--:--'
      : '${savedAt.hour.toString().padLeft(2, '0')}:'
            '${savedAt.minute.toString().padLeft(2, '0')}';
  return OfflineRosterState(
    draft,
    'Đang ngoại tuyến – danh sách lưu lúc $time (dữ liệu cũ). '
    'Điểm danh sẽ tự gửi khi có mạng.',
  );
}
