/// Lỗi từ EMS. `code` là mã máy ổn định (ví dụ 'account_deactivated'),
/// `message` là câu tiếng Việt hiển thị cho người dùng.
class EmsException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  EmsException(this.message, {this.code, this.statusCode});

  /// EMS đã trả lời rằng tài khoản không được phép dùng EMS.
  ///
  /// 401 thường chỉ có nghĩa là một token đã hết hạn. Giữ nó ở đường thử lại;
  /// nếu coi 401 là từ chối vĩnh viễn, một phiên cũ có thể khoá EMS cho tới khi
  /// tiến trình ứng dụng được khởi động lại.
  bool get isDeliberateDenial => statusCode == 403 || statusCode == 404;

  @override
  String toString() => message;
}

/// Học viên đã quẹt cổng nhưng đang bị ghi VẮNG mà chưa có lý do.
class EmsPunchedStudent {
  final String mssv;
  final DateTime? punchedAt;
  const EmsPunchedStudent({required this.mssv, this.punchedAt});
}

/// 422 có chủ đích từ EMS, không phải sự cố. Kế thừa [EmsException] để mọi
/// `catch (EmsException)` sẵn có vẫn bắt được, nhưng mang theo danh sách người.
class EmsPunchConflict extends EmsException {
  final List<EmsPunchedStudent> students;
  EmsPunchConflict(super.message, {required this.students, super.statusCode})
    : super(code: 'punch_conflict_needs_reason');
}
