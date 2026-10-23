// Validation for the meeting action sheets (confirm / reschedule need a slot; the rest need text).

const meetingModes = <(String, String)>[('in_person', 'In person'), ('online', 'Online'), ('phone', 'Phone call')];

/// field -> message; empty = valid. Fields: at, duration, place.
Map<String, String> validateMeetingSlot({required DateTime? at, required String durationText, required String mode, required String place, DateTime? now}) {
  final errors = <String, String>{};
  final n = now ?? DateTime.now();
  if (at == null) {
    errors['at'] = 'Pick a date and time.';
  } else if (!at.isAfter(n)) {
    errors['at'] = 'Choose a time in the future.';
  }
  final d = int.tryParse(durationText.trim());
  if (d == null || d < 5 || d > 180) errors['duration'] = 'Enter a length between 5 and 180 minutes.';
  final p = place.trim();
  if (p.length > 300) errors['place'] = 'Keep this under 300 characters.';
  if (mode == 'online') {
    if (p.isEmpty) {
      errors['place'] = 'An online meeting needs a link.';
    } else if (!_isWebLink(p)) {
      errors['place'] = 'Enter the full link, starting with https://';
    }
  }
  return errors;
}

bool _isWebLink(String s) {
  final u = Uri.tryParse(s);
  return u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.isNotEmpty;
}

/// Declining and completing need words; cancelling does not.
String? validateMeetingText(String text, {required bool required, int max = 500, String message = 'Please write a few words.'}) {
  final t = text.trim();
  if (required && t.isEmpty) return message;
  if (t.length > max) return 'Keep this under $max characters.';
  return null;
}
