import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/models/learner_extras.dart';
import '../learner/screen_frame.dart';
import 'learning_providers.dart';

/// The school bus: route, stop, pick-up and drop times, and who to call.
class TransportScreen extends ConsumerWidget {
  const TransportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(myBusProvider);
    Future<void> refresh() async {
      ref.invalidate(myBusProvider);
      try {
        await ref.read(myBusProvider.future);
      } catch (_) {}
    }

    return ScreenFrame(
      title: 'School bus',
      body: AsyncBody<List<BusAllocation>>(
        value: v,
        onRetry: refresh,
        isEmpty: (l) => l.isEmpty || l.every((b) => !b.allocated),
        empty: const EmptyState(illo: Illo.emptyGeneric, title: 'Not on a school bus', message: 'If your child should be on a route, ask the school office.'),
        data: (list) => RefreshScroll(
          onRefresh: refresh,
          children: [for (final b in list.where((b) => b.allocated)) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: _BusCard(b: b))],
        ),
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  const _BusCard({required this.b});
  final BusAllocation b;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(b.studentName, style: context.text.labelMedium?.copyWith(color: context.tokens.textSecondary)),
        Text(b.routeName ?? 'Route', style: context.text.headlineSmall),
        const Divider(height: Gaps.xl),
        if (b.stopName != null) FactRow('Stop', b.stopName!),
        if (b.pickupTime != null) FactRow('Morning pick-up', formatClock(b.pickupTime)),
        if (b.dropTime != null) FactRow('Evening drop', formatClock(b.dropTime)),
        if (b.vehicle != null && b.vehicle!.isNotEmpty) FactRow('Vehicle', b.vehicle!),
        if (b.driverName != null) FactRow('Driver', b.driverName!),
        if (b.attendantName != null) FactRow('Attendant', b.attendantName!),
        if (b.driverPhone != null) Padding(padding: const EdgeInsets.only(top: Gaps.md), child: SecondaryButton(label: 'Call the driver', icon: Icons.call_outlined, onPressed: () => launchUrl(Uri(scheme: 'tel', path: b.driverPhone)))),
      ],
    ),
  );
}
