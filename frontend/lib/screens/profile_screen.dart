import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/follow_service.dart';
import 'login_screen.dart';
import '../widgets/user_search_field.dart';
import 'settings_screen.dart';
import 'followers_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic> _userStats = {};
  bool _isLoading = true;
  bool _isOfflineMode = false;
  int _pendingWishesCount = 0;
  int _pendingUpdatesCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    print('[ProfileScreen] Loading user data...');
    final isOffline = await StorageService.isOfflineMode();
    final hasToken = await StorageService.getToken() != null;
    print('[ProfileScreen] Offline mode: $isOffline, Has token: $hasToken');
    
    // Try to get fresh user data from API
    final userData = await AuthService.getCurrentUser();
    print('[ProfileScreen] User data from API: $userData');
    
    // If no user data from API, try cached data
    Map<String, dynamic>? finalUserData = userData;
    if (finalUserData == null) {
      print('[ProfileScreen] No API data, checking cache...');
      finalUserData = await StorageService.getUser();
      print('[ProfileScreen] Cached user data: $finalUserData');
    }
    
    final pendingWishes = await StorageService.getPendingWishes();
    final pendingUpdates = await StorageService.getPendingProgressUpdates();
    
    // Get followers/following counts if logged in
    int followersCount = 0;
    int followingCount = 0;
    if (!isOffline && hasToken && finalUserData != null) {
      try {
        final followStatus = await FollowService.getFollowStatus(finalUserData['id']);
        followersCount = followStatus?['followers_count'] ?? 0;
        followingCount = followStatus?['following_count'] ?? 0;
      } catch (e) {
        print('[ProfileScreen] Error getting follow counts: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        // Only set offline mode if truly offline (no token and explicitly offline)
        _isOfflineMode = isOffline && !hasToken;
        _userData = finalUserData;
        _userStats = finalUserData?['statistics'] ?? {};
        _pendingWishesCount = pendingWishes?.length ?? 0;
        _pendingUpdatesCount = pendingUpdates?.length ?? 0;
        _followersCount = followersCount;
        _followingCount = followingCount;
        _isLoading = false;
      });
      
      print('[ProfileScreen] Final user data set: $_userData, Offline: $_isOfflineMode');
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isLoading = true);
    
    // Count pending items before sync
    final pendingWishes = await StorageService.getPendingWishes();
    final pendingUpdates = await StorageService.getPendingProgressUpdates();
    final pendingWishCount = pendingWishes?.length ?? 0;
    final pendingUpdateCount = pendingUpdates?.length ?? 0;
    
    // Sync both wishes and progress updates
    await SyncService.backgroundSync();
    
    // Count remaining pending items after sync
    final remainingWishes = await StorageService.getPendingWishes();
    final remainingUpdates = await StorageService.getPendingProgressUpdates();
    final remainingWishCount = remainingWishes?.length ?? 0;
    final remainingUpdateCount = remainingUpdates?.length ?? 0;
    
    if (mounted) {
      final syncedWishes = pendingWishCount - remainingWishCount;
      final syncedUpdates = pendingUpdateCount - remainingUpdateCount;
      final allSynced = remainingWishCount == 0 && remainingUpdateCount == 0;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allSynced 
              ? 'Data synced successfully!' 
              : 'Synced $syncedWishes wishes and $syncedUpdates updates.\n$remainingWishCount wishes and $remainingUpdateCount updates still pending.'
          ),
          backgroundColor: allSynced ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      await _loadUserData();
    }
  }

  void _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final username = _isOfflineMode ? 'Offline User' : (_userData?['username'] ?? 'User');
    final email = _isOfflineMode ? 'Using app offline' : (_userData?['email'] ?? 'No email');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            actions: [],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Profile'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _isOfflineMode
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Sign in to search users',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : const UserSearchField(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      username[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Statistics Card
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bar_chart_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Statistics',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _isOfflineMode
                        ? Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in to view statistics',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.login_rounded),
                                  label: const Text('Sign In'),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.flag_rounded,
                                      value: _userStats['total_wishes']?.toString() ?? '0',
                                      label: 'Goals',
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.trending_up_rounded,
                                      value: '${_userStats['average_progress']?.toStringAsFixed(0) ?? '0'}%',
                                      label: 'Avg Progress',
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        if (_userData != null) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => FollowersListScreen(
                                                userId: _userData!['id'],
                                                title: 'Followers',
                                                isFollowers: true,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: _StatCard(
                                        icon: Icons.people_rounded,
                                        value: '$_followersCount',
                                        label: 'Followers',
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        if (_userData != null) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => FollowersListScreen(
                                                userId: _userData!['id'],
                                                title: 'Following',
                                                isFollowers: false,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: _StatCard(
                                        icon: Icons.person_add_rounded,
                                        value: '$_followingCount',
                                        label: 'Following',
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.check_circle_rounded,
                                      value: _userStats['completed_wishes']?.toString() ?? '0',
                                      label: 'Completed',
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.local_fire_department_rounded,
                                      value: _userStats['current_streak']?.toString() ?? '0',
                                      label: 'Day Streak',
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_isOfflineMode && (_pendingWishesCount > 0 || _pendingUpdatesCount > 0))
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.orange[50],
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload_rounded, color: Colors.orange),
                  title: Text('${_pendingWishesCount + _pendingUpdatesCount} items pending sync'),
                  subtitle: Text('$_pendingWishesCount wishes, $_pendingUpdatesCount updates - Sign in to sync'),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text('Sign In'),
                  ),
                ),
              ),
            if (!_isOfflineMode && (_pendingWishesCount > 0 || _pendingUpdatesCount > 0))
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.blue[50],
                child: ListTile(
                  leading: const Icon(Icons.sync_rounded, color: Colors.blue),
                  title: Text('${_pendingWishesCount + _pendingUpdatesCount} items to sync'),
                  subtitle: Text('$_pendingWishesCount wishes, $_pendingUpdatesCount updates'),
                  trailing: TextButton(
                    onPressed: _syncNow,
                    child: const Text('Sync Now'),
                  ),
                ),
              ),
            Card(
              margin: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bar_chart_rounded),
                    title: const Text('Statistics'),
                    subtitle: const Text('View your progress stats'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.emoji_events_rounded),
                    title: const Text('Achievements'),
                    subtitle: const Text('View your achievements'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (!_isOfflineMode)
                    ListTile(
                      leading: const Icon(Icons.people_rounded),
                      title: const Text('Followers & Following'),
                      subtitle: Text('$_followersCount followers • $_followingCount following'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        if (_userData != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => FollowersListScreen(
                                userId: _userData!['id'],
                                title: 'Followers',
                                isFollowers: true,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  if (!_isOfflineMode)
                    const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                      // Reload user data after settings
                      _loadUserData();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help & Support'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: _isOfflineMode
                  ? FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Sign In'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.all(16),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                    ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatefulWidget {
  final VoidCallback onSyncComplete;

  const _SettingsCard({required this.onSyncComplete});

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  bool _autoSyncEnabled = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final autoSync = await StorageService.isAutoSyncEnabled();
    if (mounted) {
      setState(() => _autoSyncEnabled = autoSync);
    }
  }

  Future<void> _toggleAutoSync(bool value) async {
    await StorageService.setAutoSync(value);
    setState(() => _autoSyncEnabled = value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Auto-sync enabled' : 'Auto-sync disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    
    print('[Settings] ===== Manual sync triggered =====');
    
    // Count pending items before sync
    final pendingWishes = await StorageService.getPendingWishes();
    final pendingUpdates = await StorageService.getPendingProgressUpdates();
    final pendingWishCount = pendingWishes?.length ?? 0;
    final pendingUpdateCount = pendingUpdates?.length ?? 0;
    
    print('[Settings] Pending wishes: $pendingWishCount');
    print('[Settings] Pending progress updates: $pendingUpdateCount');
    
    await SyncService.backgroundSync();
    
    // Count remaining pending items after sync
    final remainingWishes = await StorageService.getPendingWishes();
    final remainingUpdates = await StorageService.getPendingProgressUpdates();
    final remainingWishCount = remainingWishes?.length ?? 0;
    final remainingUpdateCount = remainingUpdates?.length ?? 0;
    
    print('[Settings] Remaining wishes: $remainingWishCount');
    print('[Settings] Remaining progress updates: $remainingUpdateCount');
    
    if (mounted) {
      setState(() => _isSyncing = false);
      
      final syncedWishes = pendingWishCount - remainingWishCount;
      final syncedUpdates = pendingUpdateCount - remainingUpdateCount;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sync completed!\n'
            'Wishes: $syncedWishes synced, $remainingWishCount pending\n'
            'Updates: $syncedUpdates synced, $remainingUpdateCount pending'
          ),
          backgroundColor: (remainingWishCount == 0 && remainingUpdateCount == 0) 
              ? Colors.green 
              : Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      widget.onSyncComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Auto-Sync Toggle
            Row(
              children: [
                Icon(
                  Icons.sync_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auto-Sync',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Automatically sync when online',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _autoSyncEnabled,
                  onChanged: _toggleAutoSync,
                ),
              ],
            ),
            const Divider(height: 24),
            // Manual Sync Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _manualSync,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(_isSyncing ? 'Syncing...' : 'Manual Sync Now'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

