import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/people.dart';
import '../../security/secure_scope.dart';
import '../../workspace/workspace.dart';
import 'people_providers.dart';

/// Read-only staff profile: contact (tap to call or email), role, workload. The API decides what this role may see.
class StaffProfileScreen extends ConsumerWidget {
  const StaffProfileScreen({super.key, required this.staffId});
  final String staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(staffDetailProvider(staffId));
    return SecureScope(child: StaffFrame(
      title: 'Staff',
      body: AsyncBody<StaffDetail>(
        value: detail,
        onRetry: () => ref.invalidate(staffDetailProvider(staffId)),
        data: (d) => RefreshScroll(
          onRefresh: () async {
            ref.invalidate(staffDetailProvider(staffId));
            ref.invalidate(staffWorkloadProvider(staffId));
            try {
              await ref.read(staffDetailProvider(staffId).future);
            } catch (_) {}
          },
          children: [_Header(d: d), const SizedBox(height: Gaps.md), _Contact(m: d.member), const SizedBox(height: Gaps.md), _Work(d: d, staffId: staffId)],
        ),
      ),
    ));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.d});
  final StaffDetail d;

  @override
  Widget build(BuildContext context) {
    final m = d.member;
    return AppCard(
      child: Row(
        children: [
          UserAvatar(name: m.name, url: m.photoUrl, size: 56),
          const SizedBox(width: Gaps.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(m.name, style: context.text.titleLarge)),
                if (m.designation != null) Text(m.designation!, style: context.text.bodyMedium),
                const SizedBox(height: Gaps.xs),
                Wrap(spacing: Gaps.xs, runSpacing: Gaps.xs, children: [StatusChip(m.staffType == 'teaching' ? 'Teaching' : 'Non-teaching'), if (m.status != 'active') StatusChip(m.status, tone: StatusTone.warning, icon: Icons.info_outline_rounded)]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({required this.m});
  final StaffMember m;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Contact',
    padding: const EdgeInsets.only(bottom: Gaps.xs),
    child: Column(
      children: [
        ListRow(title: m.phone ?? 'No phone number', subtitle: 'Phone', leading: Icons.call_outlined, onTap: m.phone == null || m.phone!.isEmpty ? null : () => callPhone(context, m.phone), chevron: false),
        if (m.email != null) ListRow(title: m.email!, subtitle: 'Email', leading: Icons.mail_outline_rounded, chevron: false),
        ListRow(title: m.employeeId, subtitle: 'Employee ID', leading: Icons.badge_outlined, chevron: false),
      ],
    ),
  );
}

class _Work extends ConsumerWidget {
  const _Work({required this.d, required this.staffId});
  final StaffDetail d;
  final String staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(staffWorkloadProvider(staffId)).value;
    return SectionCard(
      title: 'Role and workload',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.member.roles.isNotEmpty) FactRow('Roles', d.member.roles.map((r) => r.split('_').map((x) => x.isEmpty ? x : x[0].toUpperCase() + x.substring(1)).join(' ')).join(', ')),
          if (d.joinDate != null) FactRow('Joined', fmtFull(d.joinDate!)),
          if (d.qualification != null) FactRow('Qualification', d.qualification!),
          if (w != null) ...[
            FactRow('Periods per week', '${w.periodsPerWeek}'),
            if (w.sectionsLed.isNotEmpty) FactRow('Class teacher of', w.sectionsLed.join(', ')),
            if (w.assignments.isNotEmpty) ...[
              const SizedBox(height: Gaps.sm),
              Text('Teaches', style: context.text.labelMedium?.copyWith(color: context.tokens.textSecondary)),
              const SizedBox(height: Gaps.xs),
              for (final a in w.assignments) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(a, style: context.text.bodyMedium)),
            ],
          ] else
            Text('Workload is not available.', style: context.text.bodySmall),
        ],
      ),
    );
  }
}
