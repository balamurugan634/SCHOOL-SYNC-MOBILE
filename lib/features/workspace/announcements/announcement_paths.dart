import '../../../data/models/me.dart';
import '../../../router/routes_management.dart';
import '../../../router/routes_teacher.dart';

/// Announcement screens are shared by teachers and management; each lives under its own route prefix so the
/// bottom bar and back stack stay in the right experience.
class AnnouncementPaths {
  const AnnouncementPaths._(this.list, this.create, this._detail, this._edit);

  final String list;
  final String create;
  final String Function(String id) _detail;
  final String Function(String id) _edit;

  String detail(String id) => _detail(id);
  String edit(String id) => _edit(id);

  static const _teacher = AnnouncementPaths._(TeacherRoutes.announcements, TeacherRoutes.announcementNew, TeacherRoutes.announcement, TeacherRoutes.announcementEdit);
  static const _management = AnnouncementPaths._(ManagementRoutes.announcements, ManagementRoutes.announcementNew, ManagementRoutes.announcement, ManagementRoutes.announcementEdit);

  static AnnouncementPaths of(Experience? e) => e == Experience.management ? _management : _teacher;
}
