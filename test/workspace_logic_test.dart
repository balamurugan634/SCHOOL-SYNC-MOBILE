import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/data/models/leave.dart' show LeaveType;
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/data/models/staff/comms.dart';
import 'package:schoolsync/data/models/staff/leave.dart';
import 'package:schoolsync/data/models/staff/teaching.dart';
import 'package:schoolsync/features/teacher/more/syllabus_logic.dart';
import 'package:schoolsync/features/workspace/announcements/announcement_logic.dart';
import 'package:schoolsync/features/workspace/announcements/announcement_paths.dart';
import 'package:schoolsync/features/workspace/me/check_in_logic.dart';
import 'package:schoolsync/features/workspace/me/leave_logic.dart';
import 'package:schoolsync/features/workspace/meetings/meeting_logic.dart';
import 'package:schoolsync/router/routes_management.dart';
import 'package:schoolsync/router/routes_teacher.dart';

const _s1 = AudienceTarget(type: 'section', id: 's1', label: 'Grade 6 A');
const _s2 = AudienceTarget(type: 'section', id: 's2', label: 'Grade 6 B');
const _g1 = AudienceTarget(type: 'grade', id: 'g1', label: 'Grade 6');

void main() {
  final now = DateTime(2026, 10, 21, 10);

  group('announcement audience scoping', () {
    test('teachers (assigned scope) are limited to sections; school scope is not', () {
      final teacher = AudiencePolicy.forScope(PermissionScope.assigned);
      final office = AudiencePolicy.forScope(PermissionScope.school);
      expect(teacher.sectionsOnly, isTrue);
      expect(office.sectionsOnly, isFalse);
      expect(AudiencePolicy.forScope(null).sectionsOnly, isTrue, reason: 'no scope = the narrowest rule');
      expect(AudiencePolicy.forScope(PermissionScope.own).sectionsOnly, isTrue);

      expect(teacher.allows(_s1), isTrue);
      expect(teacher.allows(everyoneTarget), isFalse);
      expect(teacher.allows(_g1), isFalse);
      expect(teacher.allows(userTypeTargets.first), isFalse);
      for (final t in [_s1, everyoneTarget, _g1, ...userTypeTargets]) {
        expect(office.allows(t), isTrue);
      }
    });

    test('validateAudience: empty, out of scope, too many', () {
      final teacher = AudiencePolicy.forScope(PermissionScope.assigned);
      final office = AudiencePolicy.forScope(PermissionScope.school);
      expect(validateAudience(const [], teacher), 'Choose at least one class.');
      expect(validateAudience(const [], office), 'Choose who this announcement is for.');
      expect(validateAudience(const [_s1, _s2], teacher), isNull);
      expect(validateAudience(const [everyoneTarget], teacher), contains('classes you lead or teach'));
      expect(validateAudience(const [everyoneTarget], office), isNull);
      expect(validateAudience([for (var i = 0; i < 21; i++) AudienceTarget(type: 'section', id: '$i', label: 'S$i')], office), contains('at most 20'));
    });

    test('describeAudience summarises long lists and "Everyone"', () {
      expect(describeAudience(const []), 'No audience');
      expect(describeAudience(const [_s1]), 'Grade 6 A');
      expect(describeAudience(const [_s1, _s2]), 'Grade 6 A, Grade 6 B');
      expect(describeAudience([_s1, _s2, _g1, userTypeTargets.first]), 'Grade 6 A, Grade 6 B, Grade 6 and 1 more');
      expect(describeAudience(const [everyoneTarget, _s1]), 'Everyone');
    });

    test('targets compare by type and id, and serialise without a null id', () {
      expect(const AudienceTarget(type: 'section', id: 's1', label: 'x'), _s1);
      expect(everyoneTarget.toJson(), {'type': 'all'});
      expect(_s1.toJson(), {'type': 'section', 'id': 's1'});
    });
  });

  group('schedule and expiry', () {
    test('publish time must be in the future (with a minute of slack)', () {
      expect(validateSchedule(publishAt: now.subtract(const Duration(hours: 1)), now: now)['publishAt'], isNotNull);
      expect(validateSchedule(publishAt: now.add(const Duration(seconds: 30)), now: now)['publishAt'], isNotNull);
      expect(validateSchedule(publishAt: now.add(const Duration(hours: 2)), now: now), isEmpty);
    });

    test('expiry must follow the publish time, or now when publishing immediately', () {
      final publish = now.add(const Duration(days: 1));
      expect(validateSchedule(publishAt: publish, expiresAt: publish.subtract(const Duration(hours: 1)), now: now)['expiresAt'], contains('after the publish time'));
      expect(validateSchedule(publishAt: publish, expiresAt: publish.add(const Duration(days: 3)), now: now), isEmpty);
      expect(validateSchedule(expiresAt: now.subtract(const Duration(minutes: 1)), now: now)['expiresAt'], contains('in the future'));
      expect(validateSchedule(expiresAt: now.add(const Duration(days: 2)), now: now), isEmpty);
    });

    test('the whole form: required text, audience, schedule', () {
      final teacher = AudiencePolicy.forScope(PermissionScope.assigned);
      final bad = validateAnnouncementForm(title: '  ', body: '', audience: const [], policy: teacher, now: now);
      expect(bad.keys, containsAll(['title', 'body', 'audience']));
      final ok = validateAnnouncementForm(title: 'Sports day', body: 'Bring a bottle.', audience: const [_s1], policy: teacher, now: now);
      expect(ok, isEmpty);
      expect(validateAnnouncementForm(title: 'x' * 201, body: 'b', audience: const [_s1], policy: teacher, now: now)['title'], contains('200'));
      expect(validateAnnouncementForm(title: 't', body: 'b', audience: const [everyoneTarget], policy: teacher, now: now)['audience'], isNotNull);
    });

    test('a draft PATCH clears the expiry with an explicit null; create omits it', () {
      const d = AnnouncementDraft(title: 'T', body: 'B', audience: [_s1]);
      expect(d.toUpdateJson().containsKey('expiresAt'), isTrue);
      expect(d.toUpdateJson()['expiresAt'], isNull);
      expect(d.toUpdateJson().containsKey('publishAt'), isFalse);
      expect(d.toJson().containsKey('expiresAt'), isFalse);
    });

    test('each experience keeps announcements under its own route prefix', () {
      expect(AnnouncementPaths.of(Experience.teacher).list, TeacherRoutes.announcements);
      expect(AnnouncementPaths.of(Experience.teacher).detail('a1'), '/teacher/announcements/a1');
      expect(AnnouncementPaths.of(Experience.management).list, ManagementRoutes.announcements);
      expect(AnnouncementPaths.of(Experience.management).edit('a1'), '/management/announcements/a1/edit');
      expect(AnnouncementPaths.of(null).create, TeacherRoutes.announcementNew);
    });
  });

  group('meeting slot validation', () {
    test('needs a future time and a sensible length', () {
      expect(validateMeetingSlot(at: null, durationText: '15', mode: 'in_person', place: '', now: now)['at'], isNotNull);
      expect(validateMeetingSlot(at: now.subtract(const Duration(hours: 1)), durationText: '15', mode: 'in_person', place: '', now: now)['at'], contains('future'));
      expect(validateMeetingSlot(at: now.add(const Duration(days: 1)), durationText: '15', mode: 'in_person', place: '', now: now), isEmpty);
      for (final bad in ['4', '181', 'abc', '']) {
        expect(validateMeetingSlot(at: now.add(const Duration(days: 1)), durationText: bad, mode: 'phone', place: '', now: now)['duration'], isNotNull, reason: bad);
      }
      for (final ok in ['5', '180', ' 45 ']) {
        expect(validateMeetingSlot(at: now.add(const Duration(days: 1)), durationText: ok, mode: 'phone', place: '', now: now), isEmpty, reason: ok);
      }
    });

    test('an online meeting needs a real link (MEETING_LINK_REQUIRED)', () {
      final at = now.add(const Duration(days: 1));
      expect(validateMeetingSlot(at: at, durationText: '15', mode: 'online', place: '', now: now)['place'], 'An online meeting needs a link.');
      expect(validateMeetingSlot(at: at, durationText: '15', mode: 'online', place: 'room 5', now: now)['place'], contains('https://'));
      expect(validateMeetingSlot(at: at, durationText: '15', mode: 'online', place: 'https://meet.example.org/x', now: now), isEmpty);
      expect(validateMeetingSlot(at: at, durationText: '15', mode: 'in_person', place: '', now: now), isEmpty);
    });

    test('decline and complete need words, cancel does not', () {
      expect(validateMeetingText('  ', required: true), isNotNull);
      expect(validateMeetingText('Not available', required: true), isNull);
      expect(validateMeetingText('', required: false), isNull);
      expect(validateMeetingText('x' * 501, required: false), contains('500'));
      expect(validateMeetingText('x' * 3000, required: true, max: 3000), isNull);
    });
  });

  group('my attendance state', () {
    MyStaffAttendance a(StaffDayRecord? today) => MyStaffAttendance(today: today);
    StaffDayRecord rec({String? inT, String? outT, String status = 'present'}) => StaffDayRecord(id: 'r', date: DateTime(2026, 10, 21), status: status, checkIn: inT, checkOut: outT);

    test('four phases', () {
      expect(checkInPhase(a(null)), CheckInPhase.notCheckedIn);
      expect(checkInPhase(a(rec(inT: '08:10'))), CheckInPhase.checkedIn);
      expect(checkInPhase(a(rec(inT: '08:10', outT: '15:30'))), CheckInPhase.checkedOut);
      expect(checkInPhase(a(rec(status: 'absent'))), CheckInPhase.recordedByOffice, reason: 'the office marked it: self check-in would answer ALREADY_MARKED');
    });

    test('time at school', () {
      expect(workedDuration('08:10', '15:33'), '7 h 23 min');
      expect(workedDuration('09:00', '10:00'), '1 h');
      expect(workedDuration('09:00', '09:25'), '25 min');
      expect(workedDuration('10:00', '09:00'), isNull);
      expect(workedDuration(null, '09:00'), isNull);
      expect(workedDuration('08:10', null), isNull);
    });
  });

  group('leave form', () {
    final today = DateTime(2026, 10, 21);

    test('a valid request', () {
      expect(validateLeaveForm(type: LeaveType.casual, from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 3), reason: 'Family function', today: today), isEmpty);
      expect(validateLeaveForm(type: LeaveType.sick, from: today, to: today, reason: 'Fever', today: today), isEmpty, reason: 'a single day');
    });

    test('missing pieces', () {
      final e = validateLeaveForm(type: null, from: null, to: null, reason: '', today: today);
      expect(e.keys, containsAll(['type', 'from', 'to', 'reason']));
    });

    test('order, length and age limits mirror the API', () {
      expect(validateLeaveForm(type: LeaveType.sick, from: DateTime(2026, 11, 5), to: DateTime(2026, 11, 4), reason: 'abc', today: today)['to'], contains('before the first day'));
      expect(validateLeaveForm(type: LeaveType.sick, from: DateTime(2026, 11, 1), to: DateTime(2027, 1, 5), reason: 'abc', today: today)['to'], contains('at most 60 days'));
      expect(validateLeaveForm(type: LeaveType.sick, from: DateTime(2026, 11, 1), to: DateTime(2026, 12, 30), reason: 'abc', today: today), isEmpty, reason: 'exactly 60 days');
      expect(validateLeaveForm(type: LeaveType.sick, from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 2), reason: 'abc', today: today)['from'], contains('30 days in the past'));
      expect(validateLeaveForm(type: LeaveType.sick, from: DateTime(2026, 9, 21), to: DateTime(2026, 9, 21), reason: 'abc', today: today), isEmpty, reason: 'exactly 30 days back is allowed');
    });

    test('reason: 3 to 1000 characters, trimmed', () {
      expect(validateLeaveForm(type: LeaveType.other, from: today, to: today, reason: ' ab ', today: today)['reason'], isNotNull);
      expect(validateLeaveForm(type: LeaveType.other, from: today, to: today, reason: 'abc', today: today), isEmpty);
      expect(validateLeaveForm(type: LeaveType.other, from: today, to: today, reason: 'x' * 1001, today: today)['reason'], contains('1000'));
    });

    test('calendar days are inclusive', () {
      expect(calendarDays(DateTime(2026, 11, 2), DateTime(2026, 11, 2)), 1);
      expect(calendarDays(DateTime(2026, 11, 2), DateTime(2026, 11, 4)), 3);
      expect(calendarDays(DateTime(2026, 10, 30), DateTime(2026, 11, 2)), 4);
    });
  });

  group('syllabus editing', () {
    const t1 = TopicEntry(id: 't1', subjectId: 's', subjectName: 'Maths', title: 'Fractions', termName: 'Term 1', status: SyllabusStatus.completed);
    const t2 = TopicEntry(id: 't2', subjectId: 's', subjectName: 'Maths', title: 'Decimals', termName: 'Term 1', status: SyllabusStatus.inProgress);
    const t3 = TopicEntry(id: 't3', subjectId: 's', subjectName: 'Maths', title: 'Algebra', termName: 'Term 2');
    const t4 = TopicEntry(id: 't4', subjectId: 's', subjectName: 'Maths', title: 'Revision');

    test('tap cycles through the three states', () {
      expect(nextSyllabusStatus(SyllabusStatus.notStarted), SyllabusStatus.inProgress);
      expect(nextSyllabusStatus(SyllabusStatus.inProgress), SyllabusStatus.completed);
      expect(nextSyllabusStatus(SyllabusStatus.completed), SyllabusStatus.notStarted);
    });

    test('only real changes are kept, so Save counts the right number', () {
      var c = <String, SyllabusStatus>{};
      c = withChange(c, t3, SyllabusStatus.inProgress);
      c = withChange(c, t2, SyllabusStatus.completed);
      expect(c.length, 2);
      c = withChange(c, t3, SyllabusStatus.notStarted); // back to what the server has
      expect(c.keys, ['t2']);
      expect(effectiveStatus(t2, c), SyllabusStatus.completed);
      expect(effectiveStatus(t1, c), SyllabusStatus.completed);
    });

    test('coverage preview applies unsaved edits (completed / all topics)', () {
      final base = previewCoverage(const [t1, t2, t3, t4], const {});
      expect((base.total, base.completed, base.inProgress, base.percent), (4, 1, 1, 25.0));
      final edited = previewCoverage(const [t1, t2, t3, t4], {'t2': SyllabusStatus.completed, 't3': SyllabusStatus.inProgress});
      expect((edited.completed, edited.inProgress, edited.percent), (2, 1, 50.0));
      expect(previewCoverage(const [], const {}).percent, 0);
      expect(previewCoverage(const [t1, t2, t3], const {}).percent, 33.3);
    });

    test('topics group by term in API order, with a "Whole year" bucket', () {
      final g = groupByTerm(const [t1, t2, t3, t4]);
      expect(g.map((e) => e.$1), ['Term 1', 'Term 2', 'Whole year']);
      expect(g.first.$2.map((t) => t.id), ['t1', 't2']);
    });
  });
}
