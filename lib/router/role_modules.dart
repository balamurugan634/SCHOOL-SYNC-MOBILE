import '../data/models/me.dart';
import '../features/shell/role_nav.dart';
import 'role_module.dart';
import 'routes_management.dart';
import 'routes_parent.dart';
import 'routes_student.dart';
import 'routes_teacher.dart';

/// All role experiences, in one place. The router composes `module.routes` of each.
final List<RoleModule> roleModules = [studentModule, parentModule, teacherModule, managementModule];

RoleModule moduleFor(Experience e) => roleModules.firstWhere((m) => m.experience == e);

/// Bottom-bar tabs of an experience.
List<TabSpec> tabsFor(Experience e) => moduleFor(e).tabs;
