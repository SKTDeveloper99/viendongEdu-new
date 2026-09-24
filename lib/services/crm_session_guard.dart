import 'package:flutter/material.dart';
import 'app_session.dart';
import 'ems_api_service.dart';

/// Bắt 401 từ [EmsApiService.send]: xoá phiên rồi điều hướng về '/login'.
///
/// Cố tình nhỏ — một bot khác trong cùng đợt gỡ IMS có thể thêm một bản y hệt
/// ở chỗ khác. Dùng trong `catch` của mọi màn hình gọi CRM:
/// `catch (e) { if (!await handleCrmAuthError(context, e)) { ...báo lỗi bình
/// thường... } }`.
///
/// Trả về `true` nếu đã xử lý (đã điều hướng đi) — nơi gọi không cần hiển thị
/// lỗi nữa. Trả về `false` nếu [error] không phải một 401 — nơi gọi tự lo xử
/// lý lỗi như thường lệ.
Future<bool> handleCrmAuthError(BuildContext context, Object error) async {
  if (error is! EmsException || error.statusCode != 401) return false;
  await AppSession.instance.clear();
  if (!context.mounted) return true;
  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  return true;
}
