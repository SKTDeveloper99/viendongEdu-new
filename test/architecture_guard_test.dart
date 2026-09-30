// Architecture guard — see docs/ARCHITECTURE.md.
//
//   flutter test test/architecture_guard_test.dart
//
// The allowlist below may only SHRINK: when a file is split or migrated,
// delete its entry. A listed file that grows past its recorded line count
// fails, and so does a stale entry whose file got small enough (or vanished).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _maxLines = 400;
const _maxScreenLines = 250;
const _maxWidgetLines = 200;

/// Files that were already over [_maxLines] when the guard was introduced,
/// with their line count at that time.
const Map<String, int> _allowlist = {
  'lib/screens/gv_quanly_lop_screen.dart': 1388,
  'lib/screens/ems_attendance_teacher_screen.dart': 1215,
  'lib/services/ems_api_service.dart': 1186,
  'lib/screens/teacher_my_day_screen.dart': 668,
  'lib/screens/registration_screen.dart': 653,
  'lib/screens/schedule_screen.dart': 642,
  'lib/screens/student_questions_screen.dart': 583,
  'lib/screens/gv_schedule_screen.dart': 571,
  'lib/screens/student_board_screen.dart': 490,
  'lib/screens/tuition_screen.dart': 482,
  'lib/screens/gv_lichthi_screen.dart': 468,
  'lib/services/notification_service.dart': 453,
  'lib/screens/gv_lophoc_screen.dart': 451,
  'lib/screens/exam_screen.dart': 412,
};

List<File> _dartFiles(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) return [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _rel(File f) => f.path.replaceAll('\\', '/');

int _lines(File f) => f.readAsLinesSync().length;

void main() {
  test('no lib file exceeds $_maxLines lines (allowlist may only shrink)', () {
    final problems = <String>[];
    for (final f in _dartFiles('lib')) {
      final path = _rel(f);
      final n = _lines(f);
      final allowed = _allowlist[path];
      if (allowed == null) {
        if (n > _maxLines) problems.add('$path has $n lines (max $_maxLines)');
      } else if (n > allowed) {
        problems.add('$path grew to $n lines (allowlist records $allowed)');
      }
    }
    for (final e in _allowlist.entries) {
      final f = File(e.key);
      if (!f.existsSync()) {
        problems.add('${e.key} no longer exists: remove it from the allowlist');
      } else if (_lines(f) <= _maxLines) {
        problems.add('${e.key} is now within $_maxLines lines: remove it from '
            'the allowlist');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('feature screens and widgets stay small', () {
    final problems = <String>[];
    for (final f in _dartFiles('lib/features')) {
      final path = _rel(f);
      final n = _lines(f);
      if (path.contains('/widgets/')) {
        if (n > _maxWidgetLines) {
          problems.add('$path has $n lines (widgets max $_maxWidgetLines)');
        }
      } else if (path.endsWith('_screen.dart') && n > _maxScreenLines) {
        problems.add('$path has $n lines (screens max $_maxScreenLines)');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('feature view models import only foundation, never material/widgets',
      () {
    final banned = RegExp(
        r'''import\s+['"]package:flutter/(material|widgets)\.dart['"]''');
    final problems = <String>[];
    for (final f in _dartFiles('lib/features')) {
      final path = _rel(f);
      if (!path.endsWith('_view_model.dart')) continue;
      if (banned.hasMatch(f.readAsStringSync())) {
        problems.add('$path imports material.dart or widgets.dart');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('feature views never touch the API services directly', () {
    final banned = RegExp(r'\b(EmsApiService|CrmStudentApi|CrmTeacherApi)\b');
    final problems = <String>[];
    for (final f in _dartFiles('lib/features')) {
      final path = _rel(f);
      final isView =
          path.endsWith('_screen.dart') || path.contains('/widgets/');
      if (!isView) continue;
      if (banned.hasMatch(f.readAsStringSync())) {
        problems.add('$path references EmsApiService/CrmStudentApi/'
            'CrmTeacherApi');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
