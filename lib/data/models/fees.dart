import '../json.dart';

class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceNo,
    required this.title,
    required this.status,
    required this.overdue,
    required this.totalMinor,
    required this.paidMinor,
    required this.balanceMinor,
    this.studentId,
    this.studentName,
    this.dueDate,
    this.daysOverdue = 0,
    this.discountMinor = 0,
    this.lateFeeMinor = 0,
    this.amountDueNowMinor = 0,
    this.notes,
    this.items = const [],
    this.payments = const [],
  });

  final String id;
  final String invoiceNo;
  final String title;
  final String? studentId;
  final String? studentName;
  final DateTime? dueDate;

  /// unpaid | partial | paid | void
  final String status;
  final bool overdue;
  final int daysOverdue;
  final int totalMinor;
  final int discountMinor;
  final int paidMinor;
  final int balanceMinor;
  final int lateFeeMinor;
  final int amountDueNowMinor;
  final String? notes;
  final List<InvoiceItem> items;
  final List<Payment> payments;

  bool get isPaid => status == 'paid';
  bool get isVoid => status == 'void';
  bool get payable => !isPaid && !isVoid && balanceMinor > 0;

  factory Invoice.fromJson(Json j) => Invoice(
    id: jStrOr(j['id']),
    invoiceNo: jStrOr(j['invoiceNo']),
    title: jStrOr(j['title']),
    studentId: jStr(j['studentId']),
    studentName: jStr(j['studentName']),
    dueDate: jDay(j['dueDate']),
    status: jStrOr(j['status']),
    overdue: jBool(j['overdue']),
    daysOverdue: jInt(j['daysOverdue']),
    totalMinor: jInt(j['totalMinor']),
    discountMinor: jInt(j['discountMinor']),
    paidMinor: jInt(j['paidMinor']),
    balanceMinor: jInt(j['balanceMinor']),
    lateFeeMinor: jInt(j['lateFeeMinor']),
    amountDueNowMinor: jInt(j['amountDueNowMinor']),
    notes: jStr(j['notes']),
    items: jsonList(j['items']).map(InvoiceItem.fromJson).toList(growable: false),
    payments: jsonList(j['payments']).map(Payment.fromJson).toList(growable: false),
  );
}

class InvoiceItem {
  const InvoiceItem({required this.description, required this.amountMinor, this.categoryName, this.discountMinor = 0});
  final String description;
  final String? categoryName;
  final int amountMinor;
  final int discountMinor;
  factory InvoiceItem.fromJson(Json j) => InvoiceItem(description: jStrOr(j['description']), categoryName: jStr(j['categoryName']), amountMinor: jInt(j['amountMinor']), discountMinor: jInt(j['discountMinor']));
}

class Payment {
  const Payment({required this.id, required this.invoiceId, required this.invoiceNo, required this.amountMinor, required this.method, required this.status, this.refundedMinor = 0, this.receiptNo, this.reference, this.paidAt, this.studentName});
  final String id;
  final String invoiceId;
  final String invoiceNo;
  final int amountMinor;
  final int refundedMinor;

  /// cash | cheque | bank_transfer | upi | card | online
  final String method;

  /// pending | succeeded | failed | refunded | partially_refunded
  final String status;
  final String? receiptNo;
  final String? reference;
  final DateTime? paidAt;
  final String? studentName;

  bool get succeeded => status == 'succeeded' || status == 'partially_refunded' || status == 'refunded';
  bool get pending => status == 'pending';

  String get methodLabel => switch (method) {
    'cash' => 'Cash',
    'cheque' => 'Cheque',
    'bank_transfer' => 'Bank transfer',
    'upi' => 'UPI',
    'card' => 'Card',
    'online' => 'Online',
    _ => method,
  };

  factory Payment.fromJson(Json j) => Payment(
    id: jStrOr(j['id']),
    invoiceId: jStrOr(j['invoiceId']),
    invoiceNo: jStrOr(j['invoiceNo']),
    amountMinor: jInt(j['amountMinor']),
    refundedMinor: jInt(j['refundedMinor']),
    method: jStrOr(j['method']),
    status: jStrOr(j['status']),
    receiptNo: jStr(j['receiptNo']),
    reference: jStr(j['reference']),
    paidAt: jDate(j['paidAt']),
    studentName: jStr(j['studentName']),
  );
}

class Receipt {
  const Receipt({required this.receiptNo, required this.paymentId, required this.currency, required this.schoolName, required this.studentName, required this.invoiceNo, required this.invoiceTitle, required this.items, required this.amountMinor, required this.method, this.paidAt, this.reference, this.receivedBy, this.admissionNo, this.gradeSection});
  final String receiptNo;
  final String paymentId;
  final String currency;
  final String schoolName;
  final String studentName;
  final String? admissionNo;
  final String? gradeSection;
  final String invoiceNo;
  final String invoiceTitle;
  final List<InvoiceItem> items;
  final int amountMinor;
  final String method;
  final DateTime? paidAt;
  final String? reference;
  final String? receivedBy;

  factory Receipt.fromJson(Json j) {
    final student = jsonMap(j['student']);
    final invoice = jsonMap(j['invoice']);
    final pay = jsonMap(j['payment']);
    final gs = [jStr(student['grade']), jStr(student['section'])].whereType<String>().join(' - ');
    return Receipt(
      receiptNo: jStrOr(j['receiptNo']),
      paymentId: jStrOr(j['paymentId']),
      currency: jStrOr(j['currency'], 'INR'),
      schoolName: jStrOr(jsonMap(j['school'])['name']),
      studentName: jStrOr(student['name']),
      admissionNo: jStr(student['admissionNo']),
      gradeSection: gs.isEmpty ? null : gs,
      invoiceNo: jStrOr(invoice['invoiceNo']),
      invoiceTitle: jStrOr(invoice['title']),
      items: jsonList(j['items']).map(InvoiceItem.fromJson).toList(growable: false),
      amountMinor: jInt(pay['amountMinor']),
      method: jStrOr(pay['method']),
      paidAt: jDate(j['paidAt']),
      reference: jStr(pay['reference']),
      receivedBy: jStr(j['receivedBy']),
    );
  }
}

/// Response of `POST /fees/invoices/{id}/pay`: the gateway order for an online payment.
class PayOrder {
  const PayOrder({required this.paymentId, required this.provider, required this.orderId, required this.amountMinor, required this.currency, required this.mock, this.keyId});
  final String paymentId;
  final String provider; // mock | razorpay
  final String orderId;
  final int amountMinor;
  final String currency;
  final bool mock;
  final String? keyId;

  factory PayOrder.fromJson(Json j) => PayOrder(paymentId: jStrOr(j['paymentId']), provider: jStrOr(j['provider']), orderId: jStrOr(j['orderId']), amountMinor: jInt(j['amountMinor']), currency: jStrOr(j['currency'], 'INR'), mock: jBool(j['mock']), keyId: jStr(j['keyId']));
}
