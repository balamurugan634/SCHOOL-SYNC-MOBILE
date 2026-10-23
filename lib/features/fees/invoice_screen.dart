import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/models/fees.dart';
import '../../router/routes_shared.dart';
import '../auth/session.dart';
import '../learner/learner_context.dart';
import '../security/secure_scope.dart';
import 'fees_providers.dart';

/// One invoice: line items, totals, payments, and (parents, when enabled) online payment.
class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(invoiceProvider(invoiceId));
    final site = ref.watch(sessionProvider.select((s) => s.siteInfo));
    final isParent = ref.watch(isParentProvider);
    final currency = site?.currency ?? 'INR';
    Future<void> refresh() async {
      ref.invalidate(invoiceProvider(invoiceId));
      try {
        await ref.read(invoiceProvider(invoiceId).future);
      } catch (_) {}
    }

    return SecureScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: AsyncBody<Invoice>(
          value: v,
          onRetry: refresh,
          data: (i) {
            final t = context.tokens;
            final canPayOnline = isParent && i.payable && (site?.features.onlinePayments ?? false) && !(site?.readOnly ?? false);
            return RefreshScroll(
              onRefresh: refresh,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.invoiceNo, style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
                      const SizedBox(height: 2),
                      Text(i.title, style: context.text.headlineSmall),
                      const SizedBox(height: Gaps.md),
                      Wrap(spacing: 6, children: [
                        StatusChip(i.isPaid ? 'Paid' : (i.isVoid ? 'Void' : (i.overdue ? 'Overdue ${plural(i.daysOverdue, 'day')}' : (i.status == 'partial' ? 'Part paid' : 'Unpaid'))), tone: i.isPaid ? StatusTone.success : (i.overdue ? StatusTone.danger : StatusTone.neutral)),
                      ]),
                      const Divider(height: Gaps.xl),
                      if (i.studentName != null) FactRow('Student', i.studentName!),
                      if (i.dueDate != null) FactRow('Due date', fmtFull(i.dueDate!)),
                    ],
                  ),
                ),
                const GroupLabel('Details'),
                RowGroup(
                  padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
                  children: [
                    for (final it in i.items) Padding(padding: const EdgeInsets.symmetric(horizontal: Gaps.lg), child: FactRow(it.description, formatMinor(it.amountMinor, currency: currency))),
                  ],
                ),
                const SizedBox(height: Gaps.md),
                AppCard(
                  child: Column(
                    children: [
                      FactRow('Total', formatMinor(i.totalMinor, currency: currency)),
                      if (i.discountMinor > 0) FactRow('Discount', '-${formatMinor(i.discountMinor, currency: currency)}'),
                      if (i.lateFeeMinor > 0) FactRow('Late fee', formatMinor(i.lateFeeMinor, currency: currency)),
                      FactRow('Paid', formatMinor(i.paidMinor, currency: currency)),
                      const Divider(),
                      FactRow('Balance', formatMinor(i.balanceMinor + i.lateFeeMinor, currency: currency), bold: true),
                    ],
                  ),
                ),
                if (i.payments.isNotEmpty) ...[
                  const GroupLabel('Payments'),
                  RowGroup(children: [for (final p in i.payments) ListRow(title: p.receiptNo ?? 'Payment', subtitle: [p.methodLabel, if (p.paidAt != null) fmtFull(p.paidAt!)].join('  ·  '), trailing: Text(formatMinor(p.amountMinor, currency: currency), style: context.text.labelLarge), chevron: false, onTap: p.succeeded ? () => context.push(SharedRoutes.receipt(p.id)) : null)]),
                ],
                if (canPayOnline) ...[const SizedBox(height: Gaps.xl), PrimaryButton(label: 'Pay ${formatMinor(i.amountDueNowMinor > 0 ? i.amountDueNowMinor : i.balanceMinor, currency: currency)}', icon: Icons.lock_outline_rounded, onPressed: () => context.push(SharedRoutes.pay(i.id)))]
                else if (isParent && i.payable) ...[
                  const SizedBox(height: Gaps.xl),
                  InfoBanner(message: (site?.features.onlinePayments ?? false) ? 'Online payment is paused while the school subscription is inactive. Please pay at the school office.' : 'Online payment is not turned on for this school. Please pay at the school office.'),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
