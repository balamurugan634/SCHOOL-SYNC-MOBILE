import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/util/format.dart';
import '../../data/models/fees.dart';
import '../../data/repositories/fees_repository.dart';
import '../../router/routes_shared.dart';
import '../auth/session.dart';
import '../dashboard/dashboard_providers.dart';
import '../security/secure_scope.dart';
import 'fees_providers.dart';

enum _Phase { review, starting, waiting, success, failed }

/// Online payment for a child's invoice (parents). The invoice is only marked paid when the server has
/// the gateway's confirmation, so after starting we poll the payment (and can ask the server to re-check).
///
/// The development gateway ("mock") can be completed from here; the live Razorpay checkout needs its native SDK,
/// which this build does not ship, so there the person is told to use another way to pay.
class PayScreen extends ConsumerStatefulWidget {
  const PayScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  ConsumerState<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends ConsumerState<PayScreen> {
  _Phase _phase = _Phase.review;
  PayOrder? _order;
  Payment? _payment;
  String? _error;
  Timer? _poll;
  int _polls = 0;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start(Invoice inv) async {
    setState(() {
      _phase = _Phase.starting;
      _error = null;
    });
    try {
      final amount = inv.amountDueNowMinor > 0 ? inv.amountDueNowMinor : inv.balanceMinor;
      final order = await ref.read(feesRepositoryProvider).startPayment(inv.id, amountMinor: amount);
      if (!mounted) return;
      setState(() {
        _order = order;
        _phase = _Phase.waiting;
      });
      _startPolling(order.paymentId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.failed;
          _error = AppException.from(e).displayMessage;
        });
      }
    }
  }

  void _startPolling(String paymentId) {
    _poll?.cancel();
    _polls = 0;
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check(paymentId));
  }

  Future<void> _check(String paymentId, {bool sync = false}) async {
    _polls++;
    try {
      final repo = ref.read(feesRepositoryProvider);
      final p = sync ? await repo.syncPayment(paymentId) : await repo.payment(paymentId);
      if (!mounted) return;
      if (p.status == 'succeeded') {
        _poll?.cancel();
        ref.invalidate(invoiceProvider(widget.invoiceId));
        ref.invalidate(parentDashboardProvider);
        ref.invalidate(invoicesProvider);
        ref.invalidate(paymentsProvider);
        setState(() {
          _payment = p;
          _phase = _Phase.success;
        });
      } else if (p.status == 'failed') {
        _poll?.cancel();
        setState(() {
          _phase = _Phase.failed;
          _error = 'The payment did not go through. You have not been charged.';
        });
      } else if (_polls > 40) {
        _poll?.cancel();
      }
    } catch (_) {
      // Transient errors while polling are ignored; the person can press "Check status".
    }
  }

  Future<void> _mockComplete() async {
    final o = _order;
    if (o == null) return;
    try {
      await ref.read(feesRepositoryProvider).mockComplete(o.paymentId);
      await _check(o.paymentId, sync: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = ref.watch(invoiceProvider(widget.invoiceId));
    final currency = ref.watch(sessionProvider.select((s) => s.siteInfo?.currency ?? 'INR'));
    final t = context.tokens;
    return SecureScope(
      child: PopScope(
        canPop: _phase != _Phase.starting,
        child: Scaffold(
          appBar: AppBar(title: const Text('Pay online')),
          body: AsyncBody<Invoice>(
            value: inv,
            onRetry: () => ref.invalidate(invoiceProvider(widget.invoiceId)),
            data: (i) {
              final amount = i.amountDueNowMinor > 0 ? i.amountDueNowMinor : i.balanceMinor;
              return ListView(
                padding: const EdgeInsets.all(Gaps.page),
                children: [
                  switch (_phase) {
                    _Phase.success => Column(children: [
                      const SizedBox(height: Gaps.lg),
                      const IllustrationView(Illo.success, width: 200, decorative: true),
                      const SizedBox(height: Gaps.md),
                      Text('Payment received', style: context.text.headlineMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Text('${formatMinor(_payment?.amountMinor ?? amount, currency: currency)} paid for ${i.title}.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary), textAlign: TextAlign.center),
                      const SizedBox(height: Gaps.xl),
                      if (_payment != null) PrimaryButton(label: 'View receipt', onPressed: () => context.pushReplacement(SharedRoutes.receipt(_payment!.id))),
                      const SizedBox(height: Gaps.sm),
                      SecondaryButton(label: 'Back to fees', onPressed: () => context.pop()),
                    ]),
                    _Phase.waiting => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)), const SizedBox(width: Gaps.md), Text('Waiting for the payment', style: context.text.titleMedium)]),
                        const SizedBox(height: Gaps.sm),
                        Text(_order?.mock ?? false ? 'This school uses the test payment gateway. Complete the test payment below.' : 'Finish the payment in the checkout. We will update here as soon as the bank confirms it.', style: context.text.bodyMedium),
                      ])),
                      const SizedBox(height: Gaps.md),
                      if (_order?.mock ?? false) PrimaryButton(label: 'Complete test payment', onPressed: _mockComplete)
                      else const InfoBanner(tone: BannerTone.warning, title: 'Checkout is not available in this app version', message: 'The live payment checkout needs a newer version of the app. Please pay at the school office or on the school website, then pull to refresh here.'),
                      const SizedBox(height: Gaps.sm),
                      SecondaryButton(label: 'Check status', icon: Icons.refresh_rounded, onPressed: _order == null ? null : () => _check(_order!.paymentId, sync: true)),
                    ]),
                    _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      AppCard(child: Column(children: [
                        Text(i.title, style: context.text.titleMedium, textAlign: TextAlign.center),
                        const SizedBox(height: Gaps.md),
                        Text(formatMinor(amount, currency: currency), style: figureStyle(context, size: 40)),
                        Text('to pay now', style: context.text.bodySmall),
                      ])),
                      if (_error != null) ...[const SizedBox(height: Gaps.md), InfoBanner(tone: BannerTone.danger, message: _error!)],
                      const SizedBox(height: Gaps.lg),
                      PrimaryButton(label: _phase == _Phase.failed ? 'Try again' : 'Pay ${formatMinor(amount, currency: currency)}', icon: Icons.lock_outline_rounded, loading: _phase == _Phase.starting, onPressed: () => _start(i)),
                      const SizedBox(height: Gaps.md),
                      Text('Payments are processed securely. Your card or bank details are never stored in this app.', style: context.text.bodySmall, textAlign: TextAlign.center),
                    ]),
                  },
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
