import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/paged.dart';
import '../../../data/json.dart';
import '../../../data/models/staff/comms.dart';
import '../../../data/repositories/staff/comms_repository.dart';

/// Meetings of one status (`requested`, `confirmed`, `completed`, `declined`, `cancelled`).
class MeetingsNotifier extends PagedNotifier<StaffMeeting, String> {
  MeetingsNotifier(super.arg);

  @override
  Future<Paged<StaffMeeting>> fetch(int page) => ref.read(commsRepositoryProvider).meetings(status: arg, page: page, pageSize: 20);
}

final meetingsProvider = AsyncNotifierProvider.autoDispose.family<MeetingsNotifier, PagedList<StaffMeeting>, String>(MeetingsNotifier.new);

/// Requests waiting for an answer (the count chip on More and Home).
final pendingMeetingRequestsProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(commsRepositoryProvider).pendingMeetingRequests());
