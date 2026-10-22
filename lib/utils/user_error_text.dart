import '../core/network/ems_exception.dart';

/// Keep Vietnamese validation messages, but never show machine codes, English
/// transport errors or exception dumps as product copy. Error metadata stays
/// on EmsException for authentication, refusal and retry decisions.
String vietnameseErrorMessage(String? message, {int? statusCode}) {
  final text = message?.trim() ?? '';
  final hasVietnamese = RegExp(r'[ăâđêôơưĂÂĐÊÔƠƯÀ-ỹ]').hasMatch(text);
  final technical = RegExp(
    r'\b(?:[A-Za-z]*Exception|[A-Za-z]*Error|StackTrace)\b|^[<{\[]',
  ).hasMatch(text);
  if (hasVietnamese && !technical) return text;
  return switch (statusCode) {
    401 => 'Không xác thực được tài khoản. Vui lòng kiểm tra thông tin đăng nhập và đăng nhập lại.',
    403 => 'Bạn không có quyền thực hiện thao tác này. Vui lòng liên hệ nhà trường để được hỗ trợ.',
    404 => 'Không tìm thấy dữ liệu. Vui lòng tải lại; nếu vẫn không thấy, hãy liên hệ nhà trường.',
    409 || 422 => 'Chưa thể ghi nhận thay đổi. Vui lòng kiểm tra thông tin và kết quả hiện tại trước khi thử lại.',
    _ => 'Chưa xác nhận được kết quả. Vui lòng kiểm tra lại trước khi thử lại.',
  };
}

String userErrorText(Object error) => error is EmsException
    ? vietnameseErrorMessage(error.message, statusCode: error.statusCode)
    : vietnameseErrorMessage(null);
