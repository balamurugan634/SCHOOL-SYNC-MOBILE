import 'package:flutter/material.dart';

import '../../data/models/me.dart';
import 'theme.dart';

/// Role tints (design.md 2.3): student amber, parent rose, teacher blue, management = the school's brand.
/// Only for the role chip dot, the signed-in avatar ring and onboarding illustration accents.
extension RoleTintX on SchoolSyncTheme {
  Color roleTint(Experience e) => switch (e) {
    Experience.student => roleStudent,
    Experience.parent => roleParent,
    Experience.teacher => roleTeacher,
    Experience.management => brand.solid,
  };
}
