import 'package:go_router/go_router.dart';

import '../data/models/me.dart';
import '../features/shell/role_nav.dart';

/// Everything one role experience contributes to the app: its bottom-bar tabs and its pushed routes.
/// Each role has its own `routes_<role>.dart`, so people working on different roles never edit the same file.
class RoleModule {
  const RoleModule({required this.experience, required this.tabs, this.routes = const []});

  final Experience experience;

  /// Bottom navigation (max 5). A tab with a `builder` shows that feature screen; without one, a quiet placeholder.
  final List<TabSpec> tabs;

  /// Pushed (non-tab) routes for this role; composed into the main router.
  final List<RouteBase> routes;
}
