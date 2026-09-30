import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/services/theme_controller.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('default is light with nothing stored', () async {
    final c = ThemeController.forTest();
    expect(c.value, ThemeMode.light);
    await c.load();
    expect(c.value, ThemeMode.light);
  });

  test('persistence round-trip for every mode', () async {
    for (final mode in ThemeMode.values) {
      await ThemeController.forTest().set(mode);
      final fresh = ThemeController.forTest();
      await fresh.load();
      expect(fresh.value, mode);
    }
  });

  test('unknown stored value falls back to light', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
    final c = ThemeController.forTest();
    await c.load();
    expect(c.value, ThemeMode.light);
  });
}
