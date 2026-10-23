import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/paged.dart';
import '../../../data/json.dart';
import '../../../data/models/staff/finance.dart';
import '../../../data/repositories/staff/finance_repository.dart';

final financeSummaryProvider = FutureProvider.autoDispose<FinanceSummary>((ref) => ref.watch(financeRepositoryProvider).summary());

/// [groupBy]: grade | section.
final outstandingProvider = FutureProvider.autoDispose.family<OutstandingReport, String>((ref, groupBy) => ref.watch(financeRepositoryProvider).outstanding(groupBy: groupBy));

/// [groupBy]: month (the last 6 months) | day (the last 30 days).
final collectionProvider = FutureProvider.autoDispose.family<CollectionReport, String>((ref, groupBy) {
  final now = DateTime.now();
  final to = DateTime(now.year, now.month, now.day);
  final from = groupBy == 'day' ? to.subtract(const Duration(days: 29)) : DateTime(now.year, now.month - 5, 1);
  return ref.watch(financeRepositoryProvider).collection(from: from, to: to, groupBy: groupBy);
});

/// Students with overdue fees, worst first (the API's order).
class DefaultersFeed extends PagedNotifier<Defaulter, int> {
  DefaultersFeed(super.arg);

  @override
  Future<Paged<Defaulter>> fetch(int page) => ref.read(financeRepositoryProvider).defaulters(page: page, pageSize: 30);
}

final defaultersProvider = AsyncNotifierProvider.family<DefaultersFeed, PagedList<Defaulter>, int>(DefaultersFeed.new);

/// Display names for the payment methods the API returns.
String paymentMethodLabel(String m) => switch (m) {
  'cash' => 'Cash',
  'cheque' => 'Cheque',
  'bank_transfer' => 'Bank transfer',
  'upi' => 'UPI',
  'card' => 'Card',
  'online' => 'Online',
  _ => m.isEmpty ? 'Other' : m[0].toUpperCase() + m.substring(1).replaceAll('_', ' '),
};

/// The five ageing buckets as (label, minor) in order.
List<(String, int)> agingLines(AgingBuckets b) => [('Not due yet', b.notDue), ('1 to 30 days overdue', b.d1to30), ('31 to 60 days', b.d31to60), ('61 to 90 days', b.d61to90), ('Over 90 days', b.d90plus)];
