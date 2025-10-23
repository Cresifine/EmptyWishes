# Notifications Feature

## Overview

Implemented a TikTok-style notification system with intelligent aggregation for likes and comments on user goals.

## Features

### 1. **Smart Notification Aggregation**

Notifications are automatically aggregated when multiple users interact with the same goal within a 24-hour window:

- **Individual Notifications**: "John liked your goal"
- **Aggregated (2 people)**: "John and Sarah liked your goal"
- **Aggregated (3+ people)**: "John and 5 others liked your goal"

### 2. **Notification Types**

- **`like`**: Single user liked a goal
- **`like_aggregated`**: Multiple users liked a goal
- **`comment`**: Single user commented on a goal
- **`comment_aggregated`**: Multiple users commented on a goal

### 3. **Real-time Badge Updates**

- Badge on the "Updates" tab shows unread notification count
- Auto-refreshes every 30 seconds
- Updates immediately when viewing notifications
- Displays "99+" for counts over 99

### 4. **Notification Management**

- **Mark as Read**: Tap a notification to mark it as read
- **Mark All as Read**: Button in app bar to clear all unread notifications
- **Pull to Refresh**: Refresh notifications list
- **Auto-navigation**: Tap notification to view the related goal

## Backend Implementation

### Database Schema

```sql
CREATE TABLE notifications (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,           -- Notification recipient
    type VARCHAR NOT NULL,               -- 'like', 'comment', 'like_aggregated', 'comment_aggregated'
    wish_id INTEGER,                     -- Related goal
    actor_id INTEGER,                    -- Person who triggered (for single notifications)
    actor_ids TEXT,                      -- JSON array of user IDs (for aggregated)
    content TEXT,                        -- Comment text (for comment notifications)
    is_read BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (actor_id) REFERENCES users(id),
    FOREIGN KEY (wish_id) REFERENCES wishes(id)
);
```

### API Endpoints

#### `GET /api/notifications/`
Fetch all notifications for the current user (requires authentication).

**Response:**
```json
[
  {
    "id": 1,
    "type": "like_aggregated",
    "wish_id": 42,
    "wish_title": "Run a Marathon",
    "actor_usernames": ["john_doe", "sarah_smith", "mike_jones"],
    "count": 3,
    "is_read": false,
    "created_at": "2025-10-23T10:30:00",
    "updated_at": "2025-10-23T11:45:00"
  }
]
```

#### `GET /api/notifications/unread-count`
Get count of unread notifications.

**Response:**
```json
{
  "unread_count": 5
}
```

#### `POST /api/notifications/{notification_id}/read`
Mark a specific notification as read.

#### `POST /api/notifications/read-all`
Mark all user's notifications as read.

### Aggregation Logic

```python
AGGREGATION_THRESHOLD = 3  # Aggregate if more than 3 notifications
AGGREGATION_WINDOW_HOURS = 24  # Aggregate within 24 hours

# Algorithm:
# 1. Check if similar notification exists within time window
# 2. If exists and already aggregated, add new actor to the list
# 3. If exists and threshold reached, convert to aggregated
# 4. Otherwise, create new individual notification
```

### Automatic Notification Triggers

Notifications are automatically created when:

1. **User likes a goal** → Notify goal owner
2. **User comments on a goal** → Notify goal owner
3. **No self-notifications** → Users don't get notified of their own actions

## Frontend Implementation

### Notification Service

**Location:** `frontend/lib/services/notification_service.dart`

**Key Methods:**
- `getNotifications()` - Fetch all notifications
- `getUnreadCount()` - Get unread count
- `markAsRead(int id)` - Mark specific notification as read
- `markAllAsRead()` - Mark all as read
- `formatNotificationMessage()` - Format display message

### Notifications Screen

**Location:** `frontend/lib/screens/notifications_screen.dart`

**Features:**
- Beautiful UI with color-coded notification types
- Unread indicator badge on each notification
- Pull-to-refresh support
- Offline mode detection
- Auto-navigation to goal details
- Empty state with helpful message

### Navigation Integration

**Location:** `frontend/lib/main.dart`

**Features:**
- Badge on "Updates" tab with unread count
- Auto-refresh every 30 seconds
- Updates when navigating between tabs
- Clears after viewing notifications

## UI/UX Design

### Color Coding

- **Likes**: Red heart icon (like TikTok)
- **Comments**: Blue comment icon

### Visual States

- **Unread**: Highlighted background + blue dot badge
- **Read**: Normal background, no badge

### Notification Messages

```dart
// Individual like
"john_doe liked your goal"

// Aggregated like (2 people)
"john_doe and sarah_smith liked your goal"

// Aggregated like (3+ people)
"john_doe and 5 others liked your goal"

// Comments (similar format)
"john_doe commented on your goal"
"john_doe and 2 others commented on your goal"
```

### Time Display

Uses `timeago` package for relative time:
- "2 minutes ago"
- "1 hour ago"
- "3 days ago"

## Offline Behavior

- **Offline Mode**: Shows message "Connect to internet to view notifications"
- **No Caching**: Notifications require online connection (by design)
- **Graceful Degradation**: Badge and notifications fail silently when offline

## Security

- **Authentication Required**: All endpoints require Bearer token
- **User Isolation**: Users only see their own notifications
- **No Self-Notification**: System prevents users from notifying themselves

## Performance Optimizations

1. **Polling Interval**: 30 seconds (balance between freshness and API calls)
2. **Result Limit**: 50 most recent notifications
3. **Smart Aggregation**: Reduces notification spam
4. **Indexed Queries**: Database indexes on `user_id` and `created_at`

## Future Enhancements

- [ ] **Push Notifications**: Real-time notifications using Firebase Cloud Messaging
- [ ] **WebSocket Support**: Real-time updates without polling
- [ ] **Notification Preferences**: User settings for notification types
- [ ] **Mute/Unmute Goals**: Disable notifications for specific goals
- [ ] **Rich Notifications**: Include goal images/progress
- [ ] **Notification History**: Archive and search old notifications
- [ ] **Reply from Notification**: Quick reply to comments
- [ ] **Notification Groups**: Group by goal or time period

## Testing Checklist

- [x] Create notification when user likes a goal
- [x] Create notification when user comments on a goal
- [x] Aggregate notifications after threshold
- [x] Display unread badge count
- [x] Mark notification as read on tap
- [x] Mark all notifications as read
- [x] Navigate to goal from notification
- [x] Update badge when notifications change
- [x] Handle offline mode gracefully
- [x] Prevent self-notifications
- [x] Format aggregated messages correctly

## Migration Applied

```bash
alembic upgrade head
```

Migration: `add_notifications_001` - Creates `notifications` table

## Date Implemented
October 23, 2025

## Contributors
- Backend: Notification model, aggregation logic, API endpoints
- Frontend: Notification service, UI screen, badge integration
- Database: Migration for notifications table

