import '../json.dart';

/// One period in a day (or a break).
class TimetableEntry {
  const TimetableEntry({
    required this.periodName,
    required this.ordinal,
    required this.startTime,
    required this.endTime,
    required this.isBreak,
    this.subjectName,
    this.teacherName,
    this.room,
    this.substituted = false,
    this.substituteTeacherName,
    this.state,
  });

  final String periodName;
  final int ordinal;
  final String startTime;
  final String endTime;
  final bool isBreak;
  final String? subjectName;
  final String? teacherName;
  final String? room;
  final bool substituted;
  final String? substituteTeacherName;

  /// `past` | `current` | `upcoming` (only on today's feed).
  final String? state;

  factory TimetableEntry.fromJson(Json j) {
    final sub = jsonMap(j['substitution']);
    return TimetableEntry(
      periodName: jStrOr(j['periodName']),
      ordinal: jInt(j['ordinal']),
      startTime: jStrOr(j['startTime']),
      endTime: jStrOr(j['endTime']),
      isBreak: jBool(j['isBreak']),
      subjectName: jStr(j['subjectName']),
      teacherName: jStr(j['teacherName']),
      room: jStr(j['room']),
      substituted: jBool(j['substituted']),
      substituteTeacherName: jStr(sub['substituteTeacherName']),
      state: jStr(j['state']),
    );
  }
}

class TimetableDay {
  const TimetableDay({required this.date, required this.dayOfWeek, required this.isWorkingDay, required this.entries, this.sectionName, this.current, this.next});

  final DateTime date;

  /// 1 (Monday) .. 7 (Sunday).
  final int dayOfWeek;
  final bool isWorkingDay;
  final String? sectionName;
  final List<TimetableEntry> entries;
  final TimetableEntry? current;
  final TimetableEntry? next;

  factory TimetableDay.fromJson(Json j) {
    final cur = j['current'], nxt = j['next'];
    return TimetableDay(
      date: jDay(j['date']) ?? DateTime.now(),
      dayOfWeek: jInt(j['dayOfWeek'], 1),
      isWorkingDay: jBool(j['isWorkingDay'], true),
      sectionName: jStr(j['sectionName']),
      entries: jsonList(j['entries']).map(TimetableEntry.fromJson).toList(growable: false),
      current: cur is Map ? TimetableEntry.fromJson(jsonMap(cur)) : null,
      next: nxt is Map ? TimetableEntry.fromJson(jsonMap(nxt)) : null,
    );
  }
}

enum CalendarKind {
  event,
  holiday,
  exam,
  homeworkDue,
  ptm,
  sports,
  other;

  static CalendarKind parse(String? v) => switch (v) {
    'event' => event,
    'holiday' => holiday,
    'exam' || 'exam_paper' => exam,
    'homework_due' => homeworkDue,
    'ptm' => ptm,
    'sports' => sports,
    _ => other,
  };

  String get label => switch (this) {
    event => 'Event',
    holiday => 'Holiday',
    exam => 'Exam',
    homeworkDue => 'Homework due',
    ptm => 'Meeting day',
    sports => 'Sports',
    other => 'Other',
  };
}

/// A row of the calendar feed (events, holidays, exam papers, homework due dates).
class CalendarItem {
  const CalendarItem({required this.id, required this.kind, required this.title, required this.date, required this.endDate, this.subtitle, this.startTime, this.endTime, this.allDay = false, this.location, this.status, this.entityId});

  final String id;
  final CalendarKind kind;
  final String title;
  final String? subtitle;
  final DateTime date;
  final DateTime endDate;
  final String? startTime;
  final String? endTime;
  final bool allDay;
  final String? location;
  final String? status;
  final String? entityId;

  bool get cancelled => status == 'cancelled';

  factory CalendarItem.fromJson(Json j) {
    final d = jDay(j['date']) ?? DateTime.now();
    return CalendarItem(
      id: jStrOr(j['id']),
      kind: CalendarKind.parse(jStr(j['kind'])),
      title: jStrOr(j['title']),
      subtitle: jStr(j['subtitle']),
      date: d,
      endDate: jDay(j['endDate']) ?? d,
      startTime: jStr(j['startTime']),
      endTime: jStr(j['endTime']),
      allDay: jBool(j['allDay']),
      location: jStr(j['location']),
      status: jStr(j['status']),
      entityId: jStr(j['entityId']),
    );
  }

  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(date) && !d.isAfter(endDate);
  }
}
