import '../../../data/models/staff/marks.dart';

/// Whole numbers without a decimal point, otherwise at most two decimals (`12`, `12.5`, `12.25`).
String fmtMark(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

final _markPattern = RegExp(r'^\d{1,4}(\.\d{0,2})?$');

/// The number typed in a marks field, or null when empty / not a number.
double? parseMarkText(String text) {
  final t = text.trim();
  if (t.isEmpty || !_markPattern.hasMatch(t)) return null;
  return double.tryParse(t.endsWith('.') ? t.substring(0, t.length - 1) : t);
}

/// Problem with a typed mark, or null when it is empty or fine. [max] is the maximum for the sheet / homework.
String? markError(String text, double max) {
  final t = text.trim();
  if (t.isEmpty) return null;
  if (!_markPattern.hasMatch(t)) return 'Numbers only, up to 2 decimals.';
  final v = parseMarkText(t);
  if (v == null) return 'Numbers only, up to 2 decimals.';
  if (v > max) return 'Cannot be more than ${fmtMark(max)}.';
  return null;
}

/// The state of one student's row while entering marks.
class MarkRowData {
  const MarkRowData({required this.studentId, required this.name, this.rollNo, this.text = '', this.absent = false, this.remarks = ''});
  final String studentId;
  final String name;
  final int? rollNo;
  final String text;
  final bool absent;
  final String remarks;

  factory MarkRowData.fromEntry(MarkEntry e) => MarkRowData(
    studentId: e.studentId,
    name: e.name,
    rollNo: e.rollNo,
    text: e.marksObtained == null ? '' : fmtMark(e.marksObtained!),
    absent: e.isAbsent,
    remarks: e.remarks ?? '',
  );

  /// Has marks or is absent.
  bool get done => absent || parseMarkText(text) != null;

  /// Same content as [other] (marks compared as numbers, so "55" equals "55.0").
  bool sameAs(MarkRowData other) => absent == other.absent && (absent || parseMarkText(text) == parseMarkText(other.text)) && remarks.trim() == other.remarks.trim();
}

/// How far along a mark sheet is, and what blocks submitting.
class MarksProgress {
  const MarksProgress({required this.total, required this.entered, required this.absent, required this.missing, required this.invalid});
  final int total;

  /// Students with a valid mark (not absent).
  final int entered;
  final int absent;

  /// Not absent and no mark yet.
  final List<MarkRowData> missing;

  /// A mark that is not a number or is above the maximum.
  final List<MarkRowData> invalid;

  /// Students with a mark or an absent flag.
  int get done => entered + absent;
  bool get complete => missing.isEmpty && invalid.isEmpty;
  double get fraction => total == 0 ? 0 : done / total;
}

MarksProgress markProgress(List<MarkRowData> rows, double max) {
  var entered = 0, absent = 0;
  final missing = <MarkRowData>[], invalid = <MarkRowData>[];
  for (final r in rows) {
    if (r.absent) {
      absent++;
    } else if (r.text.trim().isEmpty) {
      missing.add(r);
    } else if (markError(r.text, max) != null) {
      invalid.add(r);
    } else {
      entered++;
    }
  }
  return MarksProgress(total: rows.length, entered: entered, absent: absent, missing: missing, invalid: invalid);
}

/// The rows to send when saving: only those that differ from what the server has ([baseline], by student id).
/// Invalid marks are never included.
List<MarkInput> changedMarkInputs(List<MarkRowData> rows, Map<String, MarkRowData> baseline, double max) {
  final out = <MarkInput>[];
  for (final r in rows) {
    final base = baseline[r.studentId];
    if (base != null && r.sameAs(base)) continue;
    if (!r.absent && r.text.trim().isNotEmpty && markError(r.text, max) != null) continue;
    out.add(MarkInput(studentId: r.studentId, marks: r.absent ? null : parseMarkText(r.text), isAbsent: r.absent, remarks: r.remarks));
  }
  return out;
}

/// A sentence listing up to [limit] names, e.g. "Asha, Ben, Chitra and 4 more".
String namesSummary(List<String> names, {int limit = 6}) {
  if (names.length <= limit) {
    if (names.length <= 1) return names.join();
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
  return '${names.take(limit).join(', ')} and ${names.length - limit} more';
}

/// Why the marks cannot be edited right now (null when they can).
String? marksReadOnlyReason(MarkSheet sheet, {required bool canEdit}) {
  if (canEdit) return null;
  return switch (sheet.status) {
    'submitted' => 'These marks were submitted for review, so they cannot be changed. If the reviewer sends them back you can edit them again.',
    'approved' => 'These marks were approved. They are waiting to be published, so they cannot be changed here.',
    'published' => 'These marks are published and visible to students and parents. A correction after publication needs the school office.',
    _ => 'You cannot enter these marks right now. Marks entry may not be open for this exam yet, or you are not the subject teacher of this class.',
  };
}
