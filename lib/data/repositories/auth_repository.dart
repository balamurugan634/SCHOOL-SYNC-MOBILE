import '../../core/network/api_client.dart';
import '../../core/network/device_meta.dart';
import '../models/auth_models.dart';
import '../models/me.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<TokenResponse> login({
    required String identifier,
    required String password,
    required DeviceMeta device,
    String? pushToken,
  }) async {
    final json = await _api.post(
      '/auth/login',
      auth: false,
      data: {'identifier': identifier.trim(), 'password': password, 'device': device.toDeviceJson(pushToken: pushToken)},
    );
    return TokenResponse.fromJson((json as Map).cast<String, dynamic>());
  }

  Future<Me> me() async => Me.fromJson(((await _api.get('/auth/me')) as Map).cast<String, dynamic>());

  Future<void> logout({String? pushToken}) async {
    await _api.post('/auth/logout', data: pushToken == null ? <String, dynamic>{} : {'pushToken': pushToken});
  }

  Future<void> changePassword({required String current, required String next}) async {
    await _api.post('/auth/change-password', data: {'currentPassword': current, 'newPassword': next});
  }

  /// Always answers 202, whether or not the account exists.
  Future<void> forgotPassword(String identifier) async {
    await _api.post('/auth/forgot-password', auth: false, data: {'identifier': identifier.trim()});
  }

  Future<List<SessionInfo>> sessions() async {
    final json = await _api.get('/auth/sessions') as Map;
    return (json['data'] as List)
        .map((e) => SessionInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<void> revokeSession(String id) async {
    await _api.delete('/auth/sessions/$id');
  }

  Future<void> revokeOthers() async {
    await _api.post('/auth/sessions/revoke-others');
  }

  Future<void> registerDevice({required DeviceMeta device, required String pushToken}) async {
    await _api.post('/devices', data: device.toDeviceJson(pushToken: pushToken));
  }

  Future<void> unregisterDevice(String pushToken) async {
    await _api.post('/devices/unregister', data: {'pushToken': pushToken});
  }
}
