import 'remote/app_remote_config.dart';

/// Lantern + Infinite release (owner 2026-10-14): the app can show student
/// data only to MSSV prefixes ≥ [AppRemoteConfig.minPrefix]. Owner 2026-10-22:
/// open by default (0 = everyone); the server's `data_open` decides first,
/// and the server fences what each student actually receives. Raise
/// `lantern_min_prefix` in Remote Config to close again.
const dataRoutes = {
  '/schedule',
  '/exam',
  '/registration',
  '/grades',
  '/ems_attendance_hv',
  '/classes',
  '/tuition',
  '/lephi',
  '/capbu',
};

const noDataText =
    'Không có dữ liệu — lớp của bạn sẽ được mở trong đợt tiếp theo.';

/// True when [mssv] may see student data. Unknown MSSV (teacher, signed out)
/// is not gated here; the student screens are reached only by students.
bool studentDataOpen(String? mssv, {int? minPrefix, bool? serverDataOpen}) {
  if (serverDataOpen != null) return serverDataOpen;
  final min = minPrefix ?? AppRemoteConfig.minPrefix;
  if (min <= 0) return true;
  final m = mssv?.trim() ?? '';
  if (m.isEmpty) return true;
  final p = m.length >= 2 ? int.tryParse(m.substring(0, 2)) : null;
  return p != null && p >= min;
}
