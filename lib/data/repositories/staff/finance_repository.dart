import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../json.dart';
import '../../models/staff/finance.dart';

/// Read-only finance reports plus the approval queues (concessions, refunds, expenses).
class FinanceRepository {
  FinanceRepository(this._api);
  final ApiClient _api;

  Future<FinanceSummary> summary({DateTime? from, DateTime? to}) async => FinanceSummary.fromJson(
    jsonMap(await _api.get('/finance/summary', query: {if (from != null) 'from': isoDay(from), if (to != null) 'to': isoDay(to)})),
  );

  /// [groupBy] none | grade | section.
  Future<OutstandingReport> outstanding({String groupBy = 'grade'}) async => OutstandingReport.fromJson(jsonMap(await _api.get('/fees/reports/outstanding', query: {'groupBy': groupBy})));

  Future<Paged<Defaulter>> defaulters({int page = 1, int pageSize = 30}) async => Paged.parse(await _api.get('/fees/reports/defaulters', query: {'page': page, 'pageSize': pageSize}), Defaulter.fromJson);

  /// [groupBy] day | month.
  Future<CollectionReport> collection({DateTime? from, DateTime? to, String groupBy = 'month'}) async => CollectionReport.fromJson(
    jsonMap(await _api.get('/fees/reports/collection', query: {'groupBy': groupBy, if (from != null) 'from': isoDay(from), if (to != null) 'to': isoDay(to)})),
  );

  /// A student's invoices (read-only), for the people lookup.
  Future<List<InvoiceLine>> invoicesOf(String studentId) async => jsonList(jsonMap(await _api.get('/fees/invoices', query: {'studentId': studentId, 'pageSize': 20}))['data']).map(InvoiceLine.fromJson).toList(growable: false);

  // ── approvals ──
  Future<Paged<ConcessionItem>> concessions({String status = 'pending', int page = 1, int pageSize = 30}) async => Paged.parse(await _api.get('/fees/concessions', query: {'status': status, 'page': page, 'pageSize': pageSize}), ConcessionItem.fromJson);

  Future<void> decideConcession(String id, {required bool approve, String? note}) async {
    await _api.post('/fees/concessions/$id/${approve ? 'approve' : 'reject'}', data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
  }

  Future<Paged<RefundItem>> refunds({String status = 'requested', int page = 1, int pageSize = 30}) async => Paged.parse(await _api.get('/payments/refunds', query: {'status': status, 'page': page, 'pageSize': pageSize}), RefundItem.fromJson);

  /// Approving processes the refund by default (payment and invoice are adjusted). Rejecting needs a note (3+ characters).
  Future<void> decideRefund(String id, {required bool approve, String? note}) async {
    await _api.post('/payments/refunds/$id/${approve ? 'approve' : 'reject'}', data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
  }

  Future<Paged<ExpenseItem>> expenses({String status = 'pending', int page = 1, int pageSize = 30}) async => Paged.parse(await _api.get('/expenses', query: {'status': status, 'page': page, 'pageSize': pageSize}), ExpenseItem.fromJson);

  Future<void> decideExpense(String id, {required bool approve, String? note}) async {
    await _api.post('/expenses/$id/${approve ? 'approve' : 'reject'}', data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) => FinanceRepository(ref.watch(apiClientProvider)));
