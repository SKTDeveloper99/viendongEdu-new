// Bảng tin — phân tích JSON, trạng thái đọc/xác nhận, và hành vi lỗi của EMS.
//
// Không chạm mạng: chỉ kiểm tra phần thuần logic, thứ phải đúng trước khi bàn
// tới giao diện. Các trường hợp mạng thật (401 → đối chiếu lại, 403 dứt khoát)
// được kiểm tra qua EmsException, đúng cái mà lớp gọi đọc để quyết định.
//
//   flutter test test/ems_board_test.dart
//
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  group('AnnouncementItem.fromJson', () {
    test('đọc đủ trường và giữ NGUYÊN VĂN phần nội dung', () {
      final item = AnnouncementItem.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'title': 'Thông báo lịch: buổi học bù',
        'body': 'Chào Lê Văn A (Lớp 18QTTHC),\n\nThời gian: thứ Bảy 13/09/2026',
        'category': 'schedule',
        'must_read': true,
        'is_correction': false,
        'published_at': '2026-09-01T10:00:00.000Z',
        'read_at': null,
        'acknowledged_at': null,
      });

      expect(item.title, 'Thông báo lịch: buổi học bù');
      // Không ghép trường, không dựng lại từ mẫu: xuống dòng phải còn nguyên.
      expect(item.body.contains('\n\n'), isTrue);
      expect(item.categoryLabel, 'Lịch học / lịch thi');
      expect(item.isUnread, isTrue);
      expect(item.needsAcknowledgement, isTrue);
      expect(item.publishedAt, isNotNull);
    });

    test('JSON thiếu trường không làm vỡ app', () {
      final item = AnnouncementItem.fromJson({'id': 'x'});
      expect(item.title, '');
      expect(item.body, '');
      expect(item.mustRead, isFalse);
      expect(item.publishedAt, isNull);
      expect(item.categoryLabel, 'Thông báo'); // nhãn dự phòng
    });

    test('ngày giờ hỏng trở thành null chứ không ném lỗi', () {
      final item = AnnouncementItem.fromJson({
        'id': 'x',
        'published_at': 'không-phải-ngày',
      });
      expect(item.publishedAt, isNull);
    });

    test('đã xác nhận thì không đòi xác nhận nữa', () {
      final item = AnnouncementItem.fromJson({
        'id': 'x',
        'must_read': true,
        'read_at': '2026-09-01T10:05:00.000Z',
        'acknowledged_at': '2026-09-01T10:06:00.000Z',
      });
      expect(item.isUnread, isFalse);
      expect(item.needsAcknowledgement, isFalse);
    });

    test('thông báo đính chính được nhận ra', () {
      final item = AnnouncementItem.fromJson({'id': 'x', 'is_correction': true});
      expect(item.isCorrection, isTrue);
    });
  });

  group('AnnouncementImage', () {
    test('đọc ảnh kèm theo và giữ tỉ lệ để danh sách không nhảy', () {
      final item = AnnouncementItem.fromJson({
        'id': 'x',
        'images': [
          {'id': 'img-1', 'url': '/api/v1/student/board/images/img-1',
           'width': 1920, 'height': 1280},
        ],
      });
      expect(item.images, hasLength(1));
      expect(item.images.first.aspectRatio, closeTo(1.5, 0.001));
    });

    test('ghép URL tuyệt đối KHÔNG lặp lại /api', () {
      const img = AnnouncementImage(
          id: 'img-1', url: '/api/v1/student/board/images/img-1');
      expect(img.absoluteUrl, '${EmsApiService.baseUrl}/v1/student/board/images/img-1');
      expect(img.absoluteUrl.contains('/api/api'), isFalse);
    });

    test('thông báo không ảnh trả về danh sách rỗng, không null', () {
      expect(AnnouncementItem.fromJson({'id': 'x'}).images, isEmpty);
      expect(AnnouncementItem.fromJson({'id': 'x', 'images': 'hỏng'}).images, isEmpty);
    });

    test('thiếu kích thước thì không có tỉ lệ (widget dùng mặc định)', () {
      const img = AnnouncementImage(id: 'i', url: '/api/x');
      expect(img.aspectRatio, isNull);
    });
  });

  group('EmsException', () {
    test('401/403/404 là từ chối dứt khoát — không thử lại thành bão request', () {
      expect(EmsException('x', statusCode: 401).isDeliberateDenial, isTrue);
      expect(EmsException('x', statusCode: 403, code: 'account_deactivated')
          .isDeliberateDenial, isTrue);
      expect(EmsException('x', statusCode: 404, code: 'not_provisioned')
          .isDeliberateDenial, isTrue);
    });

    test('lỗi mạng (không có statusCode) thì ĐƯỢC phép thử lại', () {
      expect(EmsException('Không tải được bảng tin. Vui lòng thử lại.')
          .isDeliberateDenial, isFalse);
      expect(EmsException('x', statusCode: 502).isDeliberateDenial, isFalse);
    });

    test('giữ mã máy tách khỏi câu tiếng Việt', () {
      final e = EmsException('Tài khoản đã bị khoá.', code: 'account_deactivated');
      expect(e.code, 'account_deactivated');
      expect(e.toString(), 'Tài khoản đã bị khoá.');
    });
  });

  group('Cấu hình', () {
    test('base URL là https production, không IP/port cứng', () {
      expect(EmsApiService.baseUrl, startsWith('https://'));
      expect(EmsApiService.baseUrl, isNot(matches(RegExp(r'\d+\.\d+\.\d+\.\d+'))));
      expect(EmsApiService.baseUrl, endsWith('/api'));
    });
  });
}
