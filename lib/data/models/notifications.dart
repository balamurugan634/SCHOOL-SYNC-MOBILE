import '../json.dart';

class AppNotification {
  const AppNotification({required this.id, required this.type, required this.category, required this.title, required this.body, required this.read, this.route, this.createdAt});
  final String id;
  final String type;
  final String category;
  final String title;
  final String body;
  final bool read;
  final String? route;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Json j) => AppNotification(
    id: jStrOr(j['id']),
    type: jStrOr(j['type']),
    category: jStrOr(j['category'], 'system'),
    title: jStrOr(j['title']),
    body: jStrOr(j['body']),
    read: jBool(j['read']),
    route: jStr(jsonMap(j['data'])['route']),
    createdAt: jDate(j['createdAt']),
  );

  AppNotification asRead() => AppNotification(id: id, type: type, category: category, title: title, body: body, read: true, route: route, createdAt: createdAt);
}

class NotificationPref {
  const NotificationPref({required this.category, required this.label, required this.push, required this.email});
  final String category;
  final String label;
  final bool push;
  final bool email;
  factory NotificationPref.fromJson(Json j) => NotificationPref(category: jStrOr(j['category']), label: jStrOr(j['label']), push: jBool(j['push']), email: jBool(j['email']));
  NotificationPref copyWith({bool? push, bool? email}) => NotificationPref(category: category, label: label, push: push ?? this.push, email: email ?? this.email);
}
