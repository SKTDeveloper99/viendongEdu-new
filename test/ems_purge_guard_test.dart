import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// EMS là nơi duy nhất ghi điểm danh (2026-09-11). Bất kỳ ai thêm lại đường
/// ghi IMS hay huy hiệu điểm danh lấy từ IMS sẽ làm test này đỏ.
void main() {
  String read(String p) => File(p).readAsStringSync();

  test('legacy IMS attendance screens are gone from the tree', () {
    expect(File('lib/screens/gv_attendance_screen.dart').existsSync(), isFalse);
    expect(File('lib/screens/gv_qr_attendance_screen.dart').existsSync(), isFalse);
    expect(File('lib/services/zk_api_service.dart').existsSync(), isFalse);
  });

  test('no screen calls the IMS attendance write endpoint', () {
    final dir = Directory('lib');
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      // Bỏ dòng chú thích: lịch sử được phép nhắc tên, mã thì không.
      final src = read(f.path).replaceAll(RegExp(r'//.*'), '');
      expect(src.contains('giangvien/diemdanh/luu'), isFalse, reason: f.path);
      expect(RegExp(r'ApiService\.postDiemDanhLuu\(').hasMatch(src), isFalse, reason: f.path);
    }
  });

  test('student Lịch học badge is computed from EMS, never from IMS hienDienYN', () {
    final src = read('lib/screens/schedule_screen.dart');
    expect(src.contains("data['hienDienYN']"), isFalse);
    expect(src.contains('EmsApiService.myAttendance'), isTrue);
  });

  test('teacher Quản lý lớp session detail reads EMS session-marks', () {
    final src = read('lib/screens/gv_quanly_lop_screen.dart');
    expect(src.contains('EmsApiService.sessionMarks('), isTrue);
  });

  test('splash runs the force-update gate first', () {
    final src = read('lib/screens/splash_screen.dart');
    final gate = src.indexOf('AppUpdateGate.check(context)');
    final restore = src.indexOf('AppSession.instance.tryRestore()');
    expect(gate, greaterThan(0));
    expect(gate, lessThan(restore));
  });
}
