import 'package:flutter/material.dart';
import '../models/mock_data.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = MockData.getMockNotifications();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Updates'),
        elevation: 0,
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final time = notification['time'] as DateTime;
                final difference = DateTime.now().difference(time);
                String timeAgo;

                if (difference.inDays > 0) {
                  timeAgo = '${difference.inDays}d ago';
                } else if (difference.inHours > 0) {
                  timeAgo = '${difference.inHours}h ago';
                } else {
                  timeAgo = '${difference.inMinutes}m ago';
                }

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: notification['isRead']
                          ? Colors.grey[300]
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.notifications,
                        color: notification['isRead']
                            ? Colors.grey[600]
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      notification['title'],
                      style: TextStyle(
                        fontWeight: notification['isRead']
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notification['message']),
                        const SizedBox(height: 4),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}

