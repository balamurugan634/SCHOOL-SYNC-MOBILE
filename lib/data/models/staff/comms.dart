import '../../json.dart';

// ───────────────────────────── announcements (author / manager view) ─────────────────────────────

class AudienceTarget {
  const AudienceTarget({required this.type, this.id, required this.label});

  /// all | user_type | role | grade | section
  final String type;
  final String? id;
  final String label;

  Json toJson() => {'type': type, if (id != null) 'id': id};

  factory AudienceTarget.fromJson(Json j) => AudienceTarget(type: jStrOr(j['type'], 'all'), id: jStr(j['id']), label: jStrOr(j['label'], jStrOr(j['id'], 'Everyone')));

  @override
  bool operator ==(Object other) => other is AudienceTarget && other.type == type && other.id == id;
  @override
  int get hashCode => Object.hash(type, id);
}

class ManagedAnnouncement {
  const ManagedAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.priority,
    required this.state,
    this.requiresAck = false,
    this.attachments = const [],
    this.publishAt,
    this.expiresAt,
    this.createdAt,
    this.authorName,
    this.canManage = false,
    this.audience = const [],
    this.readCount,
    this.ackCount,
    this.read = true,
  });

  final String id;
  final String title;
  final String body;

  /// normal | important | urgent
  final String priority;

  /// draft | scheduled | published | expired | archived
  final String state;
  final bool requiresAck;
  final List<Attachment> attachments;
  final DateTime? publishAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String? authorName;
  final bool canManage;
  final List<AudienceTarget> audience;
  final int? readCount;
  final int? ackCount;
  final bool read;

  bool get isDraft => state == 'draft';
  bool get isScheduled => state == 'scheduled';
  bool get isPublished => state == 'published';

  factory ManagedAnnouncement.fromJson(Json j) => ManagedAnnouncement(
    id: jStrOr(j['id']),
    title: jStrOr(j['title']),
    body: jStrOr(j['body']),
    priority: jStrOr(j['priority'], 'normal'),
    state: jStrOr(j['state'], jStrOr(j['status'], 'draft')),
    requiresAck: jBool(j['requiresAck']),
    attachments: Attachment.list(j['attachments']),
    publishAt: jDate(j['publishAt']),
    expiresAt: jDate(j['expiresAt']),
    createdAt: jDate(j['createdAt']),
    authorName: jStr(jsonMap(j['author'])['name']),
    canManage: jBool(j['canManage']),
    audience: jsonList(j['audience']).map(AudienceTarget.fromJson).toList(growable: false),
    readCount: jIntN(j['readCount']),
    ackCount: jIntN(j['ackCount']),
    read: jBool(j['read'], true),
  );
}

class AnnouncementDraft {
  const AnnouncementDraft({required this.title, required this.body, this.priority = 'normal', required this.audience, this.requiresAck = false, this.attachments = const [], this.publishAt, this.expiresAt});
  final String title;
  final String body;
  final String priority;
  final List<AudienceTarget> audience;
  final bool requiresAck;
  final List<Attachment> attachments;
  final DateTime? publishAt;
  final DateTime? expiresAt;

  Json toJson() => {
    'title': title.trim(),
    'body': body.trim(),
    'priority': priority,
    'audience': [for (final a in audience) a.toJson()],
    'requiresAck': requiresAck,
    'attachmentFileIds': [for (final a in attachments) a.fileId],
    if (publishAt != null) 'publishAt': publishAt!.toUtc().toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
  };

  /// PATCH body for a draft: unlike [toJson] an empty expiry is sent as an explicit null (clears it) and the
  /// publish time is left to the schedule / unschedule endpoints.
  Json toUpdateJson() => {
    'title': title.trim(),
    'body': body.trim(),
    'priority': priority,
    'audience': [for (final a in audience) a.toJson()],
    'requiresAck': requiresAck,
    'attachmentFileIds': [for (final a in attachments) a.fileId],
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
  };
}

class AnnouncementStats {
  const AnnouncementStats({this.requiresAck = false, this.audienceSize = 0, this.readCount = 0, this.ackCount = 0, this.unreadCount = 0, this.pendingAckCount = 0, this.byUserType = const [], this.bySection = const []});
  final bool requiresAck;
  final int audienceSize;
  final int readCount;
  final int ackCount;
  final int unreadCount;
  final int pendingAckCount;
  final List<({String label, int audience, int read, int acked})> byUserType;
  final List<({String label, int audience, int read, int acked})> bySection;

  double get readPercent => audienceSize == 0 ? 0 : readCount * 100 / audienceSize;

  factory AnnouncementStats.fromJson(Json j) => AnnouncementStats(
    requiresAck: jBool(j['requiresAck']),
    audienceSize: jInt(j['audienceSize']),
    readCount: jInt(j['readCount']),
    ackCount: jInt(j['ackCount']),
    unreadCount: jInt(j['unreadCount']),
    pendingAckCount: jInt(j['pendingAckCount']),
    byUserType: [for (final r in jsonList(j['byUserType'])) (label: jStrOr(r['userType']), audience: jInt(r['audience']), read: jInt(r['read']), acked: jInt(r['acked']))],
    bySection: [for (final r in jsonList(j['bySection'])) (label: '${jStrOr(r['gradeName'])} ${jStrOr(r['sectionName'])}'.trim(), audience: jInt(r['audience']), read: jInt(r['read']), acked: jInt(r['acked']))],
  );
}

// ───────────────────────────── meetings (teacher / office view) ─────────────────────────────

class StaffMeeting {
  const StaffMeeting({
    required this.id,
    required this.status,
    required this.studentId,
    required this.studentName,
    this.admissionNo,
    this.grade,
    this.section,
    required this.teacherName,
    this.guardianName,
    required this.topic,
    this.proposedAt,
    this.scheduledAt,
    this.durationMin = 15,
    this.mode = 'in_person',
    this.locationOrLink,
    this.outcomeNotes,
    this.actions = const [],
  });

  final String id;

  /// requested | confirmed | declined | completed | cancelled
  final String status;
  final String studentId;
  final String studentName;
  final String? admissionNo;
  final String? grade;
  final String? section;
  final String teacherName;
  final String? guardianName;
  final String topic;
  final DateTime? proposedAt;
  final DateTime? scheduledAt;
  final int durationMin;

  /// in_person | online | phone
  final String mode;
  final String? locationOrLink;
  final String? outcomeNotes;

  /// confirm | decline | reschedule | complete | cancel
  final List<String> actions;

  DateTime? get when => scheduledAt ?? proposedAt;
  bool can(String a) => actions.contains(a);
  String get modeLabel => switch (mode) { 'online' => 'Online', 'phone' => 'Phone call', _ => 'In person' };
  String get classLabel => [grade, section].where((e) => e != null && e.isNotEmpty).join(' ');

  factory StaffMeeting.fromJson(Json j) {
    final s = jsonMap(j['student']);
    return StaffMeeting(
      id: jStrOr(j['id']),
      status: jStrOr(j['status']),
      studentId: jStrOr(s['id']),
      studentName: jStrOr(s['name']),
      admissionNo: jStr(s['admissionNo']),
      grade: jStr(s['grade']),
      section: jStr(s['section']),
      teacherName: jStrOr(jsonMap(j['teacher'])['name']),
      guardianName: jStr(jsonMap(j['guardian'])['name']),
      topic: jStrOr(j['topic']),
      proposedAt: jDate(j['proposedAt']),
      scheduledAt: jDate(j['scheduledAt']),
      durationMin: jInt(j['durationMin'], 15),
      mode: jStrOr(j['mode'], 'in_person'),
      locationOrLink: jStr(j['locationOrLink']),
      outcomeNotes: jStr(j['outcomeNotes']),
      actions: [for (final a in (j['availableActions'] is List ? j['availableActions'] as List : const [])) '$a'],
    );
  }
}
