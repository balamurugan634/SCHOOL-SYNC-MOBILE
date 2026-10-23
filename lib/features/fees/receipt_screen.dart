import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/util/format.dart';
import '../../data/models/fees.dart';
import '../../data/repositories/fees_repository.dart';
import '../../data/repositories/files_repository.dart';
import '../security/secure_scope.dart';
import 'fees_providers.dart';

class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.paymentId});
  final String paymentId;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  bool _busy = false;

  Future<void> _pdf(Receipt r) async {
    setState(() => _busy = true);
    try {
      await ref.read(filesRepositoryProvider).openFile(ref.read(feesRepositoryProvider).receiptPdfPath(widget.paymentId), fileName: 'receipt-${r.receiptNo}.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(receiptProvider(widget.paymentId));
    final t = context.tokens;
    return SecureScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Receipt')),
        body: AsyncBody<Receipt>(
          value: v,
          onRetry: () => ref.invalidate(receiptProvider(widget.paymentId)),
          data: (r) => RefreshScroll(
            onRefresh: () async => ref.invalidate(receiptProvider(widget.paymentId)),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.schoolName, style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
                    Text('Receipt ${r.receiptNo}', style: context.text.headlineSmall),
                    if (r.paidAt != null) Text(fmtDateTime(r.paidAt!), style: context.text.bodySmall),
                    const Divider(height: Gaps.xl),
                    FactRow('Student', r.studentName),
                    if (r.admissionNo != null) FactRow('Admission no.', r.admissionNo!),
                    if (r.gradeSection != null) FactRow('Class', r.gradeSection!),
                    FactRow('Invoice', r.invoiceNo),
                  ],
                ),
              ),
              const GroupLabel('Paid for'),
              RowGroup(padding: const EdgeInsets.symmetric(vertical: Gaps.xs), children: [for (final it in r.items) Padding(padding: const EdgeInsets.symmetric(horizontal: Gaps.lg), child: FactRow(it.description, formatMinor(it.amountMinor, currency: r.currency)))]),
              const SizedBox(height: Gaps.md),
              AppCard(
                child: Column(children: [
                  FactRow('Amount paid', formatMinor(r.amountMinor, currency: r.currency), bold: true),
                  FactRow('Method', _method(r.method)),
                  if (r.reference != null) FactRow('Reference', r.reference!),
                  if (r.receivedBy != null) FactRow('Received by', r.receivedBy!),
                ]),
              ),
              const SizedBox(height: Gaps.xl),
              SecondaryButton(label: _busy ? 'Preparing PDF' : 'Open as PDF', icon: Icons.picture_as_pdf_outlined, onPressed: _busy ? null : () => _pdf(r)),
            ],
          ),
        ),
      ),
    );
  }

  static String _method(String m) => switch (m) { 'bank_transfer' => 'Bank transfer', 'upi' => 'UPI', _ => '${m[0].toUpperCase()}${m.substring(1)}' };
}
