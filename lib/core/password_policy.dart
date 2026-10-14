/// Mirror of the server's new-password rules, checked before sending so the
/// student sees the reason under the field instead of a silent 400.
/// Students: `assertPasswordPolicy` (portals-student-portal-service.js);
/// teachers/staff: `changePassword` (auth-service.js) — 8+ characters only.
String? newPasswordProblem(
  String next, {
  required String current,
  String? mssv,
  required bool student,
}) {
  if (next.isEmpty) return 'Vui lòng nhập mật khẩu mới';
  if (student) {
    final m = (mssv ?? '').trim().toLowerCase();
    if (m.isNotEmpty && next.toLowerCase().contains(m)) {
      return 'Mật khẩu mới không được chứa mã số sinh viên';
    }
  }
  if (next.length < 8) return 'Mật khẩu mới phải có ít nhất 8 ký tự';
  if (student &&
      (!RegExp(r'[A-Za-zÀ-ỹ]').hasMatch(next) ||
          !RegExp(r'[0-9]').hasMatch(next))) {
    return 'Mật khẩu mới phải có cả chữ và số';
  }
  if (next == current) return 'Mật khẩu mới phải khác mật khẩu hiện tại';
  return null;
}
