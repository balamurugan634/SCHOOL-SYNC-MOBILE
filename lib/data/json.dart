/// Tolerant JSON helpers shared by every model (no codegen, never trust a type).
typedef Json = Map<String, dynamic>;

Json jsonMap(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

List<Json> jsonList(Object? v) => v is List ? [for (final e in v) if (e is Map) e.cast<String, dynamic>()] : <Json>[];

String? jStr(Object? v) => v == null ? null : '$v';
String jStrOr(Object? v, [String fallback = '']) => v == null ? fallback : '$v';
int jInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : (int.tryParse('$v') ?? fallback);
int? jIntN(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
double? jDoubleN(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
double jDouble(Object? v, [double fallback = 0]) => jDoubleN(v) ?? fallback;
bool jBool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

/// ISO-8601 instant or date -> local DateTime.
DateTime? jDate(Object? v) {
  if (v == null) return null;
  final d = DateTime.tryParse('$v');
  return d?.toLocal();
}

/// A calendar date `2026-10-21` (no time zone shifting).
DateTime? jDay(Object? v) {
  if (v == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch('$v');
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

String isoDay(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `{ data: [...], meta: { page, pageSize, total, totalPages } }`
class PageMeta {
  const PageMeta({this.page = 1, this.pageSize = 20, this.total = 0, this.totalPages = 1});
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  bool get hasMore => page < totalPages;

  factory PageMeta.from(Object? v) {
    final m = jsonMap(v);
    return PageMeta(page: jInt(m['page'], 1), pageSize: jInt(m['pageSize'], 20), total: jInt(m['total']), totalPages: jInt(m['totalPages'], 1));
  }
}

class Paged<T> {
  const Paged(this.items, this.meta);
  final List<T> items;
  final PageMeta meta;

  static Paged<T> parse<T>(Object? body, T Function(Json) map) {
    final m = jsonMap(body);
    return Paged(jsonList(m['data']).map(map).toList(growable: false), PageMeta.from(m['meta']));
  }
}

/// `{ data: [...], nextCursor }`
class CursorPage<T> {
  const CursorPage(this.items, this.nextCursor);
  final List<T> items;
  final String? nextCursor;

  static CursorPage<T> parse<T>(Object? body, T Function(Json) map) {
    final m = jsonMap(body);
    return CursorPage(jsonList(m['data']).map(map).toList(growable: false), jStr(m['nextCursor']));
  }
}

/// An attachment as the API stores it (`{ fileId, name, mimeType?, sizeBytes? }`).
class Attachment {
  const Attachment({required this.fileId, required this.name, this.mimeType, this.sizeBytes});
  final String fileId;
  final String name;
  final String? mimeType;
  final int? sizeBytes;

  factory Attachment.fromJson(Json j) => Attachment(fileId: jStrOr(j['fileId'] ?? j['id']), name: jStrOr(j['name'], 'File'), mimeType: jStr(j['mimeType']), sizeBytes: jIntN(j['sizeBytes']));

  Json toJson() => {'fileId': fileId, 'name': name, if (mimeType != null) 'mimeType': mimeType, if (sizeBytes != null) 'sizeBytes': sizeBytes};

  static List<Attachment> list(Object? v) => jsonList(v).map(Attachment.fromJson).where((a) => a.fileId.isNotEmpty).toList(growable: false);
}
