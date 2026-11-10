import '../core/crm_web/crm_web_target.dart';
import 'api/web_pass_api.dart';

export 'api/web_pass_api.dart' show WebPass;

/// Mints a fresh pass for every opening; passes are never stored or reused.
class WebPassRepository {
  const WebPassRepository();

  String get crmHost => WebPassApi.crmHost;

  Future<WebPass> mint(CrmTarget target) => WebPassApi.mint(target);
}
