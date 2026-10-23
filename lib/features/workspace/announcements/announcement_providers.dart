import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/paged.dart';
import '../../../data/json.dart';
import '../../../data/models/staff/comms.dart';
import '../../../data/models/staff/people.dart';
import '../../../data/repositories/staff/academics_repository.dart';
import '../../../data/repositories/staff/comms_repository.dart';

/// `state` null = all; `mine` narrows school-scope editors to what they wrote.
typedef AnnouncementQuery = ({String? state, bool mine});

class ManagedAnnouncementsNotifier extends PagedNotifier<ManagedAnnouncement, AnnouncementQuery> {
  ManagedAnnouncementsNotifier(super.arg);

  @override
  Future<Paged<ManagedAnnouncement>> fetch(int page) => ref.read(commsRepositoryProvider).managed(state: arg.state, mine: arg.mine, page: page, pageSize: 20);
}

final managedAnnouncementsProvider = AsyncNotifierProvider.autoDispose.family<ManagedAnnouncementsNotifier, PagedList<ManagedAnnouncement>, AnnouncementQuery>(ManagedAnnouncementsNotifier.new);

final announcementDetailProvider = FutureProvider.autoDispose.family<ManagedAnnouncement, String>((ref, id) => ref.watch(commsRepositoryProvider).announcement(id));

final announcementStatsProvider = FutureProvider.autoDispose.family<AnnouncementStats, String>((ref, id) => ref.watch(commsRepositoryProvider).stats(id));

/// Sections the author may address: only mine (lead / teach) for teachers, every section for school-scope authors.
final audienceSectionsProvider = FutureProvider.autoDispose.family<List<SectionItem>, bool>((ref, mine) => ref.watch(academicsRepositoryProvider).sections(mine: mine));

final audienceGradesProvider = FutureProvider.autoDispose<List<Grade>>((ref) => ref.watch(academicsRepositoryProvider).grades());
