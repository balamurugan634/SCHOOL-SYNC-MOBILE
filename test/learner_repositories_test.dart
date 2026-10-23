import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/network/app_exception.dart';
import 'package:schoolsync/core/providers.dart';
import 'package:schoolsync/core/storage/secure_store.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/attendance.dart';
import 'package:schoolsync/data/models/leave.dart';
import 'package:schoolsync/data/models/tasks.dart';
import 'package:schoolsync/data/repositories/announcements_repository.dart';
import 'package:schoolsync/data/repositories/attendance_repository.dart';
import 'package:schoolsync/data/repositories/dashboard_repository.dart';
import 'package:schoolsync/data/repositories/events_repository.dart';
import 'package:schoolsync/data/repositories/exams_repository.dart';
import 'package:schoolsync/data/repositories/fees_repository.dart';
import 'package:schoolsync/data/repositories/files_repository.dart';
import 'package:schoolsync/data/repositories/homework_repository.dart';
import 'package:schoolsync/data/repositories/leave_repository.dart';
import 'package:schoolsync/data/repositories/meetings_repository.dart';
import 'package:schoolsync/data/repositories/notifications_repository.dart';
import 'package:schoolsync/data/repositories/profile_repository.dart';
import 'package:schoolsync/data/repositories/schedule_repository.dart';
import 'package:schoolsync/data/repositories/tasks_repository.dart';

import 'support/fake_api.dart';

/// Repositories against a fake HTTP adapter that replays REAL demo-school responses (test/fixtures/api)
/// and records every request, so the exact wire format is asserted.
void main() {
  late FakeApi api;
  late MemorySecureKv kv;
  late ProviderContainer c;

  setUp(() {
    api = FakeApi();
    kv = MemorySecureKv();
    c = containerFor(api, kv: kv);
  });
  tearDown(() => c.dispose());

  group('requests carry the tenant and a request id', () {
    test('X-Tenant and X-Request-Id on every call', () async {
      api.on('GET /dashboard/student', fixture('dashboard_student'));
      await c.read(dashboardRepositoryProvider).student('u1');
      final r = api.find('GET', '/dashboard/student')!;
      expect(r.headers['X-Tenant'], 'demo');
      expect(r.headers['X-Request-Id'], isNotNull);
    });
  });

  group('dashboard', () {
    test('student home parses and is cached encrypted per user', () async {
      api.on('GET /dashboard/student', fixture('dashboard_student'));
      final d = await c.read(dashboardRepositoryProvider).student('u1');
      expect(d.fromCache, isFalse);
      expect(d.day.student.name, isNotEmpty);
      expect(kv.data.keys, contains('dash.u1.-'));
    });

    test('goes offline: serves the last copy, marked as cached with its age', () async {
      api.on('GET /dashboard/student', fixture('dashboard_student'));
      final repo = c.read(dashboardRepositoryProvider);
      final online = await repo.student('u1');
      api.offline = true;
      final cached = await repo.student('u1');
      expect(cached.fromCache, isTrue);
      expect(cached.day.student.name, online.day.student.name);
      expect(cached.fetchedAt.isAfter(DateTime.now().subtract(const Duration(minutes: 1))), isTrue);
    });

    test('offline with nothing cached surfaces a network error', () async {
      api.offline = true;
      await expectLater(c.read(dashboardRepositoryProvider).student('u1'), throwsA(isA<AppException>().having((e) => e.isNetwork, 'isNetwork', isTrue)));
    });

    test('a server error is NOT hidden by the cache', () async {
      api.on('GET /dashboard/student', fixture('dashboard_student'));
      final repo = c.read(dashboardRepositoryProvider);
      await repo.student('u1');
      api.on('GET /dashboard/student', {'title': 'Something went wrong', 'code': 'INTERNAL', 'status': 500}, status: 500);
      await expectLater(repo.student('u1'), throwsA(isA<AppException>().having((e) => e.status, 'status', 500)));
    });

    test('parent home asks for the selected child and caches per child', () async {
      api.on('GET /dashboard/parent', fixture('dashboard_parent'));
      final repo = c.read(dashboardRepositoryProvider);
      final d = await repo.parent('g1', studentId: 'child-1');
      expect(api.find('GET', '/dashboard/parent')!.query, {'studentId': 'child-1'});
      expect(d.children, isNotEmpty);
      expect(kv.data.keys, contains('dash.g1.child-1'));
      api.offline = true;
      expect((await repo.parent('g1', studentId: 'child-1')).fromCache, isTrue);
      // Another child has no cache yet.
      await expectLater(repo.parent('g1', studentId: 'child-2'), throwsA(isA<AppException>()));
    });

    test('the cache is wiped with the rest of the secure store (sign out / change school)', () async {
      api.on('GET /dashboard/student', fixture('dashboard_student'));
      final repo = c.read(dashboardRepositoryProvider);
      await repo.student('u1');
      await c.read(secureStoreProvider).clearAll();
      expect(kv.data.keys.where((k) => k.startsWith('dash.')), isEmpty);
      api.offline = true;
      await expectLater(repo.student('u1'), throwsA(isA<AppException>()));
    });
  });

  group('timetable, calendar, attendance, exams, profile', () {
    test('timetable day and calendar window (sorted by day then time)', () async {
      api.on('GET /timetable/me', fixture('timetable'));
      api.on('GET /calendar', fixture('calendar'));
      final repo = c.read(scheduleRepositoryProvider);
      final day = await repo.timetable(date: DateTime(2026, 10, 21), studentId: 'child-1');
      expect(day.entries, isNotEmpty);
      expect(api.find('GET', '/timetable/me')!.query, {'date': '2026-10-21', 'studentId': 'child-1'});
      final items = await repo.calendar(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31));
      expect(items, isNotEmpty);
      expect(api.find('GET', '/calendar')!.query, {'from': '2026-10-01', 'to': '2026-10-31'});
      for (var i = 1; i < items.length; i++) {
        expect(items[i - 1].date.isAfter(items[i].date), isFalse);
      }
    });

    test('attendance summary and cursor records use the student path', () async {
      api.on('GET /attendance/students/child-1/summary', fixture('attendance_summary'));
      api.on('GET /attendance/students/child-1/records', fixture('attendance_records'));
      final repo = c.read(attendanceRepositoryProvider);
      final s = await repo.summary('child-1', from: DateTime(2026, 4, 1), to: DateTime(2026, 10, 21));
      expect(s.totals.total, greaterThan(0));
      expect(api.find('GET', '/attendance/students/child-1/summary')!.query, {'from': '2026-04-01', 'to': '2026-10-21'});
      final page = await repo.records('child-1');
      expect(page.nextCursor, isNotNull);
      final next = await repo.records('child-1', cursor: page.nextCursor, status: AttendanceStatus.halfDay);
      final q = api.find('GET', '/attendance/students/child-1/records')!.query;
      expect(q['cursor'], page.nextCursor);
      expect(q['status'], 'half_day');
      expect(next.items, isNotEmpty);
    });

    test('exams, papers, results, progress and the report card', () async {
      api.on('GET /exams', fixture('exams'));
      api.on('GET /exams/e1/papers', fixture('exam_papers'));
      api.on('GET /results', fixture('results'));
      api.on('GET /results/progress', fixture('progress'));
      api.on('GET /report-cards/e1/students/child-1', fixture('report_card'));
      final repo = c.read(examsRepositoryProvider);
      expect(await repo.exams(), isNotEmpty);
      final papers = await repo.papers('e1');
      for (var i = 1; i < papers.length; i++) {
        expect(papers[i - 1].examDate!.isAfter(papers[i].examDate!), isFalse, reason: 'papers are in date order');
      }
      expect(await repo.results(studentId: 'child-1'), isNotEmpty);
      expect(api.find('GET', '/results')!.query, {'studentId': 'child-1'});
      expect(await repo.progress(), isNotEmpty);
      expect((await repo.reportCard('e1', 'child-1')).schoolName, isNotEmpty);
      expect(repo.reportCardPdfPath('e1', 'child-1'), '/report-cards/e1/students/child-1/pdf');
    });

    test('profile details and the edit payload', () async {
      api.on('GET /me/profile', fixture('profile_student'));
      api.on('PATCH /me/profile', {'ok': true});
      final repo = c.read(profileRepositoryProvider);
      expect((await repo.details()).displayName, isNotEmpty);
      await repo.update(phone: ' 9876543210 ', address: {'line1': '12 Park Road', 'city': 'Bengaluru'});
      expect(api.find('PATCH', '/me/profile')!.body, {'phone': '9876543210', 'address': {'line1': '12 Park Road', 'city': 'Bengaluru'}});
      await repo.update(email: 'a@b.in', currentPassword: 'Secret@123');
      expect(api.find('PATCH', '/me/profile')!.body, {'email': 'a@b.in', 'currentPassword': 'Secret@123'});
    });
  });

  group('homework', () {
    test('lists published homework for the learner; a parent adds the child', () async {
      api.on('GET /homework', fixture('homework_list'));
      final repo = c.read(homeworkRepositoryProvider);
      final p = await repo.list(learnerStatus: 'pending');
      expect(p.items, isNotEmpty);
      final q = api.find('GET', '/homework')!.query;
      expect(q['status'], 'published');
      expect(q['learnerStatus'], 'pending');
      expect(q.containsKey('studentId'), isFalse);
      await repo.list(studentId: 'child-1');
      expect(api.find('GET', '/homework')!.query['studentId'], 'child-1');
    });

    test('a missing submission is null, other errors surface', () async {
      final repo = c.read(homeworkRepositoryProvider);
      api.on('GET /homework/h1/submission', {'title': 'Not submitted', 'code': 'NOT_SUBMITTED', 'status': 404}, status: 404);
      expect(await repo.submission('h1'), isNull);
      api.on('GET /homework/h1/submission', {'title': 'Nope', 'code': 'FORBIDDEN', 'status': 403}, status: 403);
      await expectLater(repo.submission('h1'), throwsA(isA<AppException>().having((e) => e.status, 'status', 403)));
    });

    test('submit sends the text and the uploaded attachments exactly', () async {
      api.on('POST /homework/h1/submit', fixture('submission'));
      final repo = c.read(homeworkRepositoryProvider);
      final s = await repo.submit('h1', text: '  Done, see photo.  ', attachments: const [Attachment(fileId: 'f1', name: 'work.jpg', mimeType: 'image/jpeg', sizeBytes: 1200)]);
      expect(s.homeworkId, isNotEmpty);
      final body = api.find('POST', '/homework/h1/submit')!.body as Map;
      expect(body['text'], 'Done, see photo.');
      expect(body['attachments'], [
        {'fileId': 'f1', 'name': 'work.jpg', 'mimeType': 'image/jpeg', 'sizeBytes': 1200},
      ]);
      await repo.submit('h1', text: '   ');
      final blank = api.find('POST', '/homework/h1/submit')!.body as Map;
      expect(blank['text'], isNull);
      expect(blank['attachments'], isEmpty);
    });

    test('a validation failure becomes a readable AppException with field errors', () async {
      api.on('POST /homework/h1/submit', {'title': 'Validation failed', 'code': 'VALIDATION_ERROR', 'status': 422, 'errors': [{'path': 'text', 'message': 'Add text or a file'}]}, status: 422);
      await expectLater(
        c.read(homeworkRepositoryProvider).submit('h1'),
        throwsA(isA<AppException>().having((e) => e.displayMessage, 'displayMessage', 'Add text or a file').having((e) => e.errors.single.path, 'path', 'text')),
      );
    });
  });

  group('file upload', () {
    test('sends multipart `file` + purpose and parses the attachment', () async {
      final dir = Directory.systemTemp.createTempSync('ss_upload');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/answer.pdf')..writeAsBytesSync(List.filled(64, 7));
      api.onFn('POST /files', (r) => (201, {'file': {'id': 'f9'}, 'attachment': {'fileId': 'f9', 'name': 'answer.pdf', 'mimeType': 'application/pdf', 'sizeBytes': 64}}));
      final a = await c.read(filesRepositoryProvider).upload(f.path, purpose: 'submission');
      expect(a.fileId, 'f9');
      expect(a.name, 'answer.pdf');
      final r = api.find('POST', '/files')!;
      expect(r.query['purpose'], 'submission');
      final form = r.body as FormData;
      expect(form.fields.map((e) => '${e.key}=${e.value}'), contains('purpose=submission'));
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'answer.pdf');
    });

    test('a too-large file is a clear error', () async {
      final dir = Directory.systemTemp.createTempSync('ss_upload');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/big.bin')..writeAsBytesSync([1]);
      api.on('POST /files', {'title': 'File is too large', 'code': 'FILE_TOO_LARGE', 'status': 413}, status: 413);
      await expectLater(c.read(filesRepositoryProvider).upload(f.path), throwsA(isA<AppException>().having((e) => e.message, 'message', 'File is too large')));
    });
  });

  group('tasks', () {
    final taskJson = (fixture('tasks') as Json)['data'][0] as Json;

    test('feed asks for open items only by default', () async {
      api.on('GET /tasks/feed', fixture('tasks_feed'));
      final feed = await c.read(tasksRepositoryProvider).feed();
      expect(feed, isNotEmpty);
      expect(api.find('GET', '/tasks/feed')!.query['includeDone'], false);
    });

    test('create sends trimmed fields and UTC times', () async {
      api.on('POST /tasks', taskJson, status: 201);
      final due = DateTime.utc(2026, 11, 2, 18, 30);
      final t = await c.read(tasksRepositoryProvider).create(title: '  Read chapter 4 ', notes: '  ', dueAt: due, priority: TaskPriority.high);
      expect(t.title, isNotEmpty);
      final b = api.find('POST', '/tasks')!.body as Map;
      expect(b['title'], 'Read chapter 4');
      expect(b['notes'], isNull);
      expect(b['dueAt'], '2026-11-02T18:30:00.000Z');
      expect(b['priority'], 'high');
    });

    test('status change, edit and delete use PATCH/DELETE on the task', () async {
      api.on('PATCH /tasks/t1', {...taskJson, 'status': 'done'});
      api.on('DELETE /tasks/t1', {'ok': true});
      final repo = c.read(tasksRepositoryProvider);
      expect((await repo.setStatus('t1', TaskStatus.done)).done, isTrue);
      expect(api.find('PATCH', '/tasks/t1')!.body, {'status': 'done'});
      await repo.update('t1', title: ' New ', priority: TaskPriority.low);
      final b = api.find('PATCH', '/tasks/t1')!.body as Map;
      expect(b['title'], 'New');
      expect(b['priority'], 'low');
      await repo.delete('t1');
      expect(api.count('DELETE', '/tasks/t1'), 1);
    });
  });

  group('fees', () {
    test('invoices and payments for a child; detail; receipt', () async {
      api.on('GET /fees/invoices', fixture('invoices'));
      api.on('GET /payments', fixture('payments'));
      api.on('GET /fees/invoices/i1', fixture('invoice_detail'));
      api.on('GET /payments/p1/receipt', fixture('receipt'));
      final repo = c.read(feesRepositoryProvider);
      expect((await repo.invoices(studentId: 'child-1', status: 'due')).items, isNotEmpty);
      expect(api.find('GET', '/fees/invoices')!.query, containsPair('studentId', 'child-1'));
      expect((await repo.payments()).items, isNotEmpty);
      expect((await repo.invoice('i1')).items, isNotEmpty);
      expect((await repo.receipt('p1')).receiptNo, startsWith('RCT-'));
      expect(repo.receiptPdfPath('p1'), '/payments/p1/receipt/pdf');
    });

    test('pay: full balance sends no amount, a part payment sends minor units', () async {
      api.on('POST /fees/invoices/i1/pay', {'paymentId': 'p1', 'provider': 'mock', 'orderId': 'order_1', 'amountMinor': 500000, 'currency': 'INR', 'keyId': null, 'mock': true});
      final repo = c.read(feesRepositoryProvider);
      final o = await repo.startPayment('i1');
      expect(o.mock, isTrue);
      expect(api.find('POST', '/fees/invoices/i1/pay')!.body, <String, dynamic>{});
      await repo.startPayment('i1', amountMinor: 250000);
      expect(api.find('POST', '/fees/invoices/i1/pay')!.body, {'amountMinor': 250000});
    });

    test('mock gateway completion and sync, and a 404 when the dev gateway is absent', () async {
      api.on('POST /payments/p1/mock-complete', {'ok': true});
      api.on('POST /payments/p1/sync', (fixture('payments') as Json)['data'][0]);
      final repo = c.read(feesRepositoryProvider);
      await repo.mockComplete('p1');
      expect((await repo.syncPayment('p1')).succeeded, isTrue);
      api.on('POST /payments/p2/mock-complete', {'title': 'Not found', 'code': 'NOT_FOUND', 'status': 404}, status: 404);
      await expectLater(repo.mockComplete('p2'), throwsA(isA<AppException>()));
    });

    test('paying an invoice that is already paid is reported by the API message', () async {
      api.on('POST /fees/invoices/i1/pay', {'title': 'Invoice is already paid', 'code': 'INVOICE_NOT_PAYABLE', 'status': 409}, status: 409);
      await expectLater(c.read(feesRepositoryProvider).startPayment('i1'), throwsA(isA<AppException>().having((e) => e.message, 'message', 'Invoice is already paid')));
    });
  });

  group('announcements and events', () {
    test('announcements list, counts, read and acknowledge', () async {
      api.on('GET /announcements', fixture('announcements'));
      api.on('GET /announcements/unread-count', fixture('announcement_counts'));
      api.on('POST /announcements/a1/read', {'ok': true});
      api.on('POST /announcements/a1/ack', {'ok': true});
      final repo = c.read(announcementsRepositoryProvider);
      expect((await repo.list(unreadOnly: true)).items, isNotEmpty);
      expect(api.find('GET', '/announcements')!.query['unread'], true);
      await repo.counts();
      await repo.markRead('a1');
      await repo.acknowledge('a1');
      expect(api.count('POST', '/announcements/a1/ack'), 1);
    });

    test('events window uses ISO days; respond posts the child and answer', () async {
      api.on('GET /events', fixture('events_parent'));
      api.on('POST /events/e1/respond', {'studentId': 'child-1', 'studentName': 'Ishaan Bose', 'response': 'consent_given', 'note': null, 'respondedAt': '2026-10-21T10:00:00.000Z'});
      final repo = c.read(eventsRepositoryProvider);
      expect((await repo.list(from: DateTime(2026, 10, 1), to: DateTime(2026, 12, 31))).items, isNotEmpty);
      expect(api.find('GET', '/events')!.query, containsPair('from', '2026-10-01'));
      final r = await repo.respond('e1', studentId: 'child-1', response: 'consent_given', note: '  ok ');
      expect(r.response, 'consent_given');
      expect(api.find('POST', '/events/e1/respond')!.body, {'studentId': 'child-1', 'response': 'consent_given', 'note': 'ok'});
      await repo.respond('e1', studentId: 'child-1', response: 'not_going');
      expect((api.find('POST', '/events/e1/respond')!.body as Map).containsKey('note'), isFalse);
    });
  });

  group('meetings', () {
    test('request and cancel', () async {
      final m = ((fixture('meetings') as Json)['data'] as List)[1] as Json;
      api.on('GET /meetings/teachers', fixture('meeting_teachers'));
      api.on('POST /meetings', m, status: 201);
      api.on('POST /meetings/m1/cancel', {...m, 'status': 'cancelled', 'availableActions': []});
      final repo = c.read(meetingsRepositoryProvider);
      final teachers = await repo.teachers('child-1');
      expect(teachers.any((t) => t.isClassTeacher), isTrue);
      expect(api.find('GET', '/meetings/teachers')!.query, {'studentId': 'child-1'});
      final req = await repo.request(studentId: 'child-1', staffId: teachers.first.staffId, topic: ' Progress ', proposedAt: DateTime.utc(2026, 11, 5, 9));
      expect(req.status, 'requested');
      final b = api.find('POST', '/meetings')!.body as Map;
      expect(b, {'studentId': 'child-1', 'staffId': teachers.first.staffId, 'topic': 'Progress', 'proposedAt': '2026-11-05T09:00:00.000Z'});
      final cancelled = await repo.cancel('m1', reason: '  Clash ');
      expect(cancelled.canCancel, isFalse);
      expect(api.find('POST', '/meetings/m1/cancel')!.body, {'reason': 'Clash'});
      await repo.cancel('m1');
      expect(api.find('POST', '/meetings/m1/cancel')!.body, <String, dynamic>{});
    });
  });

  group('leave', () {
    final leaveJson = {
      'id': 'l1', 'studentName': 'Ishaan Bose', 'leaveType': 'sick', 'fromDate': '2026-10-22', 'toDate': '2026-10-23', 'days': 2,
      'reason': 'Fever', 'status': 'pending', 'canCancel': true, 'createdAt': '2026-10-21T10:00:00.000Z',
    };

    test('apply sends dates as ISO days and the child for parents', () async {
      api.on('POST /leave', leaveJson, status: 201);
      final l = await c.read(leaveRepositoryProvider).apply(studentId: 'child-1', type: LeaveType.sick, from: DateTime(2026, 10, 22), to: DateTime(2026, 10, 23), reason: '  Fever ', attachmentFileId: 'f1');
      expect(l.days, 2);
      expect(l.canCancel, isTrue);
      expect(api.find('POST', '/leave')!.body, {'studentId': 'child-1', 'leaveType': 'sick', 'fromDate': '2026-10-22', 'toDate': '2026-10-23', 'reason': 'Fever', 'attachmentFileId': 'f1'});
      await c.read(leaveRepositoryProvider).apply(type: LeaveType.casual, from: DateTime(2026, 10, 22), to: DateTime(2026, 10, 22), reason: 'Trip');
      final b = api.find('POST', '/leave')!.body as Map;
      expect(b.containsKey('studentId'), isFalse);
      expect(b.containsKey('attachmentFileId'), isFalse);
    });

    test('list and cancel', () async {
      api.on('GET /leave', {'data': [leaveJson], 'meta': {'page': 1, 'pageSize': 30, 'total': 1, 'totalPages': 1}});
      api.on('POST /leave/l1/cancel', {...leaveJson, 'status': 'cancelled', 'canCancel': false});
      final repo = c.read(leaveRepositoryProvider);
      expect((await repo.list()).items.single.status, 'pending');
      expect((await repo.cancel('l1')).status, 'cancelled');
    });

    test('an overlapping request is rejected with the API message', () async {
      api.on('POST /leave', {'title': 'You already have leave on these dates', 'code': 'LEAVE_OVERLAP', 'status': 409}, status: 409);
      await expectLater(
        c.read(leaveRepositoryProvider).apply(type: LeaveType.sick, from: DateTime(2026, 10, 22), to: DateTime(2026, 10, 22), reason: 'Fever'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'LEAVE_OVERLAP')),
      );
    });
  });

  group('notifications', () {
    test('cursor paging, unread filter and category', () async {
      api.on('GET /notifications', fixture('notifications'));
      final repo = c.read(notificationsRepositoryProvider);
      final p = await repo.list(unreadOnly: true, category: 'marks');
      expect(p.items, isNotEmpty);
      final q = api.find('GET', '/notifications')!.query;
      expect(q['unread'], true);
      expect(q['category'], 'marks');
      expect(q.containsKey('cursor'), isFalse);
      await repo.list(cursor: 'abc');
      expect(api.find('GET', '/notifications')!.query['cursor'], 'abc');
    });

    test('unread count, mark read, mark all, delete', () async {
      api.on('GET /notifications/unread-count', {'unread': 4});
      api.on('POST /notifications/n1/read', {'ok': true});
      api.on('POST /notifications/read-all', {'ok': true});
      api.on('DELETE /notifications/n1', {'ok': true});
      final repo = c.read(notificationsRepositoryProvider);
      expect(await repo.unreadCount(), 4);
      await repo.markRead('n1');
      await repo.markAllRead(category: 'fees');
      expect(api.find('POST', '/notifications/read-all')!.body, {'category': 'fees'});
      await repo.markAllRead();
      expect(api.find('POST', '/notifications/read-all')!.body, <String, dynamic>{});
      await repo.delete('n1');
      expect(api.count('DELETE', '/notifications/n1'), 1);
    });

    test('preferences load and save one category', () async {
      api.on('GET /notifications/preferences', fixture('notification_prefs'));
      api.on('PUT /notifications/preferences', {'ok': true});
      final repo = c.read(notificationsRepositoryProvider);
      final prefs = await repo.preferences();
      await repo.savePreference(prefs.first.copyWith(push: false));
      final b = api.find('PUT', '/notifications/preferences')!.body as Map;
      expect(b['preferences'], [
        {'category': prefs.first.category, 'push': false, 'email': prefs.first.email},
      ]);
    });
  });

  group('error handling', () {
    test('offline is a network AppException, never a raw DioException', () async {
      api.offline = true;
      for (final call in <Future<Object?> Function()>[
        () => c.read(homeworkRepositoryProvider).list(),
        () => c.read(feesRepositoryProvider).invoices(),
        () => c.read(notificationsRepositoryProvider).unreadCount(),
      ]) {
        await expectLater(call(), throwsA(isA<AppException>().having((e) => e.isNetwork, 'isNetwork', isTrue)));
      }
    });

    test('a non-JSON error page is tolerated', () async {
      api.onFn('GET /homework', (_) => (502, 'Bad gateway'));
      await expectLater(c.read(homeworkRepositoryProvider).list(), throwsA(isA<AppException>().having((e) => e.status, 'status', 502)));
    });

    test('problem+json carries the request id for support', () async {
      api.on('GET /homework', {'title': 'Oops', 'code': 'INTERNAL', 'status': 500, 'requestId': 'req-123'}, status: 500);
      await expectLater(c.read(homeworkRepositoryProvider).list(), throwsA(isA<AppException>().having((e) => e.requestId, 'requestId', 'req-123')));
    });
  });

  test('jsonEncode of attachments stays stable', () {
    expect(jsonEncode(const Attachment(fileId: 'a', name: 'b').toJson()), '{"fileId":"a","name":"b"}');
  });
}
