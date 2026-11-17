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

  /// The id of the last day card closed on this phone (ids carry the date).
  static const _dayCardKey = 'work_home.day_card_closed';

  static Future<String?> dayCardDismissed() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_dayCardKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setDayCardDismissed(String id) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_dayCardKey, id);
    } catch (_) {}
  }
}
