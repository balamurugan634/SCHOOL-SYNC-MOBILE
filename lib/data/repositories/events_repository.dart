import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/events.dart';

class EventsRepository {
  EventsRepository(this._api);
  final ApiClient _api;

  Future<Paged<SchoolEvent>> list({DateTime? from, DateTime? to, int page = 1, int pageSize = 30}) async => Paged.parse(
    await _api.get('/events', query: {'page': page, 'pageSize': pageSize, if (from != null) 'from': isoDay(from), if (to != null) 'to': isoDay(to)}),
    SchoolEvent.fromJson,
  );

  Future<SchoolEvent> get(String id) async => SchoolEvent.fromJson(jsonMap(await _api.get('/events/$id')));

  /// Registers / gives or denies consent for one child (`going`, `not_going`, `consent_given`, `consent_denied`).
  Future<EventChildResponse> respond(String eventId, {required String studentId, required String response, String? note}) async => EventChildResponse.fromJson(
    jsonMap(await _api.post('/events/$eventId/respond', data: {'studentId': studentId, 'response': response, if (note != null && note.trim().isNotEmpty) 'note': note.trim()})),
  );
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) => EventsRepository(ref.watch(apiClientProvider)));
