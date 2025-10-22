# Offline Mode with Eventual Consistency

## 🎯 Overview

EmptyWishes now supports **offline-first functionality** with **eventual consistency**. Users can use the app without registration, and their data automatically syncs when they log in or go online.

## ✨ Key Features

### 1. **Use Without Registration**
- Users can tap **"Continue Offline"** button on login screen
- Full app functionality available immediately
- No account required to get started

### 2. **Offline Data Storage**
- All wishes created offline are stored locally using `SharedPreferences`
- Data persists across app restarts
- Wishes marked with `sync_status: 'pending'`

### 3. **Eventual Consistency**
- When user logs in → **automatic sync** of all offline wishes
- When user goes online → data syncs to backend
- Sync happens in background without blocking UI

### 4. **Smart Sync Indicators**
- Profile shows count of pending wishes
- Orange banner: "X wishes pending sync - Sign in to sync"
- Blue banner: "X wishes to sync - Sync Now" button
- Real-time sync status updates

## 📱 User Flow

### Offline First-Time User:
```
1. Open app → Login screen
2. Tap "Continue Offline" → Main screen
3. Create wishes → Stored locally
4. Profile shows "Offline User"
5. Banner: "3 wishes pending sync"
```

### Later Signs In:
```
1. Tap "Sign In" from profile
2. Login/Register → Auto-sync starts
3. All 3 offline wishes → Upload to backend
4. Profile updates with real username
5. "Data synced successfully!" message
```

### Online User:
```
1. Create wish → Stored locally + queued for sync
2. Sync happens automatically
3. If sync fails → Stays in queue
4. Tap "Sync Now" → Manual retry
```

## 🔄 Sync Process

### On Login:
```dart
1. User logs in
2. Token saved locally
3. syncPendingWishes() called
4. Each pending wish uploaded to backend
5. On success → Clear from pending queue
6. On failure → Keep in queue for retry
```

### Conflict Resolution:
- **Strategy**: Last-write-wins
- Offline wishes always uploaded
- No duplicate detection (yet)
- Future: Merge strategies

## 💾 Data Storage

### Local Storage Keys:
- `auth_token` - JWT token
- `user_data` - Cached user profile
- `cached_wishes` - Backend wishes (for offline viewing)
- `pending_wishes` - Wishes waiting to sync
- `offline_mode` - Boolean flag

### Pending Wish Structure:
```json
{
  "title": "Learn Flutter",
  "description": "Master Flutter development",
  "target_date": "2025-12-31T00:00:00",
  "sync_status": "pending",
  "created_at_local": "2025-10-22T14:30:00"
}
```

## 🎨 UI/UX

### Login Screen:
- **Primary**: "Login" button (blue)
- **Secondary**: "Sign Up" link
- **Tertiary**: "Continue Offline" button (outlined)
- Helpful text: "Use the app without an account..."

### Profile Screen:

**Offline Mode:**
- Avatar shows "O" (for Offline)
- Name: "Offline User"
- Email: "Using app offline"
- Orange sync banner (if wishes exist)
- Button: "Sign In" (blue, prominent)

**Logged In with Pending:**
- Real avatar with username initial
- Blue sync banner
- "Sync Now" button
- Shows count of pending wishes

## 🔧 Technical Implementation

### Services:
1. **StorageService** - Local data persistence
2. **SyncService** - Sync logic and API calls
3. **AuthService** - Authentication with auto-sync on login
4. **WishService** - Offline-first wish management

### Key Functions:

```dart
// Enable offline mode
AuthService.useOfflineMode()

// Add wish to sync queue
SyncService.addToPendingSync(wish)

// Sync all pending
SyncService.syncPendingWishes()

// Check online status
SyncService.isOnline()

// Fetch with fallback
SyncService.fetchWishesFromBackend()
```

## 🚀 Benefits

1. **Zero Friction Start** - No registration barrier
2. **Always Available** - Works offline completely
3. **No Data Loss** - Everything syncs eventually
4. **Transparent** - User always knows sync status
5. **Flexible** - Use offline indefinitely or sign in anytime

## 📊 Sync States

| State | Description | User Action |
|-------|-------------|-------------|
| `offline_mode` | Using without account | Can sign in anytime |
| `pending` | Created offline, not synced | Automatic on login |
| `syncing` | Upload in progress | None (automatic) |
| `synced` | Successfully uploaded | None |
| `failed` | Sync error | Retry via "Sync Now" |

## 🔮 Future Enhancements

- [ ] Smart conflict resolution
- [ ] Partial sync (sync oldest first)
- [ ] Offline edit detection
- [ ] Background sync
- [ ] Sync progress indicator
- [ ] Offline analytics
- [ ] Export offline data
- [ ] Import data from backup

## 🎯 Use Cases

### Tourist without Data Plan:
- Uses app offline during trip
- Creates 20 wishes
- Returns home, connects WiFi
- Signs in → All wishes synced

### Privacy-Conscious User:
- Wants to try app first
- Uses offline for 2 weeks
- Decides to keep data
- Registers → Keeps everything

### Network Issues:
- User with spotty connection
- Creates wish → Queued
- Connection drops → No problem
- Reconnects → Auto-sync

## 🛡️ Data Safety

- Local data encrypted by device
- No data sent without consent
- User controls when to sync
- Can export before signing in (future)
- Clear indication of online/offline state

---

**Result:** Users can use EmptyWishes completely offline and sync seamlessly when they choose to register!

