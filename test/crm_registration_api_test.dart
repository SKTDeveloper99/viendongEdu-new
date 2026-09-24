// Đăng ký môn học — phân tích JSON + gọi mạng qua CrmRegistrationApi.
// Fixtures theo hình dạng thật của S3 (đọc) / S5 (ghi), mssv thử nghiệm
// TEST2600001 / "Thử Nghiệm".
//
//   flutter test test/crm_registration_api_test.dart
//
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_registration_models.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_registration_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.emsToken = 'test-token';
  });
  tearDown(() => EmsApiService.client = http.Client());

  group('CrmRegistrationPeriod.fromJson', () {
    test('is_open đọc thẳng từ server, không tự tính lại từ start/end', () {
      final p = CrmRegistrationPeriod.fromJson({
        'period_id': '125',
        'period_code': 'HK261',
        'period_name': 'Học kỳ 1, 2026 -2027',
        'start_at': '2026-08-10T00:00:00.000Z',
        'end_at': '2026-08-21T23:59:59.000Z',
        'is_open': false,
        'semester_code': '261',
      });
      expect(p.periodId, '125');
      expect(p.isOpen, isFalse);
    });
  });

  group('CrmRegistrationOfferingsPage.fromJson', () {
    test('curriculum_resolved=false + in_my_curriculum theo từng dòng', () {
      final page = CrmRegistrationOfferingsPage.fromJson({
        'period_id': '125',
        'semester_code': '261',
        'curriculum_resolved': false,
        'offerings': [
          {
            'offering_id': '169',
            'class_code': '06THC-TEST',
            'subject_code': '2DC003',
            'subject_name': 'Môn thử nghiệm',
            'credits': 3,
            'max_size': 50,
            'registered_count': 10,
            'in_my_curriculum': false,
          },
        ],
      });
      expect(page.curriculumResolved, isFalse);
      expect(page.offerings.single.inMyCurriculum, isFalse);
      expect(page.offerings.single.offeringId, '169');
    });

    test('thiếu curriculum_resolved mặc định coi là đã lọc được (true)', () {
      final page = CrmRegistrationOfferingsPage.fromJson({'offerings': []});
      expect(page.curriculumResolved, isTrue);
      expect(page.offerings, isEmpty);
    });

    test('offerings rỗng không làm vỡ app (đúng thực tế 2026-09-24: 0 dòng)', () {
      final page = CrmRegistrationOfferingsPage.fromJson({
        'period_id': '125',
        'semester_code': '261',
        'offerings': [],
      });
      expect(page.offerings, isEmpty);
    });
  });

  group('CrmRegistrationResult.fromJson', () {
    test('source=ems_request -> nhãn "Đã gửi (EMS)", chưa đồng bộ IMS', () {
      final r = CrmRegistrationResult.fromJson({
        'id': 'req-1',
        'offering_id': '169',
        'subject_name': 'Môn thử nghiệm',
        'status': 'pending',
        'source': 'ems_request',
        'synced_to_ims': false,
      });
      expect(r.isEmsRequest, isTrue);
      expect(r.sourceLabel, 'Đã gửi (EMS)');
      expect(r.syncedToIms, isFalse);
    });

    test('source=ims_roster -> nhãn "Đã xếp lớp"', () {
      final r = CrmRegistrationResult.fromJson({
        'lmh_id': '35790',
        'subject_name': 'Xác suất thống kê',
        'source': 'ims_roster',
      });
      expect(r.isEmsRequest, isFalse);
      expect(r.sourceLabel, 'Đã xếp lớp');
    });
  });

  group('CrmRegistrationApi network', () {
    test('getOfferings mặc định KHÔNG gửi scope=all', () async {
      EmsApiService.client = MockClient((request) async {
        expect(request.url.path, endsWith('/student/me/registration/offerings'));
        expect(request.url.queryParameters['period_id'], '125');
        expect(request.url.queryParameters.containsKey('scope'), isFalse);
        return http.Response(
          jsonEncode({'period_id': '125', 'curriculum_resolved': true, 'offerings': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final page = await CrmRegistrationApi.getOfferings(periodId: '125');
      expect(page.curriculumResolved, isTrue);
    });

    test('getOfferings(allSections: true) gửi scope=all ("Xem tất cả lớp")', () async {
      EmsApiService.client = MockClient((request) async {
        expect(request.url.queryParameters['scope'], 'all');
        return http.Response(
          jsonEncode({'period_id': '125', 'offerings': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      await CrmRegistrationApi.getOfferings(periodId: '125', allSections: true);
    });

    test('register gửi offering_id, đọc recorded_in/synced_to_ims', () async {
      EmsApiService.client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/student/me/registration'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['offering_id'], '169');
        return http.Response(
          jsonEncode({
            'recorded_in': 'ems',
            'synced_to_ims': false,
            'id': 'req-1',
            'mssv': 'TEST2600001',
            'semester_code': '261',
            'offering_id': '169',
            'status': 'pending',
            'submitted_at': '2026-09-24T08:00:00.000Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final res = await CrmRegistrationApi.register('169');
      expect(res.recordedIn, 'ems');
      expect(res.syncedToIms, isFalse);
      expect(res.status, 'pending');
    });

    test('register: lỗi period_closed hiện nguyên văn message máy chủ', () async {
      EmsApiService.client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'registration_period_closed',
            'message': 'Đợt đăng ký đã đóng.',
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(
        () => CrmRegistrationApi.register('169'),
        throwsA(isA<EmsException>()
            .having((e) => e.code, 'code', 'registration_period_closed')
            .having((e) => e.message, 'message', 'Đợt đăng ký đã đóng.')),
      );
    });

    test('cancel DELETE đúng đường dẫn /:id', () async {
      EmsApiService.client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, endsWith('/student/me/registration/req-1'));
        return http.Response(
          jsonEncode({'already_withdrawn': false, 'id': 'req-1', 'status': 'withdrawn'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final res = await CrmRegistrationApi.cancel('req-1');
      expect(res.alreadyWithdrawn, isFalse);
      expect(res.status, 'withdrawn');
    });
  });
}
