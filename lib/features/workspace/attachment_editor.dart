import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/json.dart';
import '../../data/repositories/files_repository.dart';
import 'error_copy.dart';

/// Attachments for homework, announcements and the like: take a photo, choose a photo, or pick a file.
/// Each file is uploaded to `POST /files` with [purpose] (homework | announcement | material ...) as soon as it is
/// chosen; [onChanged] gets the uploaded attachments (`{fileId, name, mimeType, sizeBytes}`) every time the list changes.
class AttachmentEditor extends ConsumerStatefulWidget {
  const AttachmentEditor({super.key, required this.purpose, required this.attachments, required this.onChanged, this.max = 10, this.enabled = true, this.label = 'Attachments'});

  final String purpose;
  final List<Attachment> attachments;
  final ValueChanged<List<Attachment>> onChanged;
  final int max;
  final bool enabled;
  final String label;

  @override
  ConsumerState<AttachmentEditor> createState() => _AttachmentEditorState();
}

class _AttachmentEditorState extends ConsumerState<AttachmentEditor> {
  int _uploading = 0;
  String? _error;

  Future<void> _add() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(ctx, 'camera')),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose a photo'), onTap: () => Navigator.pop(ctx, 'gallery')),
            ListTile(leading: const Icon(Icons.attach_file_rounded), title: const Text('Choose a file'), onTap: () => Navigator.pop(ctx, 'file')),
            const SizedBox(height: Gaps.sm),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      final picked = <({String path, String name})>[];
      if (choice == 'file') {
        final res = await FilePicker.pickFiles();
        for (final f in res) {
          final path = f.path;
          if (path != null) picked.add((path: path, name: f.name));
        }
      } else {
        final img = await ImagePicker().pickImage(source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 2400, imageQuality: 85);
        if (img != null) picked.add((path: img.path, name: img.name));
      }
      for (final p in picked) {
        if (widget.attachments.length >= widget.max) break;
        await _upload(p.path, p.name);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _upload(String path, String name) async {
    setState(() {
      _uploading++;
      _error = null;
    });
    try {
      final a = await ref.read(filesRepositoryProvider).upload(path, name: name, purpose: widget.purpose);
      if (mounted) widget.onChanged([...widget.attachments, a]);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not upload $name. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _uploading--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final full = widget.attachments.length >= widget.max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
        const SizedBox(height: Gaps.sm),
        for (final a in widget.attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: Gaps.xs),
            child: AppCard(
              tone: CardTone.subtle,
              padding: const EdgeInsets.fromLTRB(Gaps.md, 2, 2, 2),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file_outlined, size: 20, color: t.textSecondary),
                  const SizedBox(width: Gaps.sm),
                  Expanded(child: Text(a.sizeBytes == null ? a.name : '${a.name}  ·  ${fileSize(a.sizeBytes)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium)),
                  IconButton(tooltip: 'Remove ${a.name}', onPressed: widget.enabled ? () => widget.onChanged([...widget.attachments]..remove(a)) : null, icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
          ),
        if (_uploading > 0) const Padding(padding: EdgeInsets.symmetric(vertical: Gaps.sm), child: LinearProgressIndicator(minHeight: 4)),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: Text(_error!, style: context.text.bodySmall?.copyWith(color: t.danger))),
        SecondaryButton(label: full ? 'Attachment limit reached' : 'Add attachment', icon: Icons.add_rounded, onPressed: widget.enabled && !full && _uploading == 0 ? _add : null),
      ],
    );
  }
}
