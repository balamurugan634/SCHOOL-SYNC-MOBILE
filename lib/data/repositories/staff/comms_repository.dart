import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../json.dart';
import '../../models/staff/comms.dart';

/// Announcements an author manages, and parent-teacher meetings from the teacher / office side.
class CommsRepository {
  CommsRepository(this._api);
  final ApiClient _api;

  // ── announcements ──
  /// [state] draft | scheduled | published | expired | archived. [mine] narrows school-scope editors to their own.
  Future<Paged<ManagedAnnouncement>> managed({String? state, bool mine = false, int page = 1, int pageSize = 25}) async => Paged.parse(
    await _api.get('/announcements/manage', query: {'page': page, 'pageSize': pageSize, 'state': ?state, if (mine) 'mine': true}),
    ManagedAnnouncement.fromJson,
  );

  Future<ManagedAnnouncement> announcement(String id) async => ManagedAnnouncement.fromJson(jsonMap(await _api.get('/announcements/$id')));

  /// Saved as a draft (or scheduled when `publishAt` is in the future).
  Future<ManagedAnnouncement> createAnnouncement(AnnouncementDraft d) async => ManagedAnnouncement.fromJson(jsonMap(await _api.post('/announcements', data: d.toJson())));

  Future<ManagedAnnouncement> updateAnnouncement(String id, AnnouncementDraft d) async {
    final body = d.toJson()..remove('publishAt');
    return ManagedAnnouncement.fromJson(jsonMap(await _api.patch('/announcements/$id', data: body)));
  }

  /// PATCH of a draft with every field (an empty expiry is cleared).
  Future<ManagedAnnouncement> updateDraftAnnouncement(String id, AnnouncementDraft d) async => ManagedAnnouncement.fromJson(jsonMap(await _api.patch('/announcements/$id', data: d.toUpdateJson())));

  /// The only change a published announcement accepts. null removes the expiry.
  Future<void> setAnnouncementExpiry(String id, DateTime? at) async {
    await _api.patch('/announcements/$id', data: {'expiresAt': at?.toUtc().toIso8601String()});
  }

  Future<void> publishAnnouncement(String id) async {
    await _api.post('/announcements/$id/publish');
  }

  Future<void> scheduleAnnouncement(String id, DateTime at) async {
    await _api.post('/announcements/$id/schedule', data: {'publishAt': at.toUtc().toIso8601String()});
  }

  Future<void> unscheduleAnnouncement(String id) async {
    await _api.post('/announcements/$id/unschedule');
  }

  Future<void> expireAnnouncement(String id) async {
    await _api.post('/announcements/$id/expire');
  }

  Future<void> archiveAnnouncement(String id) async {
    await _api.post('/announcements/$id/archive');
  }

  /// Drafts only (the author); published ones are archived instead.
  Future<void> deleteAnnouncement(String id) async {
    await _api.delete('/announcements/$id');
  }

  Future<AnnouncementStats> stats(String id) async => AnnouncementStats.fromJson(jsonMap(await _api.get('/announcements/$id/stats')));

  // ── meetings ──
  Future<Paged<StaffMeeting>> meetings({String? status, int page = 1, int pageSize = 30}) async => Paged.parse(
    await _api.get('/meetings', query: {'page': page, 'pageSize': pageSize, 'status': ?status}),
    StaffMeeting.fromJson,
  );

  /// How many meeting requests are waiting for an answer (cheap: one row, reads `meta.total`).
  Future<int> pendingMeetingRequests() async => (await meetings(status: 'requested', pageSize: 1)).meta.total;

  Future<void> confirmMeeting(String id, {required DateTime at, int durationMin = 15, String mode = 'in_person', String? locationOrLink}) async {
    await _api.post('/meetings/$id/confirm', data: {'scheduledAt': at.toUtc().toIso8601String(), 'durationMin': durationMin, 'mode': mode, if (locationOrLink != null && locationOrLink.trim().isNotEmpty) 'locationOrLink': locationOrLink.trim()});
  }

  Future<void> declineMeeting(String id, {required String reason}) async {
    await _api.post('/meetings/$id/decline', data: {'reason': reason.trim()});
  }

  Future<void> rescheduleMeeting(String id, {required DateTime at, int? durationMin, String? mode, String? locationOrLink}) async {
    await _api.post('/meetings/$id/reschedule', data: {'scheduledAt': at.toUtc().toIso8601String(), 'durationMin': ?durationMin, 'mode': ?mode, if (locationOrLink != null && locationOrLink.trim().isNotEmpty) 'locationOrLink': locationOrLink.trim()});
  }

  Future<void> completeMeeting(String id, {required String outcomeNotes}) async {
    await _api.post('/meetings/$id/complete', data: {'outcomeNotes': outcomeNotes.trim()});
  }

  Future<void> cancelMeeting(String id, {String? reason}) async {
    await _api.post('/meetings/$id/cancel', data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()});
  }
}

final commsRepositoryProvider = Provider<CommsRepository>((ref) => CommsRepository(ref.watch(apiClientProvider)));
