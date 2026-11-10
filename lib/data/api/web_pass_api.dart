import '../../core/crm_web/crm_web_target.dart';
import '../../services/ems_api_service.dart';

/// A one-use sign-in pass for one CRM page (60 s, single use).
class WebPass {
  final Uri url;
  final Duration expiresIn;
  const WebPass(this.url, this.expiresIn);
}

/// `POST /api/v1/auth/web-pass {target}` → `{url, expires_in}`.
abstract final class WebPassApi {
  /// Host of the CRM the app talks to; the only host the web view loads.
  static String get crmHost => Uri.parse(EmsApiService.baseUrl).host;

  static Future<WebPass> mint(CrmTarget target) async {
    final body = await EmsApiService.sendMap(
      'POST',
      '/v1/auth/web-pass',
      body: {'target': target.relative},
    );
    final url = Uri.tryParse(body['url']?.toString() ?? '');
    final seconds = int.tryParse('${body['expires_in'] ?? ''}') ?? 60;
    // Never open anything but our own host with a pass in the fragment.
    if (url == null ||
        url.scheme != 'https' ||
        url.host != crmHost ||
        url.fragment.isEmpty) {
      throw EmsException('Không mở được trang. Vui lòng thử lại.');
    }
    return WebPass(url, Duration(seconds: seconds.clamp(1, 600)));
  }
}
