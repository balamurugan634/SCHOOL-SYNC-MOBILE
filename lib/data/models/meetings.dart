import '../json.dart';
import 'online_meeting.dart';

class Meeting {
  const Meeting({required this.id, required this.status, required this.studentName, required this.teacherName, required this.topic, required this.durationMin, required this.mode, required this.actions, this.studentId, this.teacherDesignation, this.proposedAt, this.scheduledAt, this.locationOrLink, this.outcomeNotes, this.onlineMeeting});
  final String id;

  /// requested | confirmed | declined | completed | cancelled
  final String status;
  final String? studentId;
  final String studentName;
  final String teacherName;
  final String? teacherDesignation;
  final String topic;
  final DateTime? proposedAt;
  final DateTime? scheduledAt;
  final int durationMin;

  /// in_person | online | phone
  final String mode;
  final String? locationOrLink;
  final String? outcomeNotes;
  final List<String> actions;

  /// The video call for this meeting; `null` when there is none (or the server is older than this field).
  final OnlineMeeting? onlineMeeting;

  DateTime? get when => scheduledAt ?? proposedAt;
  bool get canCancel => actions.contains('cancel');
  bool get open => status == 'requested' || status == 'confirmed';

  String get modeLabel => switch (mode) { 'online' => 'Online', 'phone' => 'Phone call', _ => 'In person' };

  factory Meeting.fromJson(Json j) {
    final student = jsonMap(j['student']);
    final teacher = jsonMap(j['teacher']);
    return Meeting(
      id: jStrOr(j['id']),
      status: jStrOr(j['status']),
      studentId: jStr(student['id']),
      studentName: jStrOr(student['name']),
      teacherName: jStrOr(teacher['name']),
      teacherDesignation: jStr(teacher['designation']),
      topic: jStrOr(j['topic']),
      proposedAt: jDate(j['proposedAt']),
      scheduledAt: jDate(j['scheduledAt']),
      durationMin: jInt(j['durationMin'], 15),
      mode: jStrOr(j['mode'], 'in_person'),
      locationOrLink: jStr(j['locationOrLink']),
      outcomeNotes: jStr(j['outcomeNotes']),
      actions: [for (final a in (j['availableActions'] is List ? j['availableActions'] as List : const [])) '$a'],
      onlineMeeting: OnlineMeeting.tryParse(j['onlineMeeting']),
    );
  }
}

class MeetingTeacher {
  const MeetingTeacher({required this.staffId, required this.name, required this.isClassTeacher, this.designation, this.subjects = const []});
  final String staffId;
  final String name;
  final String? designation;
  final bool isClassTeacher;
  final List<String> subjects;
  factory MeetingTeacher.fromJson(Json j) => MeetingTeacher(staffId: jStrOr(j['staffId']), name: jStrOr(j['name']), designation: jStr(j['designation']), isClassTeacher: jBool(j['isClassTeacher']), subjects: [for (final s in (j['subjects'] is List ? j['subjects'] as List : const [])) '$s']);
}
