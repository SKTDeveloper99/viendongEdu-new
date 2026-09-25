import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// IMS đã bị gỡ hoàn toàn khỏi app (bot A5, 2026-09). Test này đỏ nếu ai đó
/// thêm lại client IMS (`api_service.dart`, host `ims-api.viendong.edu.vn`)
/// hoặc gọi thẳng các endpoint IMS cũ.
///
/// Cùng đợt (2026-09-25): mọi backend Vercel (`noti-backend-eight` — chuông
/// thông báo cũ; `tuyensinhcd-dh` — không tìm thấy trong `lib/`, xem báo cáo)
/// cũng đã bị gỡ. Test đỏ nếu bất kỳ `*.vercel.app` nào quay lại — kể cả
/// trong chú thích, để không ai chép lại URL đó "cho chắc".
void main() {
  String read(String p) => File(p).readAsStringSync();

  test('no file named api_service.dart in lib/', () {
    final dir = Directory('lib');
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      expect(
        f.path.endsWith('/api_service.dart') || f.path == 'api_service.dart',
        isFalse,
        reason: f.path,
      );
    }
  });

  test('no reference to the IMS host or IMS endpoints in lib/', () {
    final dir = Directory('lib');
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = read(f.path);
      // Host thật thì không được xuất hiện dù trong chú thích hay không.
      expect(src.contains('ims-api.viendong.edu.vn'), isFalse, reason: f.path);
      // `ApiService.xxx` chỉ bị cấm ở CODE — nhiều chú thích lịch sử ("thay
      // ApiService.getTuition...") cố tình được giữ lại (xem CLAUDE.md task
      // brief), nên bỏ dòng chú thích trước khi kiểm tra, giống
      // `ems_purge_guard_test.dart`.
      final code = src.replaceAll(RegExp(r'//.*'), '');
      expect(RegExp(r'\bApiService\.').hasMatch(code), isFalse, reason: f.path);
    }
  });

  test('IMS-only models are gone from the tree', () {
    expect(File('lib/models/hoc_vien_model.dart').existsSync(), isFalse);
    expect(File('lib/models/giang_vien_model.dart').existsSync(), isFalse);
    expect(File('lib/services/api_service.dart').existsSync(), isFalse);
  });

  test('AppSession carries no legacy IMS fields', () {
    final src = read('lib/services/app_session.dart');
    // Bỏ dòng chú thích: lịch sử được phép nhắc tên, mã thì không.
    final code = src.replaceAll(RegExp(r'//.*'), '');
    expect(RegExp(r'\bHocVien\b').hasMatch(code), isFalse);
    expect(RegExp(r'\bGiangVien\b').hasMatch(code), isFalse);
    expect(RegExp(r'String\? token;').hasMatch(code), isFalse);
    expect(RegExp(r'String\? userid;').hasMatch(code), isFalse);
  });

  test('no *.vercel.app host anywhere in lib/, code or comments', () {
    final dir = Directory('lib');
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = read(f.path);
      expect(src.toLowerCase().contains('vercel.app'), isFalse, reason: f.path);
    }
  });
}
