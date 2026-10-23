enum Experience {
  student,
  parent,
  teacher,
  management;

  static Experience parse(String? v) =>
      Experience.values.firstWhere((e) => e.name == v, orElse: () => Experience.student);

  String get label => switch (this) {
    Experience.student => 'Student',
    Experience.parent => 'Parent',
    Experience.teacher => 'Teacher',
    Experience.management => 'Management',
  };
}

enum PermissionScope {
  own,
  linked,
  assigned,
  school;

  static PermissionScope? parse(String? v) {
    for (final s in PermissionScope.values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

class LinkedChild {
  const LinkedChild({
    required this.studentId,
    required this.name,
    required this.admissionNo,
    this.grade,
    this.section,
    this.sectionId,
    this.photoUrl,
  });

  final String studentId;
  final String name;
  final String admissionNo;
  final String? grade;
  final String? section;
  final String? sectionId;
  final String? photoUrl;

  String get classLabel {
    final parts = [grade, section].where((e) => e != null && e.isNotEmpty).cast<String>().toList();
    return parts.isEmpty ? 'Class not assigned' : parts.join(' - ');
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  factory LinkedChild.fromJson(Map<String, dynamic> j) => LinkedChild(
    studentId: j['studentId'] as String,
    name: j['name'] as String,
    admissionNo: (j['admissionNo'] as String?) ?? '',
    grade: j['grade'] as String?,
    section: j['section'] as String?,
    sectionId: j['sectionId'] as String?,
    photoUrl: j['photoUrl'] as String?,
  );
}

class MeProfile {
  const MeProfile({
    this.studentId,
    this.guardianId,
    this.staffId,
    this.children = const [],
    this.sectionId,
    this.gradeName,
    this.sectionName,
    this.classTeacherSectionIds = const [],
    this.assignedSectionIds = const [],
  });

  final String? studentId;
  final String? guardianId;
  final String? staffId;
  final List<LinkedChild> children;
  final String? sectionId;
  final String? gradeName;
  final String? sectionName;
  final List<String> classTeacherSectionIds;
  final List<String> assignedSectionIds;

  factory MeProfile.fromJson(Map<String, dynamic> j) => MeProfile(
    studentId: j['studentId'] as String?,
    guardianId: j['guardianId'] as String?,
    staffId: j['staffId'] as String?,
    children: ((j['children'] as List?) ?? const [])
        .map((e) => LinkedChild.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false),
    sectionId: j['sectionId'] as String?,
    gradeName: j['gradeName'] as String?,
    sectionName: j['sectionName'] as String?,
    classTeacherSectionIds: ((j['classTeacherSectionIds'] as List?) ?? const []).cast<String>(),
    assignedSectionIds: ((j['assignedSectionIds'] as List?) ?? const []).cast<String>(),
  );

  MeProfile copyWith({List<LinkedChild>? children}) => MeProfile(
    studentId: studentId,
    guardianId: guardianId,
    staffId: staffId,
    children: children ?? this.children,
    sectionId: sectionId,
    gradeName: gradeName,
    sectionName: sectionName,
    classTeacherSectionIds: classTeacherSectionIds,
    assignedSectionIds: assignedSectionIds,
  );
}

/// The signed-in user (`GET /api/v1/auth/me`).
class Me {
  const Me({
    required this.id,
    required this.userType,
    required this.displayName,
    required this.username,
    required this.experience,
    this.email,
    this.phone,
    this.avatarUrl,
    this.locale = 'en',
    this.mustChangePassword = false,
    this.roles = const [],
    this.permissions = const {},
    this.profile = const MeProfile(),
    this.raw,
  });

  final String id;
  final String userType;
  final String displayName;
  final String username;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String locale;
  final bool mustChangePassword;
  final List<String> roles;
  final Experience experience;

  /// permission key -> scope. For UI gating only; the API enforces.
  final Map<String, PermissionScope> permissions;
  final MeProfile profile;

  /// The decoded server payload, kept so the profile can be cached verbatim.
  final Map<String, dynamic>? raw;

  String get firstName => displayName.trim().isEmpty ? username : displayName.trim().split(RegExp(r'\s+')).first;

  bool can(String permission) => permissions.containsKey(permission);

  /// True when any of [keys] is granted.
  bool canAny(Iterable<String> keys) => keys.any(permissions.containsKey);

  PermissionScope? scopeOf(String permission) => permissions[permission];

  factory Me.fromJson(Map<String, dynamic> j) {
    final perms = <String, PermissionScope>{};
    ((j['permissions'] as Map?) ?? const {}).forEach((k, v) {
      final scope = PermissionScope.parse(v as String?);
      if (scope != null) perms[k as String] = scope;
    });
    return Me(
      raw: j,
      id: j['id'] as String,
      userType: (j['userType'] as String?) ?? 'staff',
      displayName: (j['displayName'] as String?) ?? '',
      username: (j['username'] as String?) ?? '',
      email: j['email'] as String?,
      phone: j['phone'] as String?,
      avatarUrl: j['avatarUrl'] as String?,
      locale: (j['locale'] as String?) ?? 'en',
      mustChangePassword: j['mustChangePassword'] as bool? ?? false,
      roles: ((j['roles'] as List?) ?? const []).cast<String>(),
      experience: Experience.parse(j['experience'] as String?),
      permissions: perms,
      profile: MeProfile.fromJson((j['profile'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }

  Me copyWith({Experience? experience, MeProfile? profile, bool? mustChangePassword}) => Me(
    id: id,
    userType: userType,
    displayName: displayName,
    username: username,
    email: email,
    phone: phone,
    avatarUrl: avatarUrl,
    locale: locale,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    roles: roles,
    experience: experience ?? this.experience,
    permissions: permissions,
    profile: profile ?? this.profile,
    raw: raw,
  );
}
