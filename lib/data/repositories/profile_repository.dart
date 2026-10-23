import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/profile_details.dart';

class ProfileRepository {
  ProfileRepository(this._api);
  final ApiClient _api;

  Future<ProfileDetails> details() async => ProfileDetails.fromJson(jsonMap(await _api.get('/me/profile')));

  /// Updates phone and/or address. Changing the email needs the current password.
  Future<void> update({String? phone, Map<String, String>? address, String? email, String? currentPassword}) async {
    await _api.patch('/me/profile', data: {if (phone != null) 'phone': phone.trim().isEmpty ? null : phone.trim(), 'address': ?address, if (email != null) 'email': email.trim().isEmpty ? null : email.trim(), 'currentPassword': ?currentPassword});
  }

  Future<void> setAvatar(String filePath) async {
    await _api.upload('/me/avatar', filePath: filePath, fields: {'purpose': 'avatar'}, method: 'PUT');
  }

  Future<void> removeAvatar() async {
    await _api.delete('/me/avatar');
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(apiClientProvider)));
