import '../../core/network/api_client.dart';
import '../../core/network/app_exception.dart';
import '../../core/util/site_address.dart';
import '../models/site_info.dart';

class SiteRepository {
  SiteRepository(this._api);
  final ApiClient _api;

  /// `GET /site/info` against [address] (not necessarily the saved school yet).
  Future<SiteInfo> fetchInfo(SiteAddress address) async {
    final json = await _api.get('/site/info', auth: false, site: address);
    if (json is! Map || json['code'] is! String || json['name'] is! String) {
      throw const AppException(
        kind: ErrorKind.notFound,
        code: 'NOT_SCHOOLSYNC',
        message: 'That address is not a SchoolSync school.',
      );
    }
    return SiteInfo.fromJson(json.cast<String, dynamic>());
  }
}
