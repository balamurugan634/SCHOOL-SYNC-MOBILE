import '../json.dart';

enum TaskPriority {
  low,
  normal,
  high;

  static TaskPriority parse(String? v) => switch (v) { 'low' => low, 'high' => high, _ => normal };
  String get label => switch (this) { low => 'Low', normal => 'Normal', high => 'High' };
}

enum TaskStatus {
  todo,
  doing,
  done;

  static TaskStatus parse(String? v) => switch (v) { 'doing' => doing, 'done' => done, _ => todo };
  String get label => switch (this) { todo => 'To do', doing => 'In progress', done => 'Done' };
}

class Task {
  const Task({required this.id, required this.title, required this.priority, required this.status, this.notes, this.dueAt, this.remindAt});
  final String id;
  final String title;
  final String? notes;
  final DateTime? dueAt;
  final DateTime? remindAt;
  final TaskPriority priority;
  final TaskStatus status;

  bool get done => status == TaskStatus.done;

  factory Task.fromJson(Json j) => Task(
    id: jStrOr(j['id']),
    title: jStrOr(j['title']),
    notes: jStr(j['notes']),
    dueAt: jDate(j['dueAt']),
    remindAt: jDate(j['remindAt']),
    priority: TaskPriority.parse(jStr(j['priority'])),
    status: TaskStatus.parse(jStr(j['status'])),
  );
}

/// A row of the "My tasks" feed: a personal task or a pending homework shown as a task.
class TaskFeedItem {
  const TaskFeedItem({required this.kind, required this.id, required this.title, required this.priority, required this.status, required this.overdue, this.subtitle, this.dueAt});
  final String kind; // task | homework
  final String id;
  final String title;
  final String? subtitle;
  final DateTime? dueAt;
  final TaskPriority priority;
  final TaskStatus status;
  final bool overdue;

  bool get isHomework => kind == 'homework';
  bool get done => status == TaskStatus.done;

  factory TaskFeedItem.fromJson(Json j) => TaskFeedItem(
    kind: jStrOr(j['kind'], 'task'),
    id: jStrOr(j['id']),
    title: jStrOr(j['title']),
    subtitle: jStr(j['subtitle']),
    dueAt: jDate(j['dueAt']),
    priority: TaskPriority.parse(jStr(j['priority'])),
    status: TaskStatus.parse(jStr(j['status'])),
    overdue: jBool(j['overdue']),
  );
}
