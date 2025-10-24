import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'goal_detail_screen.dart';
import '../models/wish.dart';
import '../services/wish_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkOnlineStatus();
    _loadNotifications();
  }

  Future<void> _checkOnlineStatus() async {
    final online = await SyncService.isOnline();
    if (mounted) {
      setState(() {
        _isOnline = online;
      });
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    try {
      final notifications = await NotificationService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[NotificationsScreen] Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final success = await NotificationService.markAllAsRead();
    if (success && mounted) {
      setState(() {
        for (var notif in _notifications) {
          notif['is_read'] = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read
    if (!notification['is_read']) {
      await NotificationService.markAsRead(notification['id']);
      setState(() {
        notification['is_read'] = true;
      });
    }

    // Navigate to wish detail if wish_id exists
    final wishId = notification['wish_id'];
    if (wishId != null) {
      try {
        final wishes = await WishService.getWishes();
        final wish = wishes.firstWhere(
          (w) => w.id == wishId,
          orElse: () => throw Exception('Wish not found'),
        );
        
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GoalDetailScreen(wish: wish),
            ),
          );
        }
      } catch (e) {
        print('[NotificationsScreen] Error navigating to wish: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Goal not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'like':
      case 'like_aggregated':
        return Icons.favorite_rounded;
      case 'comment':
      case 'comment_aggregated':
        return Icons.comment_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'like':
      case 'like_aggregated':
        return Colors.red;
      case 'comment':
      case 'comment_aggregated':
        return Colors.blue;
      case 'follow':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getInitials(String username) {
    final parts = username.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.substring(0, username.length > 1 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (!_isOnline)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_notifications.any((n) => !n['is_read']))
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isOnline
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You are offline',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connect to internet to view notifications',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'When someone interacts with your goals,\nyou\'ll see it here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final isRead = notification['is_read'] ?? false;
                          final type = notification['type'] ?? '';
                          final createdAt = DateTime.parse(notification['updated_at']);
                          final message = NotificationService.formatNotificationMessage(notification);
                          final wishTitle = notification['wish_title'] ?? 'your goal';
                          
                          return InkWell(
                            onTap: () => _handleNotificationTap(notification),
                            child: Container(
                              color: isRead ? null : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                              child: ListTile(
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: _getNotificationColor(type).withOpacity(0.1),
                                      child: Icon(
                                        _getNotificationIcon(type),
                                        color: _getNotificationColor(type),
                                        size: 24,
                                      ),
                                    ),
                                    if (!isRead)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  message,
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '"$wishTitle"',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timeago.format(createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
