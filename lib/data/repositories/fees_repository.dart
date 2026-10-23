import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/fees.dart';

class FeesRepository {
  FeesRepository(this._api);
  final ApiClient _api;

  Future<Paged<Invoice>> invoices({String? studentId, String? status, int page = 1, int pageSize = 30}) async => Paged.parse(
    await _api.get('/fees/invoices', query: {'page': page, 'pageSize': pageSize, 'studentId': ?studentId, 'status': ?status}),
    Invoice.fromJson,
  );

  Future<Invoice> invoice(String id) async => Invoice.fromJson(jsonMap(await _api.get('/fees/invoices/$id')));

  Future<Paged<Payment>> payments({String? studentId, int page = 1, int pageSize = 30}) async => Paged.parse(
    await _api.get('/payments', query: {'page': page, 'pageSize': pageSize, 'studentId': ?studentId}),
    Payment.fromJson,
  );

  Future<Payment> payment(String id) async => Payment.fromJson(jsonMap(await _api.get('/payments/$id')));

  Future<Payment> syncPayment(String id) async => Payment.fromJson(jsonMap(await _api.post('/payments/$id/sync')));

  Future<Receipt> receipt(String paymentId) async => Receipt.fromJson(jsonMap(await _api.get('/payments/$paymentId/receipt')));

  /// DEV ONLY (mock gateway): simulate the payer completing checkout. Absent in production (404).
  Future<void> mockComplete(String paymentId) async {
    await _api.post('/payments/$paymentId/mock-complete');
  }

  String receiptPdfPath(String paymentId) => '/payments/$paymentId/receipt/pdf';

  /// Starts an online payment (parents). The invoice is only marked paid when the gateway confirms.
  Future<PayOrder> startPayment(String invoiceId, {int? amountMinor}) async => PayOrder.fromJson(jsonMap(await _api.post('/fees/invoices/$invoiceId/pay', data: {'amountMinor': ?amountMinor})));
}

final feesRepositoryProvider = Provider<FeesRepository>((ref) => FeesRepository(ref.watch(apiClientProvider)));
