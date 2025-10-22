import 'wish.dart';

class MockData {
  static List<Wish> getMockWishes() {
    return [
      Wish(
        id: 1,
        title: 'Learn Flutter',
        description: 'Master Flutter development for mobile apps',
        progress: 65,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        targetDate: DateTime.now().add(const Duration(days: 20)),
      ),
      Wish(
        id: 2,
        title: 'Run a Marathon',
        description: 'Complete a full marathon in under 4 hours',
        progress: 30,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        targetDate: DateTime.now().add(const Duration(days: 90)),
      ),
      Wish(
        id: 3,
        title: 'Read 50 Books',
        description: 'Read 50 books this year',
        progress: 80,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 200)),
        targetDate: DateTime.now().add(const Duration(days: 165)),
      ),
      Wish(
        id: 4,
        title: 'Learn Spanish',
        description: 'Become conversational in Spanish',
        progress: 45,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        targetDate: DateTime.now().add(const Duration(days: 335)),
      ),
    ];
  }

  static List<Map<String, dynamic>> getMockNotifications() {
    return [
      {
        'title': 'Progress Update',
        'message': 'You\'ve completed 65% of "Learn Flutter"!',
        'time': DateTime.now().subtract(const Duration(hours: 2)),
        'isRead': false,
      },
      {
        'title': 'New Milestone',
        'message': 'Congratulations! You reached 80% on "Read 50 Books"',
        'time': DateTime.now().subtract(const Duration(hours: 5)),
        'isRead': false,
      },
      {
        'title': 'Reminder',
        'message': 'Don\'t forget to update your progress on "Run a Marathon"',
        'time': DateTime.now().subtract(const Duration(days: 1)),
        'isRead': true,
      },
    ];
  }
}

