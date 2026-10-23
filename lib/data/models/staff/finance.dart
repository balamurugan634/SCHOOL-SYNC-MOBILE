import '../../json.dart';

class MonthMoney {
  const MonthMoney({required this.month, this.collectedMinor = 0, this.expensesMinor});
  final String month; // yyyy-MM
  final int collectedMinor;
  final int? expensesMinor;
  factory MonthMoney.fromJson(Json j) => MonthMoney(month: jStrOr(j['month']), collectedMinor: jInt(j['collectedMinor']), expensesMinor: jIntN(j['expensesMinor']));
}

/// `GET /finance/summary` (also the `finance` block of the management dashboard).
class FinanceSummary {
  const FinanceSummary({
    required this.currency,
    this.from,
    this.to,
    this.invoicedMinor = 0,
    this.collectedMinor = 0,
    this.refundedMinor = 0,
    this.netCollectedMinor = 0,
    this.expensesMinor,
    this.netPositionMinor,
    this.outstandingMinor = 0,
    this.overdueMinor = 0,
    this.collectionRatePercent,
    this.byMonth = const [],
    this.pendingRefunds = 0,
    this.pendingConcessions = 0,
    this.pendingExpenses,
  });

  final String currency;
  final DateTime? from;
  final DateTime? to;
  final int invoicedMinor;
  final int collectedMinor;
  final int refundedMinor;
  final int netCollectedMinor;

  /// null when the caller may not see expenses.
  final int? expensesMinor;
  final int? netPositionMinor;
  final int outstandingMinor;
  final int overdueMinor;
  final double? collectionRatePercent;
  final List<MonthMoney> byMonth;
  final int pendingRefunds;
  final int pendingConcessions;
  final int? pendingExpenses;

  factory FinanceSummary.fromJson(Json j) {
    final pending = jsonMap(j['pending']);
    return FinanceSummary(
      currency: jStrOr(j['currency'], 'INR'),
      from: jDay(j['from']),
      to: jDay(j['to']),
      invoicedMinor: jInt(j['invoicedMinor']),
      collectedMinor: jInt(j['collectedMinor']),
      refundedMinor: jInt(j['refundedMinor']),
      netCollectedMinor: jInt(j['netCollectedMinor']),
      expensesMinor: jIntN(j['expensesMinor']),
      netPositionMinor: jIntN(j['netPositionMinor']),
      outstandingMinor: jInt(j['outstandingMinor']),
      overdueMinor: jInt(j['overdueMinor']),
      collectionRatePercent: jDoubleN(j['collectionRatePercent']),
      byMonth: jsonList(j['byMonth']).map(MonthMoney.fromJson).toList(growable: false),
      pendingRefunds: jInt(pending['refunds']),
      pendingConcessions: jInt(pending['concessions']),
      pendingExpenses: jIntN(pending['expenses']),
    );
  }
}

class AgingBuckets {
  const AgingBuckets({this.notDue = 0, this.d1to30 = 0, this.d31to60 = 0, this.d61to90 = 0, this.d90plus = 0});
  final int notDue;
  final int d1to30;
  final int d31to60;
  final int d61to90;
  final int d90plus;

  factory AgingBuckets.fromJson(Object? v) {
    final j = jsonMap(v);
    return AgingBuckets(notDue: jInt(j['notDue']), d1to30: jInt(j['d1to30']), d31to60: jInt(j['d31to60']), d61to90: jInt(j['d61to90']), d90plus: jInt(j['d90plus']));
  }
}

class OutstandingRow {
  const OutstandingRow({required this.name, this.invoices = 0, this.outstandingMinor = 0, this.overdueMinor = 0});
  final String name;
  final int invoices;
  final int outstandingMinor;
  final int overdueMinor;
  factory OutstandingRow.fromJson(Json j) => OutstandingRow(name: jStrOr(j['name']), invoices: jInt(j['invoices']), outstandingMinor: jInt(j['outstandingMinor']), overdueMinor: jInt(j['overdueMinor']));
}

class OutstandingReport {
  const OutstandingReport({required this.currency, this.invoices = 0, this.outstandingMinor = 0, this.overdueMinor = 0, this.buckets = const AgingBuckets(), this.rows = const []});
  final String currency;
  final int invoices;
  final int outstandingMinor;
  final int overdueMinor;
  final AgingBuckets buckets;
  final List<OutstandingRow> rows;

  factory OutstandingReport.fromJson(Json j) => OutstandingReport(
    currency: jStrOr(j['currency'], 'INR'),
    invoices: jInt(j['invoices']),
    outstandingMinor: jInt(j['outstandingMinor']),
    overdueMinor: jInt(j['overdueMinor']),
    buckets: AgingBuckets.fromJson(j['buckets']),
    rows: jsonList(j['rows']).map(OutstandingRow.fromJson).toList(growable: false),
  );
}

class Defaulter {
  const Defaulter({required this.studentId, required this.studentName, required this.admissionNo, this.gradeName, this.sectionName, this.overdueInvoices = 0, this.overdueMinor = 0, this.maxDaysOverdue = 0, this.guardianName, this.guardianPhone});
  final String studentId;
  final String studentName;
  final String admissionNo;
  final String? gradeName;
  final String? sectionName;
  final int overdueInvoices;
  final int overdueMinor;
  final int maxDaysOverdue;
  final String? guardianName;
  final String? guardianPhone;

  String get classLabel => [gradeName, sectionName].where((e) => e != null && e.isNotEmpty).join(' ');

  factory Defaulter.fromJson(Json j) => Defaulter(
    studentId: jStrOr(j['studentId']),
    studentName: jStrOr(j['studentName']),
    admissionNo: jStrOr(j['admissionNo']),
    gradeName: jStr(j['gradeName']),
    sectionName: jStr(j['sectionName']),
    overdueInvoices: jInt(j['overdueInvoices']),
    overdueMinor: jInt(j['overdueMinor']),
    maxDaysOverdue: jInt(j['maxDaysOverdue']),
    guardianName: jStr(j['guardianName']),
    guardianPhone: jStr(j['guardianPhone']),
  );
}

class CollectionPoint {
  const CollectionPoint({required this.period, this.collectedMinor = 0, this.refundedMinor = 0, this.count = 0});
  final String period;
  final int collectedMinor;
  final int refundedMinor;
  final int count;
  factory CollectionPoint.fromJson(Json j) => CollectionPoint(period: jStrOr(j['period']), collectedMinor: jInt(j['collectedMinor']), refundedMinor: jInt(j['refundedMinor']), count: jInt(j['count']));
}

class CollectionReport {
  const CollectionReport({required this.currency, this.from, this.to, this.collectedMinor = 0, this.refundedMinor = 0, this.netMinor = 0, this.count = 0, this.series = const [], this.byMethod = const [], this.byCategory = const []});
  final String currency;
  final DateTime? from;
  final DateTime? to;
  final int collectedMinor;
  final int refundedMinor;
  final int netMinor;
  final int count;
  final List<CollectionPoint> series;
  final List<({String label, int minor, int count})> byMethod;
  final List<({String label, int minor})> byCategory;

  factory CollectionReport.fromJson(Json j) => CollectionReport(
    currency: jStrOr(j['currency'], 'INR'),
    from: jDay(j['from']),
    to: jDay(j['to']),
    collectedMinor: jInt(j['collectedMinor']),
    refundedMinor: jInt(j['refundedMinor']),
    netMinor: jInt(j['netMinor']),
    count: jInt(j['count']),
    series: jsonList(j['series']).map(CollectionPoint.fromJson).toList(growable: false),
    byMethod: [for (final r in jsonList(j['byMethod'])) (label: jStrOr(r['method']), minor: jInt(r['collectedMinor']), count: jInt(r['count']))],
    byCategory: [for (final r in jsonList(j['byCategory'])) (label: jStrOr(r['category']), minor: jInt(r['collectedMinor']))],
  );
}

// ── approvals ──────────────────────────────────────────────────────────────

class ConcessionItem {
  const ConcessionItem({required this.id, required this.studentName, this.admissionNo = '', required this.name, required this.type, required this.value, this.categoryName, this.reason, required this.status, this.appliedMinor = 0, this.createdAt});
  final String id;
  final String studentName;
  final String admissionNo;
  final String name;

  /// percent (value in basis points) | fixed (value in minor units)
  final String type;
  final int value;
  final String? categoryName;
  final String? reason;
  final String status; // pending | approved | rejected
  final int appliedMinor;
  final DateTime? createdAt;

  bool get pending => status == 'pending';

  factory ConcessionItem.fromJson(Json j) => ConcessionItem(
    id: jStrOr(j['id']),
    studentName: jStrOr(j['studentName']),
    admissionNo: jStrOr(j['admissionNo']),
    name: jStrOr(j['name']),
    type: jStrOr(j['type'], 'percent'),
    value: jInt(j['value']),
    categoryName: jStr(j['categoryName']),
    reason: jStr(j['reason']),
    status: jStrOr(j['status'], 'pending'),
    appliedMinor: jInt(j['appliedMinor']),
    createdAt: jDate(j['createdAt']),
  );
}

class RefundItem {
  const RefundItem({required this.id, this.invoiceNo = '', required this.studentName, this.amountMinor = 0, required this.reason, required this.status, this.requestedByName, this.createdAt});
  final String id;
  final String invoiceNo;
  final String studentName;
  final int amountMinor;
  final String reason;

  /// requested | approved | rejected | processed
  final String status;
  final String? requestedByName;
  final DateTime? createdAt;

  bool get requested => status == 'requested';

  factory RefundItem.fromJson(Json j) => RefundItem(
    id: jStrOr(j['id']),
    invoiceNo: jStrOr(j['invoiceNo']),
    studentName: jStrOr(j['studentName']),
    amountMinor: jInt(j['amountMinor']),
    reason: jStrOr(j['reason']),
    status: jStrOr(j['status'], 'requested'),
    requestedByName: jStr(j['requestedByName']),
    createdAt: jDate(j['createdAt']),
  );
}

class ExpenseItem {
  const ExpenseItem({required this.id, required this.category, required this.description, this.amountMinor = 0, this.spentOn, this.paidTo, this.reference, required this.status, this.createdByName, this.createdAt});
  final String id;
  final String category;
  final String description;
  final int amountMinor;
  final DateTime? spentOn;
  final String? paidTo;
  final String? reference;

  /// pending | approved | rejected
  final String status;
  final String? createdByName;
  final DateTime? createdAt;

  bool get pending => status == 'pending';

  factory ExpenseItem.fromJson(Json j) => ExpenseItem(
    id: jStrOr(j['id']),
    category: jStrOr(j['category']),
    description: jStrOr(j['description']),
    amountMinor: jInt(j['amountMinor']),
    spentOn: jDay(j['spentOn']),
    paidTo: jStr(j['paidTo']),
    reference: jStr(j['reference']),
    status: jStrOr(j['status'], 'pending'),
    createdByName: jStr(j['createdByName']),
    createdAt: jDate(j['createdAt']),
  );
}

/// A student's invoice, shown read-only inside the people lookup.
class InvoiceLine {
  const InvoiceLine({required this.id, required this.invoiceNo, required this.title, this.dueDate, required this.status, this.overdue = false, this.totalMinor = 0, this.paidMinor = 0, this.balanceMinor = 0});
  final String id;
  final String invoiceNo;
  final String title;
  final DateTime? dueDate;
  final String status;
  final bool overdue;
  final int totalMinor;
  final int paidMinor;
  final int balanceMinor;

  factory InvoiceLine.fromJson(Json j) => InvoiceLine(
    id: jStrOr(j['id']),
    invoiceNo: jStrOr(j['invoiceNo']),
    title: jStrOr(j['title']),
    dueDate: jDay(j['dueDate']),
    status: jStrOr(j['status'], 'unpaid'),
    overdue: jBool(j['overdue']),
    totalMinor: jInt(j['totalMinor']),
    paidMinor: jInt(j['paidMinor']),
    balanceMinor: jInt(j['balanceMinor']),
  );
}
