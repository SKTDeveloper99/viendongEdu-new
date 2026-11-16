import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local choices of the work home (Overlord slice).
abstract final class HomePrefs {
  /// Debug only: the home with or without its bottom bar, for the owner to
  /// compare on the simulator. Release builds always keep the bar.
  static final ValueNotifier<bool> bottomBar = ValueNotifier(true);

  /// For an account that is teacher and office: which calendar Lịch opens on.
  static const _lichKey = 'work_home.lich_last';
  static const _barKey = 'work_home.debug_bottom_bar';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      bottomBar.value = kDebugMode ? (p.getBool(_barKey) ?? true) : true;
    } catch (_) {}
  }

  static Future<void> setBottomBar(bool v) async {
    bottomBar.value = v;
    try {
      (await SharedPreferences.getInstance()).setBool(_barKey, v);
    } catch (_) {}
  }

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
