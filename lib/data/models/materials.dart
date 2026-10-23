import '../json.dart';

class StudyMaterial {
  const StudyMaterial({required this.id, required this.title, required this.subjectName, this.description, this.fileId, this.url, this.createdByName, this.createdAt});
  final String id;
  final String title;
  final String subjectName;
  final String? description;
  final String? fileId;
  final String? url;
  final String? createdByName;
  final DateTime? createdAt;

  factory StudyMaterial.fromJson(Json j) => StudyMaterial(
    id: jStrOr(j['id']),
    title: jStrOr(j['title']),
    subjectName: jStrOr(j['subjectName']),
    description: jStr(j['description']),
    fileId: jStr(j['fileId']),
    url: jStr(j['url']),
    createdByName: jStr(j['createdByName']),
    createdAt: jDate(j['createdAt']),
  );
}

class SyllabusTopic {
  const SyllabusTopic({required this.id, required this.title, required this.subjectName, required this.ordinal, this.termName, this.status = 'not_started', this.plannedHours});
  final String id;
  final String title;
  final String subjectName;
  final int ordinal;
  final String? termName;

  /// not_started | in_progress | completed
  final String status;
  final int? plannedHours;

  factory SyllabusTopic.fromJson(Json j) => SyllabusTopic(
    id: jStrOr(j['id']),
    title: jStrOr(j['title']),
    subjectName: jStrOr(j['subjectName']),
    ordinal: jInt(j['ordinal']),
    termName: jStr(j['termName']),
    status: jStrOr(jsonMap(j['progress'])['status'], 'not_started'),
    plannedHours: jIntN(j['plannedHours']),
  );
}
