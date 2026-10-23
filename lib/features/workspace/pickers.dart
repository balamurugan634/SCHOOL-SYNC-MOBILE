import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A date. [firstDate] / [lastDate] default to a sensible school window.
Future<DateTime?> pickDay(BuildContext context, {DateTime? initial, DateTime? firstDate, DateTime? lastDate, String? help}) {
  final now = DateTime.now();
  final first = firstDate ?? DateTime(now.year - 1);
  final last = lastDate ?? DateTime(now.year + 2, 12, 31);
  var init = initial ?? now;
  if (init.isBefore(first)) init = first;
  if (init.isAfter(last)) init = last;
  return showDatePicker(context: context, initialDate: init, firstDate: first, lastDate: last, helpText: help);
}

/// A date, then a time of day. Returns null when either step is cancelled.
Future<DateTime?> pickDayTime(BuildContext context, {DateTime? initial, DateTime? firstDate, DateTime? lastDate, String? help}) async {
  final day = await pickDay(context, initial: initial, firstDate: firstDate, lastDate: lastDate, help: help);
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now().add(const Duration(hours: 1))));
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

/// Opens the phone dialer. Shows a message when this device cannot place calls.
Future<void> callPhone(BuildContext context, String? number) async {
  final messenger = ScaffoldMessenger.of(context);
  final digits = number?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
  if (digits.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('There is no phone number on record.')));
    return;
  }
  final ok = await launchUrl(Uri(scheme: 'tel', path: digits));
  if (!ok) messenger.showSnackBar(SnackBar(content: Text('This device cannot place calls. The number is $number.')));
}

/// Opens a web link (meeting links ...).
Future<void> openLink(BuildContext context, String? url) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(url ?? '');
  if (uri == null || !uri.hasScheme) {
    messenger.showSnackBar(const SnackBar(content: Text('That link cannot be opened.')));
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) messenger.showSnackBar(const SnackBar(content: Text('That link cannot be opened.')));
}
