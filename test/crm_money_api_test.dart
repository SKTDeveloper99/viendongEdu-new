// Học phí / lệ phí / cấp bù — phân tích JSON và gọi mạng qua CrmMoneyApi.
// Fixtures dựng theo hình dạng thật của S4 (docs/api/mobile-ims-replacement-
// S4.md), chỉ đổi mssv/tên sang dữ liệu thử nghiệm (TEST2600001, Thử Nghiệm).
//
//   flutter test test/crm_money_api_test.dart
//
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_money_capbu.dart';
import 'package:viendongedu2_flutter/models/crm_money_fees.dart';
import 'package:viendongedu2_flutter/models/crm_money_tuition.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_money_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.emsToken = 'test-token';
  });
  tearDown(() => EmsApiService.client = http.Client());

  group('CrmTuitionResponse.fromJson', () {
    test('đọc summary đã áp luật + payments, không tự tính lại', () {
      final r = CrmTuitionResponse.fromJson({
        'mssv': 'TEST2600001',
        'summary': {
          'owedTotal': 10000000,
          'paid': 4000000,
          'balance': 6000000,
          'payment_status': 'Còn nợ',
          'other_receipts': {
            'mien_giam_khen_thuong': 200000,
            'le_phi_khac': 100000,
            'hoan_phi': 0,
            'total': 300000,
          },
          'money_known': true,
        },
        'payments': [
          {
            'phieu_thu_id': '1',
            'so_tien': 4000000,
            'ngay_nop': '2026-09-01T00:00:00.000Z',
            'ghi_chu': 'Đóng học phí HK1',
            'semester_code': '261',
            'loai_phieu_thu': 'Học phí',
          },
        ],
      });

      expect(r.summary.owedTotal, 10000000);
      expect(r.summary.balance, 6000000);
      expect(r.summary.moneyKnown, isTrue);
      expect(r.summary.otherReceipts.mienGiamKhenThuong, 200000);
      expect(r.payments, hasLength(1));
      expect(r.payments.first.loaiPhieuThu, 'Học phí');
    });

    test('money_known=false giữ nguyên "chưa có luật", không suy ra 0', () {
      final r = CrmTuitionResponse.fromJson({
        'mssv': 'TEST2600001',
        'summary': {
          'owedTotal': null,
          'money_known': false,
          'money_unknown_reason': 'CD15 K5-K8 chưa có giá 261.',
        },
        'payments': [],
      });
      expect(r.summary.moneyKnown, isFalse);
      expect(r.summary.owedTotal, isNull);
      expect(r.summary.moneyUnknownReason, contains('chưa có giá'));
    });

    test('thiếu trường không làm vỡ app', () {
      final r = CrmTuitionResponse.fromJson({});
      expect(r.summary.owedTotal, isNull);
      expect(r.payments, isEmpty);
    });
  });

  group('CrmCongNo.fromJson', () {
    test('null nghĩa là chưa có nghĩa vụ, có note đi kèm', () {
      final c = CrmCongNo.fromJson({
        'mssv': 'TEST2600001',
        'phai_nop': null,
        'da_nop': null,
        'cong_no': null,
        'computable': false,
        'has_money_rows': false,
        'note': 'Chưa có nghĩa vụ học phí được ghi nhận trong hệ thống tại thời điểm này.',
      });
      expect(c.computable, isFalse);
      expect(c.phaiNop, isNull);
      expect(c.note, isNotNull);
    });
  });

  group('CrmFeesResponse.fromJson', () {
    test('đọc totals/by_type/items và cờ nhiễm dữ liệu', () {
      final r = CrmFeesResponse.fromJson({
        'mssv': 'TEST2600001',
        'totals': {
          'le_phi_khac': 1000000,
          'mien_giam_khen_thuong': 200000,
          'hoan_phi': 0,
          'phat_sinh_charges': 0,
          'paid_side_contaminated': false,
        },
        'by_type': [
          {'type_id': 162, 'type_name': 'Lệ phí', 'bucket': 'le_phi_khac', 'tong': 1000000, 'so_lan': 2},
        ],
        'items': [
          {
            'phieu_thu_id': '9',
            'semester_code': '261',
            'so_tien': 500000,
            'ngay_nop': '2026-09-10T00:00:00.000Z',
            'loai_phieu_thu_id': 162,
            'loai_phieu_thu': 'Lệ phí',
            'ledger': 'OTHER_FEE',
          },
        ],
      });
      expect(r.totals.lePhiKhac, 1000000);
      expect(r.totals.paidSideContaminated, isFalse);
      expect(r.byType.single.typeName, 'Lệ phí');
      expect(r.items.single.ledger, 'OTHER_FEE');
    });

    test('phat_sinh_charges khác 0 -> cờ nhiễm phải bật', () {
      final r = CrmFeesResponse.fromJson({
        'totals': {'phat_sinh_charges': 50000, 'paid_side_contaminated': true},
      });
      expect(r.totals.paidSideContaminated, isTrue);
    });
  });

  group('CrmCapBuResponse.fromJson', () {
    test('mirror IMS nguyên văn, cột tiền chuỗi rỗng -> null không phải 0', () {
      final r = CrmCapBuResponse.fromJson({
        'mssv': 'TEST2600001',
        'count': 1,
        'items': [
          {
            'id': '1', 'ma': 'M1', 'ten': 'HP HK1', 'ky_hieu': 'K1',
            'ngay_cap': '2026-01-19T00:00:00.000Z',
            'don_gia': 10200000, 'thanh_tien': 10200000, 'vat': '',
            'total': 10200000, 'ghi_chu': null,
            'hocky_id': '76', 'hocky_ten': 'Học kỳ 1, 2025 - 2026',
          },
        ],
      });
      expect(r.count, 1);
      expect(r.items.single.vat, isNull);
      expect(r.items.single.hocKyTen, 'Học kỳ 1, 2025 - 2026');
    });
  });

  group('CrmMoneyApi network', () {
    test('getFees gọi đúng đường dẫn và trả CrmFeesResponse', () async {
      EmsApiService.client = MockClient((request) async {
        expect(request.url.path, endsWith('/student/me/fees'));
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({'mssv': 'TEST2600001', 'totals': {}, 'items': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final r = await CrmMoneyApi.getFees();
      expect(r.mssv, 'TEST2600001');
    });

    test('getCapBu gọi đúng đường dẫn', () async {
      EmsApiService.client = MockClient((request) async {
        expect(request.url.path, endsWith('/student/me/capbu'));
        return http.Response(
          jsonEncode({'mssv': 'TEST2600001', 'count': 0, 'items': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final r = await CrmMoneyApi.getCapBu();
      expect(r.count, 0);
    });

    test('404 ném EmsException với thông điệp máy chủ nguyên văn', () async {
      EmsApiService.client = MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'Student not found'}),
          404,
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(
        () => CrmMoneyApi.getTuition(),
        throwsA(isA<EmsException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });
}
