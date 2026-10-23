import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/learner_extras.dart';

/// Library loans and the school bus, for students and parents.
class LearnerExtrasRepository {
  LearnerExtrasRepository(this._api);
  final ApiClient _api;

  Future<List<LibraryLoan>> libraryLoans({String? studentId, bool includeReturned = false}) async {
    final body = jsonMap(await _api.get('/library/my-books', query: {'studentId': ?studentId, 'includeReturned': includeReturned}));
    return jsonList(body['data']).map(LibraryLoan.fromJson).toList(growable: false);
  }

  Future<List<BusAllocation>> myBus() async {
    final body = jsonMap(await _api.get('/transport/my-bus'));
    return jsonList(body['data']).map(BusAllocation.fromJson).toList(growable: false);
  }
}

final learnerExtrasRepositoryProvider = Provider<LearnerExtrasRepository>((ref) => LearnerExtrasRepository(ref.watch(apiClientProvider)));
