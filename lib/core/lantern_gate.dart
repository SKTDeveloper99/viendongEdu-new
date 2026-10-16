import 'remote/app_remote_config.dart';

/// Lantern + Infinite release (owner 2026-10-14): the test app shows student
/// data only to MSSV prefixes ≥ [AppRemoteConfig.minPrefix] (25). Everyone
/// else sees "Không có dữ liệu" on the data screens; the board, questions and
/// the game stay on. Lower `lantern_min_prefix` in Remote Config to reopen.
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
    'Không có dữ liệu — bản thử nghiệm hiện chỉ mở cho sinh viên khóa 25 trở về sau.';

/// True when [mssv] may see student data. Unknown MSSV (teacher, signed out)
/// is not gated here; the student screens are reached only by students.
bool studentDataOpen(String? mssv, {int? minPrefix}) {
  final m = mssv?.trim() ?? '';
  if (m.isEmpty) return true;
  final p = m.length >= 2 ? int.tryParse(m.substring(0, 2)) : null;
  return p != null && p >= (minPrefix ?? AppRemoteConfig.minPrefix);
}
