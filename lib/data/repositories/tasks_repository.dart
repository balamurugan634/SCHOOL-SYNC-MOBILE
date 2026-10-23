import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/tasks.dart';

class TasksRepository {
  TasksRepository(this._api);
  final ApiClient _api;

  Future<List<TaskFeedItem>> feed({bool includeDone = false, int limit = 100}) async {
    final body = jsonMap(await _api.get('/tasks/feed', query: {'limit': limit, 'includeDone': includeDone}));
    return jsonList(body['data']).map(TaskFeedItem.fromJson).toList(growable: false);
  }

  Future<Task> create({required String title, String? notes, DateTime? dueAt, DateTime? remindAt, TaskPriority priority = TaskPriority.normal}) async => Task.fromJson(
    jsonMap(await _api.post('/tasks', data: {'title': title.trim(), 'notes': (notes == null || notes.trim().isEmpty) ? null : notes.trim(), 'dueAt': dueAt?.toUtc().toIso8601String(), 'remindAt': remindAt?.toUtc().toIso8601String(), 'priority': priority.name})),
  );

  Future<Task> setStatus(String id, TaskStatus status) async => Task.fromJson(jsonMap(await _api.patch('/tasks/$id', data: {'status': status.name})));

  Future<Task> update(String id, {String? title, String? notes, DateTime? dueAt, TaskPriority? priority}) async => Task.fromJson(
    jsonMap(await _api.patch('/tasks/$id', data: {if (title != null) 'title': title.trim(), if (notes != null) 'notes': notes.trim().isEmpty ? null : notes.trim(), 'dueAt': dueAt?.toUtc().toIso8601String(), if (priority != null) 'priority': priority.name})),
  );

  Future<void> delete(String id) async {
    await _api.delete('/tasks/$id');
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) => TasksRepository(ref.watch(apiClientProvider)));
