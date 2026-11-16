import 'package:shared_preferences/shared_preferences.dart';

/// Device-local choices of the work home (Overlord slice).
abstract final class HomePrefs {
  /// For an account that is teacher and office: which calendar Lịch opens on.
  static const _lichKey = 'work_home.lich_last';

  static Future<String> lichLast() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_lichKey) ??
          'teach';
    } catch (_) {
      return 'teach';
    }
  }

  static Future<void> setLichLast(String v) async {
    try {
      (await SharedPreferences.getInstance()).setString(_lichKey, v);
    } catch (_) {}
  }
}
