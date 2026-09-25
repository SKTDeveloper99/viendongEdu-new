import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/models/mock_data.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EmsApiService.client = http.Client();
    final session = AppSession.instance;
    session
      ..emsToken = null
      ..emsDenied = false
      ..role = null
      ..mssv = null
      ..teacherId = null
      ..teacherCode = null
      ..fullName = null
      ..mustChangePassword = false;
  });

  tearDown(() => EmsApiService.client = http.Client());

  // 6.1.0: đăng nhập không còn đi qua IMS, nên không còn "đối chiếu lại"
  // (identity mirror) khi token EMS hết hạn — không còn token IMS đứng sau
  // để đối chiếu. refreshEmsToken() giờ chỉ còn là một shim tương thích cho
  // các màn hình sóng 2 (splash/schedule) chưa được sửa: nó không gọi mạng,
  // chỉ trả về trạng thái hiện có.
  test('refreshEmsToken is a no-network compatibility shim now', () async {
    expect(await AppSession.instance.refreshEmsToken(), isFalse);

    AppSession.instance.emsToken = 'a-real-token';
    expect(await AppSession.instance.refreshEmsToken(), isTrue);
  });

  test('refreshEmsToken(force: true) clears a stale denial flag but still '
      'makes no network call', () async {
    AppSession.instance.emsDenied = true;
    expect(await AppSession.instance.refreshEmsToken(force: true), isFalse);
    expect(AppSession.instance.emsDenied, isFalse);
  });

  test('applyIdentity + persist + tryRestore round-trips a CRM session', () async {
    final identity = CrmIdentity(
      role: CrmRole.student,
      token: 'crm-token-1',
      mssv: '2600001234',
      fullName: 'Nguyễn Văn A',
      mustChangePassword: false,
    );
    AppSession.instance.applyIdentity(identity);
    await AppSession.instance.persist();

    // Xoá sạch bộ nhớ, chỉ còn SharedPreferences đã lưu ở trên.
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..mssv = null
      ..fullName = null;

    final restored = await AppSession.instance.tryRestore();
    expect(restored, isTrue);
    expect(AppSession.instance.isLoggedIn, isTrue);
    expect(AppSession.instance.role, CrmRole.student);
    expect(AppSession.instance.mssv, '2600001234');
    expect(AppSession.instance.fullName, 'Nguyễn Văn A');
  });

  test('a bare IMS token with no CRM identity does not count as logged in', () async {
    final prefs = await SharedPreferences.getInstance();
    // Giả lập một bản cài đặt CŨ (trước 6.1.0): có token IMS nhưng chưa từng
    // có 'crm_identity'.
    await prefs.setString('auth_token', 'stale-ims-token');

    final restored = await AppSession.instance.tryRestore();
    expect(restored, isFalse);
    expect(AppSession.instance.isLoggedIn, isFalse);
  });

  test('teacher schedule cannot fall back to an IMS attendance writer', () {
    final source = File(
      'lib/screens/gv_schedule_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('GvAttendanceScreen')));
    expect(source, isNot(contains('GvQrAttendanceScreen')));
    expect(source, isNot(contains('postDiemDanhLuu')));
    expect(source, contains('EmsAttendanceTeacherScreen'));
  });

  test('student home has a one-tap attendance destination', () {
    final attendance = MockData.menuItems.where(
      (item) => item['route'] == '/ems_attendance_hv',
    );
    expect(attendance, hasLength(1));
    expect(attendance.single['label'], 'Điểm danh');
  });
}
