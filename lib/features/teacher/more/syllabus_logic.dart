import '../../../data/models/staff/teaching.dart';

/// Tap-to-cycle order: not started -> in progress -> completed -> not started.
SyllabusStatus nextSyllabusStatus(SyllabusStatus s) => switch (s) {
  SyllabusStatus.notStarted => SyllabusStatus.inProgress,
  SyllabusStatus.inProgress => SyllabusStatus.completed,
  SyllabusStatus.completed => SyllabusStatus.notStarted,
};

/// What a topic shows: the unsaved choice when there is one, otherwise what the server has.
SyllabusStatus effectiveStatus(TopicEntry t, Map<String, SyllabusStatus> changes) => changes[t.id] ?? t.status;

/// Records [status] for [topic]. A change back to the saved value removes the edit, so "Save" only counts real changes.
Map<String, SyllabusStatus> withChange(Map<String, SyllabusStatus> changes, TopicEntry topic, SyllabusStatus status) {
  final next = Map<String, SyllabusStatus>.of(changes);
  if (status == topic.status) {
    next.remove(topic.id);
  } else {
    next[topic.id] = status;
  }
  return next;
}

/// Coverage with the unsaved edits applied (completed / all topics, as the API computes it).
({int total, int completed, int inProgress, double percent}) previewCoverage(List<TopicEntry> topics, Map<String, SyllabusStatus> changes) {
  var completed = 0, inProgress = 0;
  for (final t in topics) {
    switch (effectiveStatus(t, changes)) {
      case SyllabusStatus.completed:
        completed++;
      case SyllabusStatus.inProgress:
        inProgress++;
      case SyllabusStatus.notStarted:
        break;
    }
  }
  final total = topics.length;
  final pct = total == 0 ? 0.0 : (completed * 1000 / total).round() / 10;
  return (total: total, completed: completed, inProgress: inProgress, percent: pct);
}

/// Topics grouped by term in the order the API listed them ("Whole year" when a topic has no term).
List<(String, List<TopicEntry>)> groupByTerm(List<TopicEntry> topics) {
  final groups = <String, List<TopicEntry>>{};
  for (final t in topics) {
    groups.putIfAbsent(t.termName ?? 'Whole year', () => []).add(t);
  }
  return [for (final e in groups.entries) (e.key, e.value)];
}
