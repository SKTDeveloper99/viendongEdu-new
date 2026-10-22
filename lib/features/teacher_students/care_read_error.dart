import '../../services/ems_api_service.dart';

/// Server errors may contain staff-only wording or reason codes (M-54).
String careReadError(Object error) {
  if (error is EmsException) {
    if (error.statusCode == 401) return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    if (error.statusCode == 403) return 'Bạn không có quyền xem danh sách này. Vui lòng liên hệ nhà trường để được hỗ trợ.';
    if (error.statusCode == 404) {
      return 'Chưa có hồ sơ trong phạm vi phụ trách. Vui lòng liên hệ nhà trường để kiểm tra phân công.';
    }
  }
  return 'Không tải được dữ liệu mới. Kiểm tra mạng và thử lại.';
}

bool careAccessDenied(Object error) =>
    error is EmsException &&
    (error.statusCode == 401 ||
        error.statusCode == 403 ||
        error.statusCode == 404);
