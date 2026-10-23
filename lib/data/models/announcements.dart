import '../json.dart';

class Announcement {
  const Announcement({required this.id, required this.title, required this.body, required this.priority, required this.requiresAck, required this.read, required this.acknowledged, this.authorName, this.publishAt, this.expiresAt, this.attachments = const []});
  final String id;
  final String title;
  final String body;

  /// normal | important | urgent
  final String priority;
  final bool requiresAck;
  final bool read;
  final bool acknowledged;
  final String? authorName;
  final DateTime? publishAt;
  final DateTime? expiresAt;
  final List<Attachment> attachments;

  bool get urgent => priority == 'urgent';
  bool get important => priority == 'important';
  bool get needsAck => requiresAck && !acknowledged;

  factory Announcement.fromJson(Json j) => Announcement(
    id: jStrOr(j['id']),
    title: jStrOr(j['title']),
    body: jStrOr(j['body']),
    priority: jStrOr(j['priority'], 'normal'),
    requiresAck: jBool(j['requiresAck']),
    read: jBool(j['read']),
    acknowledged: jBool(j['acknowledged']),
    authorName: jStr(jsonMap(j['author'])['name']),
    publishAt: jDate(j['publishAt']),
    expiresAt: jDate(j['expiresAt']),
    attachments: Attachment.list(j['attachments']),
  );

  Announcement copyWith({bool? read, bool? acknowledged}) => Announcement(
    id: id, title: title, body: body, priority: priority, requiresAck: requiresAck,
    read: read ?? this.read, acknowledged: acknowledged ?? this.acknowledged,
    authorName: authorName, publishAt: publishAt, expiresAt: expiresAt, attachments: attachments,
  );
}

class AnnouncementCounts {
  const AnnouncementCounts({this.unread = 0, this.pendingAck = 0});
  final int unread;
  final int pendingAck;
  factory AnnouncementCounts.fromJson(Json j) => AnnouncementCounts(unread: jInt(j['unread'] ?? j['unreadCount']), pendingAck: jInt(j['pendingAck'] ?? j['pendingAckCount']));
}
