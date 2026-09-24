import 'package:flutter/material.dart';
import 'app_session.dart';
import 'ems_api_service.dart';

/// Xử lý chung cho một phiên EMS đã hết hạn (401): xoá session rồi điều
/// hướng về '/login'. Dùng ở mọi màn hình gọi [EmsApiService] trực tiếp
/// (tiền học phí, đăng ký môn, sửa hồ sơ) thay vì mỗi màn hình tự viết lại.
///
/// Trivial theo đúng ý — các bot khác có thể có một bản giống hệt, không
/// sao (xem brief S4/S5/S3).
class CrmSessionGuard {
  /// Trả `true` nếu [error] là một 401 và đã điều hướng về '/login'. Gọi nơi
  /// bắt lỗi: `if (await CrmSessionGuard.handleIfExpired(context, e)) return;`
  static Future<bool> handleIfExpired(BuildContext context, Object error) async {
    if (error is! EmsException || error.statusCode != 401) return false;
    await AppSession.instance.clear();
    if (!context.mounted) return true;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    return true;
  }
}
