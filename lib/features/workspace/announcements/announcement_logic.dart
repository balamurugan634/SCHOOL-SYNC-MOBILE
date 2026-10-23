import '../../../data/models/me.dart';
import '../../../data/models/staff/comms.dart';

/// Who an author may address. Teachers hold `announcements:create` at "assigned" scope: they may only
/// target the sections they lead or teach. School-scope authors (office, principal) may also address everyone,
/// a user type, a grade, or any section. The API enforces this too (`AUDIENCE_NOT_ALLOWED`).
class AudiencePolicy {
  const AudiencePolicy({required this.sectionsOnly});

  /// Only `section` targets are allowed.
  final bool sectionsOnly;

  /// Anything narrower than school scope is limited to sections.
  factory AudiencePolicy.forScope(PermissionScope? scope) => AudiencePolicy(sectionsOnly: scope != PermissionScope.school);

  bool allows(AudienceTarget t) => !sectionsOnly || t.type == 'section';
}

const userTypeTargets = <AudienceTarget>[
  AudienceTarget(type: 'user_type', id: 'student', label: 'Students'),
  AudienceTarget(type: 'user_type', id: 'parent', label: 'Parents'),
  AudienceTarget(type: 'user_type', id: 'staff', label: 'Staff'),
];

const everyoneTarget = AudienceTarget(type: 'all', label: 'Everyone');

/// Null when the audience is fine, otherwise a sentence for the person.
String? validateAudience(List<AudienceTarget> audience, AudiencePolicy policy) {
  if (audience.isEmpty) return policy.sectionsOnly ? 'Choose at least one class.' : 'Choose who this announcement is for.';
  if (audience.any((t) => !policy.allows(t))) return 'You can only address the classes you lead or teach.';
  if (audience.length > 20) return 'Choose at most 20 groups. Use a grade or "Everyone" for larger audiences.';
  return null;
}

/// "Grade 6 A, Grade 6 B and 2 more".
String describeAudience(List<AudienceTarget> audience, {int max = 3}) {
  if (audience.isEmpty) return 'No audience';
  if (audience.any((t) => t.type == 'all')) return 'Everyone';
  final labels = [for (final t in audience) t.label];
  if (labels.length <= max) return labels.join(', ');
  return '${labels.take(max).join(', ')} and ${labels.length - max} more';
}

/// Schedule rules: the publish time must be in the future (a minute of slack for the clock) and the expiry must come
/// after it (or after now when publishing immediately). Returns field -> message; empty = valid.
Map<String, String> validateSchedule({DateTime? publishAt, DateTime? expiresAt, DateTime? now}) {
  final n = now ?? DateTime.now();
  final errors = <String, String>{};
  if (publishAt != null && !publishAt.isAfter(n.add(const Duration(minutes: 1)))) {
    errors['publishAt'] = 'Pick a publish time in the future.';
  }
  if (expiresAt != null) {
    final base = publishAt ?? n;
    if (!expiresAt.isAfter(base)) {
      errors['expiresAt'] = publishAt == null ? 'The expiry must be in the future.' : 'The expiry must be after the publish time.';
    }
  }
  return errors;
}

/// Everything the form checks before it will talk to the API.
Map<String, String> validateAnnouncementForm({required String title, required String body, required List<AudienceTarget> audience, required AudiencePolicy policy, DateTime? publishAt, DateTime? expiresAt, DateTime? now}) {
  final errors = <String, String>{};
  if (title.trim().isEmpty) errors['title'] = 'Add a title.';
  if (title.trim().length > 200) errors['title'] = 'The title can be at most 200 characters.';
  if (body.trim().isEmpty) errors['body'] = 'Write the message.';
  if (body.trim().length > 10000) errors['body'] = 'The message can be at most 10,000 characters.';
  final a = validateAudience(audience, policy);
  if (a != null) errors['audience'] = a;
  errors.addAll(validateSchedule(publishAt: publishAt, expiresAt: expiresAt, now: now));
  return errors;
}
