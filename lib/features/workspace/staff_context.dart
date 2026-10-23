import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/me.dart';
import '../auth/session.dart';

/// The signed-in user (null only while signing out).
final staffMeProvider = Provider<Me?>((ref) => ref.watch(sessionProvider.select((s) => s.me)));

/// My staff id (teachers and management are staff), used to filter "what I teach".
final staffIdProvider = Provider<String?>((ref) => ref.watch(sessionProvider.select((s) => s.me?.profile.staffId)));

/// The school's subscription lapsed: reads work, writes are refused (402). Write buttons are disabled with a message.
final readOnlyProvider = Provider<bool>((ref) => ref.watch(sessionProvider.select((s) => s.siteInfo?.readOnly ?? false)));

/// The school's currency (finance screens).
final currencyProvider = Provider<String>((ref) => ref.watch(sessionProvider.select((s) => s.siteInfo?.currency ?? 'INR')));

/// Is the finance module switched on for this school?
final feesEnabledProvider = Provider<bool>((ref) => ref.watch(sessionProvider.select((s) => s.siteInfo?.features.fees ?? true)));

/// Permission checks from any widget: `ref.can('attendance:create')`.
extension StaffPermissionX on WidgetRef {
  bool can(String permission) => watch(staffMeProvider)?.can(permission) ?? false;
  bool canAny(Iterable<String> permissions) => watch(staffMeProvider)?.canAny(permissions) ?? false;
  PermissionScope? scopeOf(String permission) => watch(staffMeProvider)?.scopeOf(permission);

  /// True when the permission is held at school-wide scope (not only for assigned sections / own records).
  bool canSchool(String permission) => scopeOf(permission) == PermissionScope.school;
}

/// Ids of the sections I lead as class teacher (they may decide leave and corrections for these).
final classTeacherSectionIdsProvider = Provider<List<String>>((ref) => ref.watch(sessionProvider.select((s) => s.me?.profile.classTeacherSectionIds ?? const <String>[])));
