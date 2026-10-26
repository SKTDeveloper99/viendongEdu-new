import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ems_api_service.dart';

/// Cổng bắt buộc cập nhật (2026-09-11).
///
/// VÌ SAO: bản app cũ vẫn ghi điểm danh vào IMS qua màn hình cũ. Chứng minh
/// ngày 11/09: giáo viên đã đánh VẮNG trên EMS lúc 09:30, rồi một bản cũ ghi
/// "có mặt" vào IMS lúc 09:45 — hai hệ thống nói ngược nhau về cùng một
/// sinh viên. Từ bản này, điểm danh CHỈ ghi EMS; bản nào thấp hơn
/// `min_version` do máy chủ công bố thì KHÔNG được chạy tiếp.
///
/// Máy chủ: `GET /api/app/min-version` (công khai, không cần đăng nhập) —
/// đổi `APP_MIN_VERSION` trong .env là bản cũ chết ngay lần mở kế tiếp,
/// không cần phát hành lại.
///
/// Cùng một tên bản có thể là hai bản khác nhau trên Play (2026-10-26: 101 là
/// 6.0.8 của tdat535, 102 là 6.0.8 của mình; máy Android về 101 thì báo "chưa
/// điểm danh"). Vì vậy máy chủ còn công bố được `android_min_build` /
/// `ios_min_build`: build number (versionCode trên Android) thấp hơn số này
/// cũng bị chặn, kể cả khi tên bản bằng `min_version`.
///
/// An toàn: mạng lỗi / máy chủ lỗi → CHO QUA (không bao giờ khoá người dùng vì
/// EMS sập). Chỉ khoá khi máy chủ trả lời rõ ràng rằng bản này quá cũ.
class AppUpdateGate {
  static const Duration _timeout = Duration(seconds: 2);

  /// Trả về true nếu được phép chạy tiếp. Khi bị chặn, hàm này hiện hộp thoại
  /// không đóng được và không bao giờ trả về.
  static Future<bool> check(BuildContext context) async {
    Map<String, dynamic>? body;
    try {
      final res = await http
          .get(Uri.parse('${EmsApiService.baseUrl}/app/min-version'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {
      return true; // không liên lạc được → không chặn
    }
    if (body == null) return true;

    final min = body['min_version']?.toString() ?? '';
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return false;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final minBuild = body[ios ? 'ios_min_build' : 'android_min_build'];
    if (!isOutdated(info.version, min) &&
        !isBuildOutdated(info.buildNumber, minBuild)) {
      return true;
    }

    final url = ios
        ? body['ios_url']?.toString()
        : body['android_url']?.toString();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Cần cập nhật ứng dụng'),
          content: Text(
            'Bản ${info.version} (${info.buildNumber}) đã cũ. Từ bản $min điểm danh chỉ ghi vào hệ '
            'thống mới; bản cũ có thể ghi sai. Vui lòng cập nhật để tiếp tục.',
          ),
          actions: [
            FilledButton(
              onPressed: url == null || url.isEmpty
                  ? null
                  : () => launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    ),
              child: const Text('Cập nhật ngay'),
            ),
          ],
        ),
      ),
    );
    return false;
  }

  /// So sánh `a.b.c` theo từng số. Chuỗi lạ → không chặn (false).
  static bool isOutdated(String current, String minimum) {
    final c = _parse(current);
    final m = _parse(minimum);
    if (c == null || m == null) return false;
    for (var i = 0; i < 3; i++) {
      if (c[i] < m[i]) return true;
      if (c[i] > m[i]) return false;
    }
    return false;
  }

  /// Build number thấp hơn `minimum` → cũ. Thiếu / lạ → không chặn (false).
  static bool isBuildOutdated(String current, Object? minimum) {
    final c = int.tryParse(current.trim());
    final m = minimum is int ? minimum : int.tryParse('${minimum ?? ''}');
    if (c == null || m == null) return false;
    return c < m;
  }

  static List<int>? _parse(String v) {
    final core = v.split('+').first.trim();
    final parts = core.split('.');
    if (parts.isEmpty || parts.length > 3) return null;
    final out = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null) return null;
      out.add(n);
    }
    while (out.length < 3) {
      out.add(0);
    }
    return out;
  }
}
