import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/data/models/site_info.dart';
import 'package:schoolsync/router/role_modules.dart';

/// `test/fixtures/me_*.json` are real `/auth/me` payloads from the demo school (no tokens).
Me _fixture(String role) => Me.fromJson((jsonDecode(File('test/fixtures/me_$role.json').readAsStringSync()) as Map).cast<String, dynamic>());

List<String> _labels(Me me) => [for (final t in tabsFor(me.experience)) t.label];

void main() {
  group('real demo payloads parse and map to the right shell', () {
    test('student', () {
      final me = _fixture('student');
      expect(me.experience, Experience.student);
      expect(_labels(me), ['Home', 'My Tasks', 'Calendar', 'Learning', 'Profile']);
      expect(me.profile.gradeName, isNotNull);
      expect(me.profile.children, isEmpty);
      expect(me.mustChangePassword, isFalse);
    });

    test('parent has a linked child for the child selector', () {
      final me = _fixture('parent');
      expect(me.experience, Experience.parent);
      expect(_labels(me), ['Home', 'Attendance', 'Academics', 'Fees', 'More']);
      expect(me.profile.children, hasLength(1));
      expect(me.profile.children.first.name, isNotEmpty);
      expect(me.profile.children.first.firstName, isNotEmpty);
    });

    test('teacher', () {
      final me = _fixture('teacher');
      expect(me.experience, Experience.teacher);
      expect(_labels(me), ['Home', 'Classes', 'Attendance', 'Homework', 'More']);
      expect(me.profile.assignedSectionIds, isNotEmpty);
      expect(me.roles, contains('class_teacher'));
    });

    test('principal and super admin are both the management experience', () {
      for (final r in ['principal', 'management']) {
        final me = _fixture(r);
        expect(me.experience, Experience.management, reason: r);
        expect(_labels(me), ['Home', 'Academics', 'People', 'Finance', 'More'], reason: r);
      }
    });

    test('every tab is reachable for the role it was designed for', () {
      for (final r in ['student', 'parent', 'teacher', 'principal', 'management']) {
        final me = _fixture(r);
        for (final t in tabsFor(me.experience)) {
          expect(t.allowedFor(me), isTrue, reason: '$r / ${t.label}');
        }
      }
    });

    test('permission scopes survive parsing', () {
      expect(_fixture('parent').scopeOf('fees:view'), PermissionScope.linked);
      expect(_fixture('teacher').scopeOf('attendance:create'), PermissionScope.assigned);
      expect(_fixture('management').scopeOf('students:view'), PermissionScope.school);
      expect(_fixture('student').can('users:create'), isFalse);
    });
  });

  group('gating', () {
    test('Finance is blocked for a manager without fee permissions', () {
      final base = _fixture('principal');
      final noFees = Me(
        id: base.id,
        userType: base.userType,
        displayName: base.displayName,
        username: base.username,
        experience: Experience.management,
        permissions: {for (final e in base.permissions.entries.where((e) => !e.key.startsWith('fees') && !e.key.startsWith('payments') && !e.key.startsWith('expenses'))) e.key: e.value},
      );
      final finance = tabsFor(Experience.management).firstWhere((t) => t.label == 'Finance');
      expect(finance.allowedFor(noFees), isFalse);
      expect(finance.allowedFor(base), isTrue);
    });

    test('Fees tab follows the school feature flag', () {
      final fees = tabsFor(Experience.parent).firstWhere((t) => t.label == 'Fees');
      const on = SiteInfo(code: 'x', name: 'X', primaryColor: '#000000');
      const off = SiteInfo(code: 'x', name: 'X', primaryColor: '#000000', features: SiteFeatures(fees: false));
      expect(fees.enabledAt(on), isTrue);
      expect(fees.enabledAt(off), isFalse);
      expect(fees.enabledAt(null), isTrue);
    });

    test('sensitive tabs are flagged for screen-capture protection', () {
      final sensitive = {
        for (final e in Experience.values) e: [for (final t in tabsFor(e)) if (t.sensitive) t.label],
      };
      expect(sensitive[Experience.parent], containsAll(['Fees', 'Academics']));
      expect(sensitive[Experience.management], contains('Finance'));
      expect(sensitive[Experience.student], containsAll(['Learning', 'Profile']));
    });

    test('children selector helpers', () {
      const c = LinkedChild(studentId: 's', name: 'Ishaan Kumar Bose', admissionNo: 'A1', grade: 'Grade 6', section: 'A');
      expect(c.firstName, 'Ishaan');
      expect(c.classLabel, 'Grade 6 - A');
      expect(const LinkedChild(studentId: 's', name: 'N', admissionNo: '').classLabel, 'Class not assigned');
    });
  });
}
