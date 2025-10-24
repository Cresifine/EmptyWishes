# Tags Feature Documentation

## Overview

Implemented a comprehensive tagging system for goals that allows users to categorize and filter their goals using custom tags.

## Features Implemented

### 1. **Backend Implementation**

#### Database Schema
- **`tags` table**: Stores unique tag names with usage tracking
  ```sql
  CREATE TABLE tags (
      id INTEGER PRIMARY KEY,
      name VARCHAR UNIQUE,
      created_at DATETIME,
      usage_count INTEGER
  );
  ```

- **`wish_tags` table**: Many-to-many junction table
  ```sql
  CREATE TABLE wish_tags (
      wish_id INTEGER,
      tag_id INTEGER,
      created_at DATETIME,
      PRIMARY KEY (wish_id, tag_id)
  );
  ```

#### API Endpoints

1. **GET /api/tags/popular** - Get popular tags sorted by usage
   - Query params: `limit` (default: 20)
   - Returns tags with usage count

2. **GET /api/tags/search** - Search tags (autocomplete)
   - Query params: `q` (query), `limit` (default: 10)
   - Returns matching tags

3. **GET /api/tags/** - Get all tags
   - Query params: `skip`, `limit`

4. **GET /api/tags/{tag_id}** - Get specific tag

#### Updated Endpoints

1. **POST /api/wishes** - Create wish with tags
   - New parameter: `tags` (JSON array of tag names)
   - Auto-creates tags if they don't exist
   - Increments usage_count for each tag

2. **GET /api/wishes/public/feed** - Feed with tag filtering
   - New parameter: `tag` (filter by tag name)
   - Returns wishes with tags included

#### Tag Management
- **Normalization**: Tags are stored in lowercase
- **Auto-creation**: Tags are created on-the-fly when used
- **Usage Tracking**: Each tag tracks how many times it's used
- **get_or_create_tag()**: Helper function for tag management

### 2. **Frontend Implementation**

#### New Service: TagService
**Location**: `frontend/lib/services/tag_service.dart`

**Methods**:
- `getPopularTags()` - Fetch popular tags
- `searchTags(query)` - Search tags with autocomplete
- `getAllTags()` - Fetch all tags

#### Updated: Create Wish Screen
**Features**:
- ✅ Tag input field with autocomplete
- ✅ Live tag suggestions while typing
- ✅ Popular tags displayed as clickable chips
- ✅ Selected tags shown as removable chips
- ✅ Add tags by typing or clicking suggestions
- ✅ Tags sent to backend when creating wish

**UI Components**:
```dart
- Tag input TextField with search
- Suggested tags (autocomplete results)
- Selected tags (removable chips)
- Popular tags (clickable chips)
```

#### Updated: WishService
- Added `tags` parameter to `createWish()`
- Tags stored locally with wishes
- Tags synced to backend automatically

#### Updated: SyncService
- Sends tags as JSON array when syncing wishes
- Tags included in multipart form data

### 3. **User Experience**

#### Creating Goals with Tags
1. User types in tag field
2. Autocomplete shows matching existing tags
3. User can select from suggestions or type new tags
4. Tags appear as chips below the input
5. User can remove tags by clicking X
6. Popular tags shown for quick selection
7. Tags saved with goal locally and synced to backend

#### Tag Behavior
- **Case Insensitive**: "Fitness" and "fitness" are the same tag
- **Whitespace Trimmed**: "  study  " becomes "study"
- **Unique**: Can't add the same tag twice to a goal
- **No Duplicates**: Existing tags are reused automatically

## Technical Implementation

### Database Migration
**File**: `backend/alembic/versions/add_tags_system.py`
- Migration ID: `add_tags_system_001`
- Creates `tags` and `wish_tags` tables
- Applied successfully with Alembic

### Tag Normalization
```python
def get_or_create_tag(db: Session, tag_name: str) -> Tag:
    normalized_name = tag_name.strip().lower()
    # Check if exists or create new
```

### Frontend Tag Input
```dart
// Autocomplete with debounce
onChanged: (query) {
  _searchTags(query);  // Fetches suggestions
}

// Add tag on submit
onSubmitted: (value) {
  _addTag(value);
}
```

### Offline Support
- ✅ Tags stored locally with wishes
- ✅ Tags synced to backend when online
- ✅ Works in offline-first architecture

## API Examples

### Create Wish with Tags
```bash
POST /api/wishes
Content-Type: multipart/form-data

title: "Learn Flutter"
description: "Build mobile apps"
tags: ["flutter", "mobile", "development"]
```

### Search Tags
```bash
GET /api/tags/search?q=fit
Response: [
  {"id": 1, "name": "fitness", "usage_count": 15},
  {"id": 2, "name": "fit-challenge", "usage_count": 5}
]
```

### Filter Feed by Tag
```bash
GET /api/wishes/public/feed?tag=fitness
Response: [
  {
    "wish": {
      "id": 1,
      "title": "Run Marathon",
      "tags": [{"id": 1, "name": "fitness"}]
    }
  }
]
```

## Future Enhancements

### Planned Features
- [ ] **Tag Trending**: Show trending tags in the last 7 days
- [ ] **Tag Colors**: Assign colors to tags for visual categorization
- [ ] **Tag Following**: Follow specific tags to see related goals
- [ ] **Tag Statistics**: Show # of goals per tag
- [ ] **Tag Cloud**: Visual representation of popular tags
- [ ] **Tag Management**: Edit/merge/delete tags (admin)
- [ ] **Tag Suggestions**: ML-based tag suggestions based on goal title/description
- [ ] **Tag Categories**: Group tags into categories (health, career, personal, etc.)

### Feed Enhancements
- [ ] **Multi-tag Filter**: Filter by multiple tags at once
- [ ] **Tag-based Discovery**: Explore page with tag navigation
- [ ] **Related Tags**: Show related tags when viewing a tag
- [ ] **Tag Search in Feed**: Search bar with tag autocomplete in feed screen

### UI Improvements
- [ ] **Tag Icons**: Add icons for popular tags
- [ ] **Tag Badges**: Visual badges for frequently used tags
- [ ] **Tag Display on Cards**: Show tags on wish cards in lists
- [ ] **Tag Edit**: Edit tags on existing wishes

## Testing Checklist

- [x] Create wish with tags (backend)
- [x] Tags stored in database
- [x] Tags auto-created if new
- [x] Usage count incremented
- [x] Search tags endpoint works
- [x] Popular tags endpoint works
- [x] Feed filtering by tag works
- [x] Frontend tag input with autocomplete
- [x] Popular tags displayed
- [x] Tag selection and removal
- [x] Tags included in wish creation
- [x] Tags synced to backend
- [x] Offline tag support
- [ ] Display tags on wish cards (TODO)
- [ ] Feed tag filter UI (TODO)

## Files Modified/Created

### Backend
- ✅ `app/models/tag.py` - Tag model and wish_tags table
- ✅ `app/schemas/tag.py` - Tag schemas
- ✅ `app/api/tags.py` - Tag API endpoints
- ✅ `app/models/wish.py` - Added tags relationship
- ✅ `app/api/wishes.py` - Updated to handle tags
- ✅ `main.py` - Registered tags router
- ✅ `alembic/versions/add_tags_system.py` - Database migration

### Frontend
- ✅ `lib/services/tag_service.dart` - New tag service
- ✅ `lib/screens/create_wish_screen.dart` - Added tag input
- ✅ `lib/services/wish_service.dart` - Added tags parameter
- ✅ `lib/services/sync_service.dart` - Sync tags to backend

## Date Implemented
October 24, 2025

## Migration Status
✅ Database migration applied successfully
✅ Backend running with tag support
✅ Frontend integrated and tested

