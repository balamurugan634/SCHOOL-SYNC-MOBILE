import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/util/format.dart';
import '../../data/json.dart';
import '../../data/models/leave.dart';
import '../../data/repositories/files_repository.dart';
import '../../data/repositories/leave_repository.dart';
import '../dashboard/dashboard_providers.dart';
import '../learner/learner_context.dart';
import '../learner/screen_frame.dart';
import 'leave_providers.dart';

/// Apply for leave (a parent for the selected child, a student for themselves).
class LeaveFormScreen extends ConsumerStatefulWidget {
  const LeaveFormScreen({super.key});

  @override
  ConsumerState<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends ConsumerState<LeaveFormScreen> {
  LeaveType _type = LeaveType.sick;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  final _reason = TextEditingController();
  Attachment? _file;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool from) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: from ? _from : _to, firstDate: now.subtract(const Duration(days: 30)), lastDate: now.add(const Duration(days: 365)));
    if (d == null) return;
    setState(() {
      if (from) {
        _from = d;
        if (_to.isBefore(d)) _to = d;
      } else {
        _to = d.isBefore(_from) ? _from : d;
      }
    });
  }

  Future<void> _attach() async {
    final picked = await FilePicker.pickFile();
    final path = picked?.path;
    if (picked == null || path == null) return;
    setState(() => _uploading = true);
    try {
      final a = await ref.read(filesRepositoryProvider).upload(path, name: picked.name, purpose: 'document');
      if (mounted) setState(() => _file = a);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not upload the file: ${AppException.from(e).displayMessage}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_reason.text.trim().length < 3) {
      setState(() => _error = 'Please give a short reason.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final q = ref.read(learnerQueryIdProvider);
    try {
      await ref.read(leaveRepositoryProvider).apply(studentId: q, type: _type, from: _from, to: _to, reason: _reason.text, attachmentFileId: _file?.fileId);
      ref.invalidate(leaveListProvider(q));
      ref.invalidate(parentDashboardProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave request sent to the school.')));
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
    final name = ref.watch(learnerNameProvider);
    final days = _to.difference(_from).inDays + 1;
    return ScreenFrame(
      title: 'Apply for leave',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.huge),
        children: [
          if (name != null) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: Text('For $name', style: context.text.titleMedium)),
          Text('Type of leave', style: context.text.labelMedium),
          const SizedBox(height: 6),
          FilterChips<LeaveType>(options: LeaveType.values, selected: _type, onSelected: (t) => setState(() => _type = t), labelOf: (t) => t.label, padding: EdgeInsets.zero),
          const SizedBox(height: Gaps.lg),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(true), icon: const Icon(Icons.event_outlined, size: 18), label: Text('From ${fmtShort(_from)}'))),
            const SizedBox(width: Gaps.sm),
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(false), icon: const Icon(Icons.event_outlined, size: 18), label: Text('To ${fmtShort(_to)}'))),
          ]),
          Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(plural(days, 'day'), style: context.text.bodySmall)),
          const SizedBox(height: Gaps.md),
          TextField(controller: _reason, minLines: 3, maxLines: 5, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Reason', alignLabelWithHint: true)),
          const SizedBox(height: Gaps.md),
          if (_file != null) ListRow(title: _file!.name, subtitle: fileSize(_file!.sizeBytes), leading: Icons.insert_drive_file_outlined, dense: true, chevron: false, trailing: IconButton(tooltip: 'Remove', icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => _file = null)))
          else SecondaryButton(label: _uploading ? 'Uploading' : 'Attach a note (optional)', icon: Icons.attach_file_rounded, onPressed: _uploading ? null : _attach),
          if (_error != null) ...[const SizedBox(height: Gaps.md), InfoBanner(tone: BannerTone.danger, message: _error!)],
          const SizedBox(height: Gaps.xl),
          PrimaryButton(label: 'Send request', loading: _saving, onPressed: _uploading ? null : _save),
        ],
      ),
    );
  }
}
