import '../json.dart';
import 'online_meeting.dart';

class EventChildResponse {
  const EventChildResponse({required this.studentId, required this.studentName, this.response, this.note, this.respondedAt});
  final String studentId;
  final String studentName;

  /// going | not_going | consent_given | consent_denied | null
  final String? response;
  final String? note;
  final DateTime? respondedAt;

  factory EventChildResponse.fromJson(Json j) => EventChildResponse(studentId: jStrOr(j['studentId']), studentName: jStrOr(j['studentName']), response: jStr(j['response']), note: jStr(j['note']), respondedAt: jDate(j['respondedAt']));
}

class SchoolEvent {
  const SchoolEvent({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.allDay,
    required this.registrationRequired,
    required this.consentRequired,
    required this.responseOpen,
    this.description,
    this.startTime,
    this.endTime,
    this.location,
    this.consentText,
    this.registrationDeadline,
    this.children = const [],
    this.onlineMeeting,
  });

  final String id;
  final String title;
  final String? description;

  /// holiday | event | exam | ptm | sports | other
  final String kind;

  /// draft | published | cancelled
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final String? startTime;
  final String? endTime;
  final bool allDay;
  final String? location;
  final bool registrationRequired;
  final bool consentRequired;
  final String? consentText;
  final DateTime? registrationDeadline;
  final bool responseOpen;
  final List<EventChildResponse> children;

  /// The video call for this event; `null` when there is none (or the server is older than this field).
  final OnlineMeeting? onlineMeeting;

  bool get cancelled => status == 'cancelled';
  bool get needsResponse => (registrationRequired || consentRequired) && responseOpen && children.any((c) => c.response == null);

  String get kindLabel => switch (kind) {
    'holiday' => 'Holiday',
    'event' => 'Event',
    'exam' => 'Exam',
    'ptm' => 'Meeting day',
    'sports' => 'Sports',
    _ => 'Other',
  };

  factory SchoolEvent.fromJson(Json j) {
    final start = jDay(j['startDate']) ?? DateTime.now();
    return SchoolEvent(
      id: jStrOr(j['id']),
      title: jStrOr(j['title']),
      description: jStr(j['description']),
      kind: jStrOr(j['kind'], 'other'),
      status: jStrOr(j['status'], 'published'),
      startDate: start,
      endDate: jDay(j['endDate']) ?? start,
      startTime: jStr(j['startTime']),
      endTime: jStr(j['endTime']),
      allDay: jBool(j['allDay']),
      location: jStr(j['location']),
      registrationRequired: jBool(j['registrationRequired']),
      consentRequired: jBool(j['consentRequired']),
      consentText: jStr(j['consentText']),
      registrationDeadline: jDate(j['registrationDeadline']),
      responseOpen: jBool(j['responseOpen']),
      children: jsonList(j['children']).map(EventChildResponse.fromJson).toList(growable: false),
      onlineMeeting: OnlineMeeting.tryParse(j['onlineMeeting']),
    );
  }
}
