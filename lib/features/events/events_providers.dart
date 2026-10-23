import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/paged.dart';
import '../../data/json.dart';
import '../../data/models/events.dart';
import '../../data/repositories/events_repository.dart';

/// Upcoming events (from today) or past ones (last 6 months). Key: `true` = upcoming.
class EventsNotifier extends PagedNotifier<SchoolEvent, bool> {
  EventsNotifier(super.arg);

  @override
  Future<Paged<SchoolEvent>> fetch(int page) {
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day);
    return ref.read(eventsRepositoryProvider).list(
      from: arg ? d : d.subtract(const Duration(days: 180)),
      to: arg ? d.add(const Duration(days: 365)) : d.subtract(const Duration(days: 1)),
      page: page,
    );
  }
}

final eventsProvider = AsyncNotifierProvider.family<EventsNotifier, PagedList<SchoolEvent>, bool>(EventsNotifier.new);

final eventDetailProvider = FutureProvider.family<SchoolEvent, String>((ref, id) => ref.watch(eventsRepositoryProvider).get(id));
