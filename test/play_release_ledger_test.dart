import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the next Play upload against the 2026-10-26 mix-up: two different
/// builds both named 6.0.8 (101 tdat535, 102 ours), so phones on 101 looked
/// "up to date" while showing stale attendance.
void main() {
  final ledger =
      (jsonDecode(File('android/play_releases.json').readAsStringSync())
              as Map<String, dynamic>)['releases']
          as List<dynamic>;
  final rows = ledger.cast<Map<String, dynamic>>();

  final pubspec = File('pubspec.yaml').readAsStringSync();
  final name = RegExp(
    r'^version:\s*([0-9.]+)\+',
    multiLine: true,
  ).firstMatch(pubspec)!.group(1)!;
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final code = int.parse(
    RegExp(r'versionCode\s*=\s*(\d+)').firstMatch(gradle)!.group(1)!,
  );

  test('versionCode is new and higher than every recorded upload', () {
    final top = rows
        .map((r) => r['versionCode'] as int)
        .reduce((a, b) => a > b ? a : b);
    final same = rows.where((r) => r['versionCode'] == code).toList();
    if (same.isEmpty) {
      expect(code, greaterThan(top), reason: 'Play refuses lower codes');
    } else {
      // Rebuilding the latest recorded upload is fine; it must match.
      expect(code, top);
      expect(same.single['versionName'], name);
      expect(same.single['line'], 'viendong');
    }
  });

  test('versionName is not shared with a build from another line', () {
    final others = rows
        .where((r) => r['versionName'] == name && r['line'] != 'viendong')
        .map((r) => r['versionCode'])
        .toList();
    expect(
      others,
      isEmpty,
      reason:
          '$name is also versionCode $others from another line; the update '
          'gate compares names, so pick a name nobody else has shipped.',
    );
  });

  test('versionName is not below a name already on Play', () {
    List<int> parts(String v) => v.split('.').map(int.parse).toList();
    int cmp(String a, String b) {
      final x = parts(a), y = parts(b);
      for (var i = 0; i < 3; i++) {
        if (x[i] != y[i]) return x[i] - y[i];
      }
      return 0;
    }

    // "legacy" 6.1.0 (91) predates the gate; it is retired with
    // android_min_build, not by name.
    for (final r in rows.where((r) => r['line'] != 'legacy')) {
      expect(
        cmp(name, r['versionName'] as String),
        greaterThanOrEqualTo(0),
        reason: '$name is below ${r['versionName']} (${r['versionCode']})',
      );
    }
  });
}
