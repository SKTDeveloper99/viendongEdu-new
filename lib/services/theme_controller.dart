import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Giao diện sáng/tối của app. Mặc định SÁNG (không theo máy) — chủ trường
/// yêu cầu; người dùng có thể đổi trong tab "Cá nhân" và lựa chọn được nhớ.
///
/// Chỉ là trạng thái trình bày: không gọi mạng, không đụng phiên đăng nhập.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.light);

  /// Dùng riêng cho test, để không dính singleton.
  @visibleForTesting
  ThemeController.forTest() : super(ThemeMode.light);

  static final ThemeController instance = ThemeController._();

  static const prefsKey = 'theme_mode';

  /// Đọc lựa chọn đã lưu. Lỗi đọc prefs hoặc giá trị lạ → giữ SÁNG.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = decode(prefs.getString(prefsKey));
    } catch (e) {
      debugPrint('[Theme] load failed: $e');
      value = ThemeMode.light;
    }
  }

  /// Đổi giao diện ngay, rồi lưu. Lưu lỗi thì vẫn giữ lựa chọn trong phiên.
  Future<void> set(ThemeMode mode) async {
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, encode(mode));
    } catch (e) {
      debugPrint('[Theme] save failed: $e');
    }
  }

  static String encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  static ThemeMode decode(String? raw) => switch (raw) {
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.light,
  };

  /// Nhãn tiếng Việt hiển thị trong menu.
  static String label(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Sáng',
    ThemeMode.dark => 'Tối',
    ThemeMode.system => 'Theo máy',
  };
}
