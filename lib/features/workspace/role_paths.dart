import '../../data/models/me.dart';
import '../../router/routes_management.dart';
import '../../router/routes_teacher.dart';

/// Paths of the screens teachers and management share, in the prefix of the experience that is looking.
/// (The same screen class is registered under both prefixes so each experience keeps its own back stack and tabs.)
abstract final class RolePaths {
  static String student(Experience e, String studentId) => e == Experience.management ? ManagementRoutes.student(studentId) : TeacherRoutes.student(studentId);
  static String section(Experience e, String sectionId) => e == Experience.management ? ManagementRoutes.section(sectionId) : TeacherRoutes.section(sectionId);
}
