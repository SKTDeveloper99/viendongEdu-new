// Teacher-side contrast (ui-dark-mode items 9, 10, 14, 15). Source checks
// keep the fixes from drifting back; visual checks are in the goldens.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _src(String path) => File(path).readAsStringSync();

void main() {
  test('date pickers follow the app theme (no forced light scheme)', () {
    for (final p in [
      'lib/screens/gv_schedule_screen.dart',
      'lib/screens/schedule_screen.dart',
    ]) {
      expect(_src(p).contains('ColorScheme.light('), isFalse, reason: p);
    }
  });

  test('teacher text no longer uses the faint ink (2.9:1 / 3.6:1)', () {
    for (final p in [
      'lib/screens/gv_lophoc_screen.dart',
      'lib/screens/gv_schedule_screen.dart',
      'lib/screens/gv_lichthi_screen.dart',
      'lib/features/teacher_attendance/schedule_card.dart',
    ]) {
      expect(_src(p).contains('inkFaint'), isFalse, reason: p);
    }
  });

  test('Lịch thi divider is visible; roster avatar uses the theme', () {
    expect(
      _src(
        'lib/screens/gv_lichthi_screen.dart',
      ).contains('Divider(height: 1, color: context.vd.surfaceAlt)'),
      isFalse,
    );
    expect(
      _src(
        'lib/features/class_manager/widgets/class_students_tab.dart',
      ).contains('0xFFE65100'),
      isFalse,
    );
  });
}
