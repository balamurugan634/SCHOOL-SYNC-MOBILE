import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/util/format.dart';
import '../../data/models/meetings.dart';
import '../../data/repositories/meetings_repository.dart';
import '../dashboard/dashboard_providers.dart';
import '../home/child_selector.dart';
import 'meetings_providers.dart';

/// Ask a teacher of the selected child for a meeting.
class MeetingRequestScreen extends ConsumerStatefulWidget {
  const MeetingRequestScreen({super.key});

  @override
  ConsumerState<MeetingRequestScreen> createState() => _MeetingRequestScreenState();
}

class _MeetingRequestScreenState extends ConsumerState<MeetingRequestScreen> {
  String? _staffId;
  final _topic = TextEditingController();
  DateTime? _when;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _when ?? now.add(const Duration(days: 2)), firstDate: now, lastDate: now.add(const Duration(days: 120)));
    if (d == null || !mounted) return;
    final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when ?? DateTime(now.year, now.month, now.day, 10)));
    if (!mounted) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, tm?.hour ?? 10, tm?.minute ?? 0));
  }

  Future<void> _send(String studentId) async {
    if (_staffId == null) {
      setState(() => _error = 'Choose a teacher.');
      return;
    }
    if (_topic.text.trim().length < 3) {
      setState(() => _error = 'Say briefly what you would like to discuss.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(meetingsRepositoryProvider).request(studentId: studentId, staffId: _staffId!, topic: _topic.text, proposedAt: _when);
      ref.invalidate(meetingsProvider);
      ref.invalidate(parentDashboardProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent. You will be notified when the teacher answers.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppException.from(e).displayMessage;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(selectedChildProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Request a meeting')),
      body: child == null
          ? const EmptyState(illo: Illo.firstUse, title: 'No child selected')
          : ListView(
              padding: const EdgeInsets.all(Gaps.page),
              children: [
                const ChildSelector(),
                const SizedBox(height: Gaps.lg),
                Text('Which teacher?', style: context.text.titleMedium),
                const SizedBox(height: Gaps.sm),
                ref.watch(meetingTeachersProvider(child.studentId)).when(
                  loading: () => const SkeletonList(count: 3, padding: EdgeInsets.zero),
                  error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(meetingTeachersProvider(child.studentId))),
                  data: (teachers) => RowGroup(
                    children: [
                      for (final MeetingTeacher t in teachers)
                        ListRow(
                          title: t.name,
                          subtitle: [if (t.isClassTeacher) 'Class teacher', if (t.subjects.isNotEmpty) t.subjects.join(', ')].join('  ·  '),
                          leading: _staffId == t.staffId ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                          chevron: false,
                          onTap: () => setState(() => _staffId = t.staffId),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Gaps.lg),
                TextField(controller: _topic, minLines: 2, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What would you like to discuss?', alignLabelWithHint: true)),
                const SizedBox(height: Gaps.md),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _pickWhen, icon: const Icon(Icons.event_outlined, size: 18), label: Text(_when == null ? 'Suggest a time (optional)' : fmtDateTime(_when!)))),
                  if (_when != null) IconButton(tooltip: 'Clear', onPressed: () => setState(() => _when = null), icon: const Icon(Icons.close_rounded)),
                ]),
                if (_error != null) ...[const SizedBox(height: Gaps.md), InfoBanner(tone: BannerTone.danger, message: _error!)],
                const SizedBox(height: Gaps.xl),
                PrimaryButton(label: 'Send request', loading: _saving, onPressed: () => _send(child.studentId)),
              ],
            ),
    );
  }
}
