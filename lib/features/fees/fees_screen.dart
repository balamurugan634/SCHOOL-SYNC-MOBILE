import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/paged.dart';
import '../../core/util/format.dart';
import '../../data/models/fees.dart';
import '../../router/routes_shared.dart';
import '../auth/session.dart';
import '../learner/screen_frame.dart';
import '../security/secure_scope.dart';
import 'fees_providers.dart';

enum _Tab { invoices, payments }

/// Fees: what is due, invoice history and payment receipts.
class FeesScreen extends ConsumerStatefulWidget {
  const FeesScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends ConsumerState<FeesScreen> {
  _Tab _tab = _Tab.invoices;

  @override
  Widget build(BuildContext context) {
    final studentId = ref.watch(feesQueryProvider);
    final currency = ref.watch(sessionProvider.select((s) => s.siteInfo?.currency ?? 'INR'));
    final inv = ref.watch(invoicesProvider((studentId: studentId, status: null)));
    final pay = ref.watch(paymentsProvider(studentId));

    Future<void> refresh() async {
      ref.invalidate(invoicesProvider((studentId: studentId, status: null)));
      ref.invalidate(paymentsProvider(studentId));
      try {
        await ref.read(invoicesProvider((studentId: studentId, status: null)).future);
      } catch (_) {}
    }

    return SecureScope(
      child: ScreenFrame(
        title: 'Fees',
        subtitle: widget.embedded ? 'Balance, dues, receipts and payments.' : null,
        embedded: widget.embedded,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.sm),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_Tab>(
                  showSelectedIcon: false,
                  segments: const [ButtonSegment(value: _Tab.invoices, label: Text('Invoices')), ButtonSegment(value: _Tab.payments, label: Text('Payments'))],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
              ),
            ),
            Expanded(
              child: _tab == _Tab.invoices
                  ? AsyncBody<PagedList<Invoice>>(
                      value: inv,
                      onRetry: refresh,
                      isEmpty: (p) => p.items.isEmpty,
                      empty: const EmptyState(illo: Illo.emptyGeneric, title: 'No invoices', message: 'Fee invoices appear here once the school issues them.'),
                      data: (p) {
                        final open = p.items.where((i) => i.payable).toList();
                        final due = open.fold<int>(0, (a, i) => a + i.amountDueNowMinor);
                        final overdue = open.where((i) => i.overdue).fold<int>(0, (a, i) => a + i.balanceMinor);
                        return RefreshScroll(
                          onRefresh: refresh,
                          children: [
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(open.isEmpty ? 'All paid' : 'Due now', style: context.text.labelMedium?.copyWith(color: context.tokens.textSecondary)),
                                  Text(open.isEmpty ? formatMinor(0, currency: currency) : formatMinor(due, currency: currency), style: figureStyle(context, size: 36)),
                                  if (overdue > 0) Padding(padding: const EdgeInsets.only(top: 6), child: StatusChip('${formatMinor(overdue, currency: currency)} overdue', tone: StatusTone.danger, icon: Icons.warning_amber_rounded)),
                                ],
                              ),
                            ),
                            const GroupLabel('Invoices'),
                            RowGroup(children: [for (final i in p.items) _InvoiceRow(i, currency)]),
                            LoadMoreFooter(paged: p, onMore: () => ref.read(invoicesProvider((studentId: studentId, status: null)).notifier).loadMore()),
                          ],
                        );
                      },
                    )
                  : AsyncBody<PagedList<Payment>>(
                      value: pay,
                      onRetry: refresh,
                      isEmpty: (p) => p.items.isEmpty,
                      empty: const EmptyState(illo: Illo.emptyGeneric, title: 'No payments yet', message: 'Receipts appear here after a payment is recorded.'),
                      data: (p) => RefreshScroll(
                        onRefresh: refresh,
                        children: [
                          RowGroup(
                            children: [
                              for (final x in p.items)
                                ListRow(
                                  title: x.receiptNo ?? x.invoiceNo,
                                  subtitle: [x.methodLabel, if (x.paidAt != null) fmtFull(x.paidAt!), x.invoiceNo].join('  ·  '),
                                  trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(formatMinor(x.amountMinor, currency: currency), style: context.text.labelLarge), _payChip(x)]),
                                  onTap: x.succeeded ? () => context.push(SharedRoutes.receipt(x.id)) : null,
                                  chevron: false,
                                ),
                            ],
                          ),
                          LoadMoreFooter(paged: p, onMore: () => ref.read(paymentsProvider(studentId).notifier).loadMore()),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payChip(Payment p) => switch (p.status) {
    'succeeded' => const StatusChip('Paid', tone: StatusTone.success),
    'pending' => const StatusChip('Pending', tone: StatusTone.warning),
    'failed' => const StatusChip('Failed', tone: StatusTone.danger),
    'refunded' => const StatusChip('Refunded'),
    'partially_refunded' => const StatusChip('Part refunded'),
    _ => const SizedBox.shrink(),
  };
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow(this.i, this.currency);
  final Invoice i;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tone = i.isPaid ? StatusTone.success : (i.overdue ? StatusTone.danger : (i.status == 'partial' ? StatusTone.warning : StatusTone.neutral));
    final label = i.isPaid ? 'Paid' : (i.isVoid ? 'Void' : (i.overdue ? 'Overdue' : (i.status == 'partial' ? 'Part paid' : 'Unpaid')));
    return ListRow(
      title: i.title,
      subtitle: [i.invoiceNo, if (i.dueDate != null) 'Due ${fmtShort(i.dueDate!)}'].join('  ·  '),
      onTap: () => context.push(SharedRoutes.invoice(i.id)),
      chevron: false,
      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(formatMinor(i.isPaid ? i.totalMinor : i.balanceMinor, currency: currency), style: context.text.labelLarge), StatusChip(label, tone: tone)]),
    );
  }
}
