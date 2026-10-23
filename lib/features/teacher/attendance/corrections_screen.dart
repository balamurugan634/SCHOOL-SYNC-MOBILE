import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/paged.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../../data/repositories/staff/roll_call_repository.dart';
import '../../workspace/workspace.dart';
import 'attendance_providers.dart';
import 'detail_sheet.dart';

/// Attendance correction requests. "To decide": what I may approve or reject (class teacher of the section, or the
/// office); "My requests": the ones I raised, by status. Rejecting needs a note.
class CorrectionsScreen extends ConsumerWidget {
  const CorrectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDecide = ref.can('attendance:approve');
    final tabs = [if (canDecide) 'To decide', 'My requests'];
    return FeatureGate(
      label: 'Corrections',
      anyPermission: const ['attendance:view', 'attendance:create'],
      child: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Corrections'),
            bottom: tabs.length > 1 ? TabBar(tabs: [for (final t in tabs) Tab(text: t)]) : null,
          ),
          body: TabBarView(children: [if (canDecide) const _CorrectionList(query: (status: 'pending', mine: false), emptyTitle: 'Nothing to decide', emptyMessage: 'When a teacher asks for a change to a saved roll call it will wait here for you.', decidable: true), const _MyRequests()]),
        ),
      ),
    );
  }
}

class _MyRequests extends StatefulWidget {
  const _MyRequests();

  @override
  State<_MyRequests> createState() => _MyRequestsState();
}

class _MyRequestsState extends State<_MyRequests> {
  String _status = 'pending';
  static const _labels = {'pending': 'Pending', 'approved': 'Approved', 'rejected': 'Rejected'};

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: Gaps.sm),
      FilterChips<String>(options: _labels.keys.toList(), selected: _status, onSelected: (s) => setState(() => _status = s), labelOf: (s) => _labels[s]!),
      const SizedBox(height: Gaps.sm),
      Expanded(
        child: _CorrectionList(
          query: (status: _status, mine: true),
          emptyTitle: 'No ${_labels[_status]!.toLowerCase()} requests',
          emptyMessage: _status == 'pending' ? 'Open a closed roll call and tap a student to ask for a change.' : null,
          decidable: false,
        ),
      ),
    ],
  );
}

class _CorrectionList extends ConsumerWidget {
  const _CorrectionList({required this.query, required this.emptyTitle, this.emptyMessage, required this.decidable});
  final CorrectionQuery query;
  final String emptyTitle;
  final String? emptyMessage;
  final bool decidable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = correctionsProvider(query);
    final v = ref.watch(provider);
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return AsyncBody<PagedList<CorrectionItem>>(
      value: v,
      onRetry: () => ref.invalidate(provider),
      isEmpty: (p) => p.items.isEmpty,
      empty: RefreshScroll(onRefresh: refresh, children: [EmptyState(icon: Icons.rule_rounded, title: emptyTitle, message: emptyMessage)]),
      data: (p) => RefreshScroll(
        onRefresh: refresh,
        children: [
          RowGroup(children: [for (final c in p.items) CorrectionTile(item: c, onTap: () => openCorrection(context, ref, c))]),
          LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
        ],
      ),
    );
  }
}

class CorrectionTile extends StatelessWidget {
  const CorrectionTile({super.key, required this.item, required this.onTap});
  final CorrectionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: '${item.studentName}, ${item.sectionName}, ${fmtDay(item.date)}, change from ${item.fromStatus?.label ?? 'unknown'} to ${item.toStatus?.label ?? 'unknown'}, ${item.pending ? 'pending' : item.status}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(item.studentName, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  const SizedBox(width: Gaps.sm),
                  DecisionChip(item.status),
                ],
              ),
              const SizedBox(height: 2),
              Text('${item.sectionName} · ${fmtDay(item.date)}', style: context.text.bodySmall),
              const SizedBox(height: Gaps.sm),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [AttendanceChip(item.fromStatus), Icon(Icons.arrow_forward_rounded, size: 16, color: t.textTertiary), AttendanceChip(item.toStatus)],
              ),
              const SizedBox(height: Gaps.sm),
              Text(item.reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
              if (item.requestedByName != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Requested by ${item.requestedByName}${item.createdAt != null ? ', ${relativeDay(item.createdAt!)}' : ''}', style: context.text.labelSmall?.copyWith(color: t.textTertiary))),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the sheet shows about a request.
class CorrectionDetails extends StatelessWidget {
  const CorrectionDetails({super.key, required this.item});
  final CorrectionItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.studentName, style: context.text.titleMedium),
        Text('${item.sectionName}${item.rollNo != null ? ' · Roll ${item.rollNo}' : ''} · ${item.admissionNo}', style: context.text.bodySmall),
        const SizedBox(height: Gaps.md),
        DetailBlock('Date', fmtDayLong(item.date)),
        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [AttendanceChip(item.fromStatus), Icon(Icons.arrow_forward_rounded, size: 16, color: t.textTertiary), AttendanceChip(item.toStatus)]),
        const SizedBox(height: Gaps.md),
        DetailBlock('Reason', item.reason),
        if (item.requestedByName != null) DetailBlock('Requested by', '${item.requestedByName}${item.createdAt != null ? ' on ${fmtDateTime(item.createdAt!)}' : ''}'),
        if (!item.pending) ...[
          DetailBlock('Decision', '${item.status == 'approved' ? 'Approved' : 'Rejected'}${item.decidedByName != null ? ' by ${item.decidedByName}' : ''}${item.decidedAt != null ? ' on ${fmtDateTime(item.decidedAt!)}' : ''}'),
          if (item.decisionNote != null && item.decisionNote!.isNotEmpty) DetailBlock('Note', item.decisionNote!),
        ],
      ],
    );
  }
}

/// Opens the decision sheet (approve / reject with a note) when I may decide, otherwise a read-only detail.
Future<void> openCorrection(BuildContext context, WidgetRef ref, CorrectionItem item) async {
  if (!(item.pending && item.canDecide)) {
    await showDetailSheet(context, title: 'Correction request', child: CorrectionDetails(item: item));
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  final done = await showDecisionSheet(
    context,
    title: 'Correction request',
    details: CorrectionDetails(item: item),
    approveConsequence: 'The record changes to ${item.toStatus?.label ?? 'the new status'} and the student\'s guardians are told.',
    rejectConsequence: 'The record stays as it is. ${item.requestedByName ?? 'The teacher'} will be told why.',
    onDecide: (approve, note) async {
      try {
        await ref.read(rollCallRepositoryProvider).decideCorrection(item.id, approve: approve, note: note);
      } catch (e) {
        if (isStaleStateError(e)) ref.invalidate(correctionsProvider);
        rethrow;
      }
    },
  );
  if (done) {
    ref.invalidate(correctionsProvider);
    ref.invalidate(attendanceTodayProvider);
    messenger.showSnackBar(const SnackBar(content: Text('Decision saved.')));
  }
}
