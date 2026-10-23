import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/paged.dart';
import '../../data/json.dart';
import '../../data/models/fees.dart';
import '../../data/repositories/fees_repository.dart';
import '../learner/learner_context.dart';

class InvoicesNotifier extends PagedNotifier<Invoice, ({String? studentId, String? status})> {
  InvoicesNotifier(super.arg);
  @override
  Future<Paged<Invoice>> fetch(int page) => ref.read(feesRepositoryProvider).invoices(studentId: arg.studentId, status: arg.status, page: page);
}

final invoicesProvider = AsyncNotifierProvider.family<InvoicesNotifier, PagedList<Invoice>, ({String? studentId, String? status})>(InvoicesNotifier.new);

class PaymentsNotifier extends PagedNotifier<Payment, String?> {
  PaymentsNotifier(super.arg);
  @override
  Future<Paged<Payment>> fetch(int page) => ref.read(feesRepositoryProvider).payments(studentId: arg, page: page);
}

final paymentsProvider = AsyncNotifierProvider.family<PaymentsNotifier, PagedList<Payment>, String?>(PaymentsNotifier.new);

final invoiceProvider = FutureProvider.family<Invoice, String>((ref, id) => ref.watch(feesRepositoryProvider).invoice(id));
final receiptProvider = FutureProvider.family<Receipt, String>((ref, paymentId) => ref.watch(feesRepositoryProvider).receipt(paymentId));

/// Outstanding totals for the selected child, derived from the invoice list (all pages the first fetch returned).
final feesQueryProvider = Provider<String?>((ref) => ref.watch(learnerQueryIdProvider));
