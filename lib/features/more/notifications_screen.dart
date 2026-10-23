import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Phase 1: the inbox arrives with the communication module.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: const EmptyState(
      icon: Icons.notifications_none_rounded,
      title: 'Your inbox is coming',
      message: 'Announcements, homework, attendance and fee notices will collect here. Push alerts can be managed in Settings.',
    ),
  );
}
