// Sửa hồ sơ cá nhân — phân tích JSON + gọi PATCH qua CrmProfileApi.
// Fixtures theo hình dạng thật S5 §2, mssv thử nghiệm TEST2600001.
//
//   flutter test test/crm_profile_api_test.dart
//
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_profile_models.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_profile_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.emsToken = 'test-token';
  });
  tearDown(() => EmsApiService.client = http.Client());

  group('CrmStudentProfile', () {
    test('fromGetMeJson đọc {student:{...}}, KHÔNG có cccd ở endpoint đọc', () {
      final p = CrmStudentProfile.fromGetMeJson({
        'student': {
          'mssv': 'TEST2600001',
          'full_name': 'Thử Nghiệm',
          'email': 'thunghiem@thunghiem.test',
          'phone': '0900000000',
        },
      });
      expect(p.mssv, 'TEST2600001');
      expect(p.email, 'thunghiem@thunghiem.test');
      // Endpoint GET /api/student/me hiện không trả cccd — cmnd phải là
      // null, không phải rỗng bị hiểu nhầm hay bịa ra một giá trị.
      expect(p.cmnd, isNull);
    });

    test('fromPatchJson đọc field sdt/cmnd (alias) từ phản hồi PATCH', () {
      final p = CrmStudentProfile.fromPatchJson({
        'recorded_in': 'ems',
        'synced_to_ims': false,
        'mssv': 'TEST2600001',
        'email': 'moi@thunghiem.test',
        'sdt': '0911111111',
        'cmnd': '012345678901',
      });
      expect(p.email, 'moi@thunghiem.test');
      expect(p.phone, '0911111111');
      expect(p.cmnd, '012345678901');
    });
  });

  group('CrmTeacherProfile', () {
    test('fromGetMeJson đọc {teacher:{...}}', () {
      final p = CrmTeacherProfile.fromGetMeJson({
        'teacher': {
          'teacher_id': '99',
          'teacher_code': 'GV-TEST',
          'name': 'Thử Nghiệm',
          'email': 'gv@thunghiem.test',
          'phone': '0922222222',
        },
      });
      expect(p.teacherId, '99');
      expect(p.fullName, 'Thử Nghiệm');
      expect(p.email, 'gv@thunghiem.test');
    });

    test('fromPatchJson đọc teacher_id/sdt từ phản hồi PATCH', () {
      final p = CrmTeacherProfile.fromPatchJson({
        'recorded_in': 'ems',
        'synced_to_ims': false,
        'teacher_id': '99',
        'email': 'gv2@thunghiem.test',
        'sdt': '0933333333',
      });
      expect(p.teacherId, '99');
      expect(p.phone, '0933333333');
    });
  });

  group('CrmProfileApi network', () {
    test('getStudentMe GET đúng đường dẫn /student/me', () async {
      EmsApiService.client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, endsWith('/student/me'));
        return http.Response(
          jsonEncode({'student': {'mssv': 'TEST2600001', 'email': 'a@thunghiem.test'}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = await CrmProfileApi.getStudentMe();
      expect(p.mssv, 'TEST2600001');
    });

    test('updateStudentProfile gửi PATCH thật (không phải GET/POST) tới /student/me/profile', () async {
      EmsApiService.client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, endsWith('/student/me/profile'));
        expect(request.headers['Authorization'], 'Bearer test-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'moi@thunghiem.test');
        expect(body.containsKey('sdt'), isFalse); // không gửi trường trống
        return http.Response(
          jsonEncode({
            'recorded_in': 'ems',
            'synced_to_ims': false,
            'mssv': 'TEST2600001',
            'email': 'moi@thunghiem.test',
            'sdt': null,
            'cmnd': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = await CrmProfileApi.updateStudentProfile(email: 'moi@thunghiem.test');
      expect(p.email, 'moi@thunghiem.test');
    });

    test('updateTeacherProfile PATCH tới /teacher/me/profile', () async {
      EmsApiService.client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, endsWith('/teacher/me/profile'));
        return http.Response(
          jsonEncode({
            'recorded_in': 'ems',
            'synced_to_ims': false,
            'teacher_id': '99',
            'email': 'gv@thunghiem.test',
            'sdt': '0933333333',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = await CrmProfileApi.updateTeacherProfile(sdt: '0933333333');
      expect(p.phone, '0933333333');
    });

    test('400 validate hiện nguyên văn thông điệp máy chủ', () async {
      EmsApiService.client = MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'Email không đúng định dạng.'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(
        () => CrmProfileApi.updateStudentProfile(email: 'sai-dinh-dang'),
        throwsA(isA<EmsException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', 'Email không đúng định dạng.')),
      );
    });
  });
}
