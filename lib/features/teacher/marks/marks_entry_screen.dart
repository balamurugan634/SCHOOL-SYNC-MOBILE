import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../data/models/staff/marks.dart';
import '../../../data/repositories/staff/marks_repository.dart';
import '../../security/secure_scope.dart';
import '../../workspace/workspace.dart';
import '../homework/homework_widgets.dart' show LabelledMeter;
import 'marks_logic.dart';
import 'marks_providers.dart';
import 'marks_widgets.dart';

/// Enter marks for one mark sheet (exam x class x subject): fast numeric entry, absent toggle, save draft, submit.
class MarksEntryScreen extends ConsumerWidget {
  const MarksEntryScreen({super.key, required this.sheetId});
  final String sheetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(markSheetProvider(sheetId));
    if (v.hasValue) return MarksEntryBody(key: ValueKey(sheetId), detail: v.requireValue);
    return StaffFrame(
      title: 'Marks',
      body: v.hasError
          ? ErrorState(error: v.error!, onRetry: () => ref.invalidate(markSheetProvider(sheetId)))
          : const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: Padding(padding: EdgeInsets.only(top: Gaps.sm), child: SkeletonList(count: 6))),
    );
  }
}

class _Row {
  _Row(MarkEntry e)
    : id = e.studentId,
      name = e.name,
      rollNo = e.rollNo,
      controller = TextEditingController(text: e.marksObtained == null ? '' : fmtMark(e.marksObtained!)),
      focus = FocusNode(debugLabel: 'marks-${e.studentId}'),
      absent = e.isAbsent,
      remarks = e.remarks ?? '';

  final String id;
  final String name;
  final int? rollNo;
  final TextEditingController controller;
  final FocusNode focus;
  bool absent;
  String remarks;

  MarkRowData get data => MarkRowData(studentId: id, name: name, rollNo: rollNo, text: controller.text, absent: absent, remarks: remarks);

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

/// The entry list itself (public for widget tests).
class MarksEntryBody extends ConsumerStatefulWidget {
  const MarksEntryBody({super.key, required this.detail});
  final MarkSheetDetail detail;

  @override
  ConsumerState<MarksEntryBody> createState() => _MarksEntryBodyState();
}

class _MarksEntryBodyState extends ConsumerState<MarksEntryBody> {
  late final List<_Row> _rows;
  late Map<String, MarkRowData> _baseline;
  final _scroll = ScrollController();
  bool _busy = false;
  bool _leaving = false;
  String? _formError;

  MarkSheet get _sheet => widget.detail.sheet;
  bool get _editable => widget.detail.canEdit;
  double get _max => _sheet.maxMarks;

  @override
  void initState() {
    super.initState();
    _rows = [for (final e in widget.detail.entries) _Row(e)];
    _baseline = {for (final e in widget.detail.entries) e.studentId: MarkRowData.fromEntry(e)};
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  List<MarkRowData> get _data => [for (final r in _rows) r.data];

  bool get _dirty => _editable && _rows.any((r) => !r.data.sameAs(_baseline[r.id] ?? MarkRowData(studentId: r.id, name: r.name)));

  // ── focus ──
  void _focusRowAt(int index) {
    if (index < 0 || index >= _rows.length) return;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final target = math.min(_scroll.position.maxScrollExtent, math.max(0.0, 230.0 + index * 112 - 120));
    if (reduce) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: Motion.base, curve: Motion.standard);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rows[index].focus.requestFocus();
    });
  }

  void _next(int from) {
    for (var j = from + 1; j < _rows.length; j++) {
      if (!_rows[j].absent) {
        _rows[j].focus.requestFocus();
        final ctx = _rows[j].focus.context;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: Motion.fast, alignment: .3);
        return;
      }
    }
    FocusScope.of(context).unfocus();
  }

  // ── actions ──
  Future<void> _editRemark(_Row r) async {
    final res = await showDialog<String>(context: context, builder: (_) => _RemarkDialog(name: r.name, initial: r.remarks));
    if (res != null && mounted) setState(() => r.remarks = res);
  }

  bool _guardInvalid(MarksProgress p) {
    if (p.invalid.isEmpty) return true;
    final names = namesSummary([for (final r in p.invalid) r.name]);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fix the marks above ${fmtMark(_max)} first: $names.')));
    _focusRowAt(_rows.indexWhere((r) => r.id == p.invalid.first.studentId));
    return false;
  }

  /// Saves rows that differ from the server. Returns true when nothing is left unsaved.
  Future<bool> _persist({required String? success}) async {
    final p = markProgress(_data, _max);
    if (!_guardInvalid(p)) return false;
    final changed = changedMarkInputs(_data, _baseline, _max);
    if (changed.isEmpty) {
      if (success != null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Everything is already saved.')));
      return true;
    }
    final ids = {for (final c in changed) c.studentId};
    final snapshot = {for (final r in _rows) if (ids.contains(r.id)) r.id: r.data};
    final ok = await runWrite(
      context,
      ref,
      () => ref.read(marksRepositoryProvider).saveEntries(_sheet.id, changed),
      success: success,
      onError: (e) {
        if (mounted) setState(() => _formError = friendlyError(e));
      },
    );
    if (ok && mounted) {
      setState(() {
        _baseline = {..._baseline, ...snapshot};
        _formError = null;
      });
      ref.invalidate(mySheetsProvider);
    }
    return ok;
  }

  Future<void> _saveDraft() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    await _persist(success: 'Draft saved');
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final p = markProgress(_data, _max);
    if (!p.complete) {
      await _explainIncomplete(p);
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'Submit marks for review?',
      message: '${_sheet.subjectName}, ${_sheet.sectionTitle}: ${p.entered} marks and ${p.absent} absent. After submitting you cannot change them unless the reviewer sends the sheet back.',
      confirmLabel: 'Submit',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final saved = await _persist(success: null);
    if (!saved || !mounted) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    final done = await runWrite(
      context,
      ref,
      () => ref.read(marksRepositoryProvider).submit(_sheet.id),
      success: 'Marks submitted for review',
      onError: (e) {
        if (mounted) setState(() => _formError = friendlyError(e));
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) {
      refreshMarks(ref, sheetId: _sheet.id);
      _leaving = true;
      context.pop();
    }
  }

  Future<void> _explainIncomplete(MarksProgress p) async {
    final first = p.invalid.isNotEmpty ? p.invalid.first : p.missing.first;
    final parts = <String>[
      if (p.missing.isNotEmpty) '${p.missing.length} still need a mark or an absent flag: ${namesSummary([for (final r in p.missing) r.name])}.',
      if (p.invalid.isNotEmpty) '${p.invalid.length} have a mark above ${fmtMark(_max)}: ${namesSummary([for (final r in p.invalid) r.name])}.',
    ];
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Not ready to submit'),
        content: Text('Every student needs a mark or an absent flag before the sheet can go for review.\n\n${parts.join('\n')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Close')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(minimumSize: const Size(120, 48)), child: const Text('Go to first')),
        ],
      ),
    );
    if (go == true && mounted) _focusRowAt(_rows.indexWhere((r) => r.id == first.studentId));
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmAction(context, title: 'Leave without saving?', message: 'You have marks that are not saved yet.', confirmLabel: 'Discard', destructive: true);
    if (leave && mounted) {
      setState(() => _leaving = true);
      Navigator.of(context).pop();
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(markSheetProvider(_sheet.id));
    try {
      await ref.read(markSheetProvider(_sheet.id).future);
    } catch (_) {}
  }

  // ── build ──
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final readOnlyMode = ref.watch(readOnlyProvider);
    final progress = markProgress(_data, _max);
    final reason = marksReadOnlyReason(_sheet, canEdit: _editable);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReadOnlyBanner(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text('${_sheet.subjectName}, ${_sheet.sectionTitle}', style: context.text.headlineSmall)),
                  const SizedBox(height: 2),
                  Text('${_sheet.examName}  ·  out of ${fmtMark(_max)}${_sheet.passMarks == null ? '' : '  ·  pass mark ${fmtMark(_sheet.passMarks!)}'}', style: context.text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: Gaps.sm),
            SheetStatusChip(_sheet.status),
          ],
        ),
        const SizedBox(height: Gaps.md),
        if (_sheet.isReturned && (_sheet.returnNote ?? '').isNotEmpty) ...[
          InfoBanner(tone: BannerTone.warning, icon: Icons.undo_rounded, title: 'Sent back for changes', message: '${_sheet.returnNote}\nUpdate the marks and submit again.'),
          const SizedBox(height: Gaps.md),
        ],
        if (reason != null) ...[InfoBanner(icon: Icons.lock_outline_rounded, message: reason), const SizedBox(height: Gaps.md)],
        if (_formError != null) ...[InfoBanner(tone: BannerTone.danger, message: _formError!, onDismiss: () => setState(() => _formError = null)), const SizedBox(height: Gaps.md)],
        if (_editable) ...[
          LabelledMeter(value: progress.fraction, label: '${progress.done} of ${progress.total} done: ${progress.entered} marks entered, ${progress.absent} absent${progress.missing.isEmpty ? '' : ', ${progress.missing.length} to go'}'),
        ] else
          Text('${progress.entered} marks, ${progress.absent} absent', style: context.text.bodySmall),
        const SizedBox(height: Gaps.sm),
      ],
    );

    final list = ListView.builder(
      controller: _scroll,
      scrollCacheExtent: const ScrollCacheExtent.pixels(900),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.page, Gaps.huge),
      itemCount: _rows.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return header;
        final idx = i - 1;
        final r = _rows[idx];
        final isFirst = idx == 0, isLast = idx == _rows.length - 1;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: t.surface,
            border: Border(left: BorderSide(color: t.border), right: BorderSide(color: t.border), top: isFirst ? BorderSide(color: t.border) : BorderSide.none, bottom: BorderSide(color: t.border)),
            borderRadius: BorderRadius.vertical(top: isFirst ? const Radius.circular(Radii.lg) : Radius.zero, bottom: isLast ? const Radius.circular(Radii.lg) : Radius.zero),
          ),
          child: _editable ? _editRow(context, r, idx, isLast) : _readRow(context, r),
        );
      },
    );

    return SecureScope(child: PopScope(
      canPop: _leaving || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: StaffFrame(
        title: 'Marks',
        bottom: _editable
            ? SafeArea(
                child: Container(
                  decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.border))),
                  padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.sm),
                  child: Row(
                    children: [
                      Expanded(child: SecondaryButton(label: 'Save draft', icon: Icons.save_outlined, onPressed: _busy || !_dirty || readOnlyMode ? null : _saveDraft)),
                      const SizedBox(width: Gaps.md),
                      Expanded(child: PrimaryButton(label: 'Submit', icon: Icons.send_rounded, loading: _busy, onPressed: readOnlyMode ? null : _submit)),
                    ],
                  ),
                ),
              )
            : null,
        body: _editable ? list : RefreshIndicator(onRefresh: _refresh, child: list),
      ),
    ));
  }

  Widget _readRow(BuildContext context, _Row r) {
    final t = context.tokens;
    final marks = parseMarkText(r.controller.text);
    final pass = _sheet.passMarks;
    return Semantics(
      label: '${r.name}, ${r.absent ? 'absent' : (marks == null ? 'no mark' : '${fmtMark(marks)} out of ${fmtMark(_max)}')}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.md),
        child: Row(
          children: [
            SizedBox(width: 32, child: Text(r.rollNo == null ? '' : '${r.rollNo}', style: context.text.labelMedium?.copyWith(color: t.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]))),
            Expanded(child: Text(r.name, style: context.text.bodyMedium)),
            if (r.absent)
              const StatusChip('Absent', tone: StatusTone.danger, icon: Icons.close_rounded)
            else if (marks == null)
              Text('No mark', style: context.text.bodySmall)
            else ...[
              Text('${fmtMark(marks)} / ${fmtMark(_max)}', style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
              if (pass != null && marks < pass) ...[const SizedBox(width: Gaps.sm), const StatusChip('Below pass', tone: StatusTone.warning, icon: Icons.south_rounded)],
            ],
          ],
        ),
      ),
    );
  }

  Widget _editRow(BuildContext context, _Row r, int idx, bool isLast) {
    final t = context.tokens;
    final err = r.absent ? null : markError(r.controller.text, _max);
    final enabled = !_busy && !r.absent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.sm, Gaps.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 32, child: Text(r.rollNo == null ? '' : '${r.rollNo}', style: context.text.labelMedium?.copyWith(color: t.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]))),
              Expanded(child: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
            ],
          ),
          const SizedBox(height: Gaps.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 32),
              Expanded(
                child: TextField(
                  controller: r.controller,
                  focusNode: r.focus,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(7)],
                  onEditingComplete: () => isLast ? FocusScope.of(context).unfocus() : _next(idx),
                  onChanged: (_) => setState(() => _formError = null),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: r.absent ? 'Absent' : 'Marks out of ${fmtMark(_max)}',
                    errorText: err,
                    errorMaxLines: 2,
                  ),
                  style: context.text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
              const SizedBox(width: Gaps.xs),
              _AbsentToggle(
                name: r.name,
                value: r.absent,
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        r.absent = v;
                        if (v) r.controller.clear();
                        _formError = null;
                      }),
              ),
              IconButton(
                tooltip: r.remarks.isEmpty ? 'Add a remark for ${r.name}' : 'Edit the remark for ${r.name}',
                onPressed: _busy ? null : () => _editRemark(r),
                icon: Icon(r.remarks.isEmpty ? Icons.sticky_note_2_outlined : Icons.sticky_note_2_rounded, color: r.remarks.isEmpty ? t.textTertiary : t.brand.ink),
              ),
            ],
          ),
          if (r.remarks.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 32, top: 2, right: Gaps.sm), child: Text('Remark: ${r.remarks}', maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall)),
        ],
      ),
    );
  }
}

/// A 48 dp "Absent" toggle: a check icon plus a word, never colour alone.
class _AbsentToggle extends StatelessWidget {
  const _AbsentToggle({required this.name, required this.value, required this.onChanged});
  final String name;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onChanged != null;
    final color = value ? t.danger : t.textSecondary;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: 'Absent, $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? () => onChanged!(!value) : null,
        borderRadius: Radii.field,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: enabled ? color : t.inkDisabled),
                const SizedBox(width: 4),
                Text('Absent', style: context.text.labelMedium?.copyWith(color: enabled ? color : t.inkDisabled)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Owns its controller so it is disposed only after the dialog has finished animating away.
class _RemarkDialog extends StatefulWidget {
  const _RemarkDialog({required this.name, required this.initial});
  final String name;
  final String initial;

  @override
  State<_RemarkDialog> createState() => _RemarkDialogState();
}

class _RemarkDialogState extends State<_RemarkDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Remark for ${widget.name}'),
    content: TextField(controller: _c, autofocus: true, maxLength: 300, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Optional note')),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, _c.text.trim()), style: FilledButton.styleFrom(minimumSize: const Size(96, 48)), child: const Text('Done')),
    ],
  );
}
