import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import 'error_copy.dart';
import 'staff_context.dart';

/// Runs a write call safely.
///
/// * school in view-only mode (402 territory): nothing is sent, a clear message is shown
/// * any failure becomes a plain-language snackbar (see `friendlyError`)
/// * returns `true` only when the call succeeded
///
/// Use it for every POST/PUT/PATCH/DELETE that is not inside a form that shows errors inline.
Future<bool> runWrite(BuildContext context, WidgetRef ref, Future<void> Function() action, {String? success, void Function(Object error)? onError}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (ref.read(readOnlyProvider)) {
    messenger.showSnackBar(const SnackBar(content: Text('Your school is in view-only mode, so changes are switched off until the subscription is renewed.')));
    return false;
  }
  try {
    await action();
    if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    return true;
  } catch (e) {
    if (onError != null) {
      onError(e);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e)), duration: const Duration(seconds: 6)));
    }
    return false;
  }
}

/// A banner for screens whose main job is writing, shown while the school is in view-only mode.
class ReadOnlyBanner extends ConsumerWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(readOnlyProvider)) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(bottom: Gaps.md),
      child: InfoBanner(tone: BannerTone.warning, icon: Icons.event_busy_rounded, title: 'View-only mode', message: 'Your school\'s subscription has ended. You can read information, but changes are switched off until it is renewed.'),
    );
  }
}

/// Confirm a consequential action. Cancel is the default (design.md section 8): states the object and the consequence.
Future<bool> confirmAction(BuildContext context, {required String title, required String message, required String confirmLabel, bool destructive = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(autofocus: true, onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(minimumSize: const Size(120, 48), backgroundColor: destructive ? ctx.tokens.dangerTint : null, foregroundColor: destructive ? ctx.tokens.danger : null),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
