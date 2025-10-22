import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import 'login_screen.dart';
import '../widgets/user_search_field.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final isOffline = await StorageService.isOfflineMode();
    final userData = await AuthService.getCurrentUser();
    final pendingWishes = await StorageService.getPendingWishes();
    
    if (mounted) {
      setState(() {
        _isOfflineMode = isOffline;
        _userData = userData;
        _userStats = userData?['statistics'] ?? {};
        _pendingWishesCount = pendingWishes?.length ?? 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isLoading = true);
    
    final synced = await SyncService.syncPendingWishes();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(synced ? 'Data synced successfully!' : 'Sync failed. Try again later.'),
          backgroundColor: synced ? Colors.green : Colors.orange,
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
            if (_isOfflineMode && _pendingWishesCount > 0)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.orange[50],
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload_rounded, color: Colors.orange),
                  title: Text('$_pendingWishesCount wishes pending sync'),
                  subtitle: const Text('Sign in to sync your data'),
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
            if (!_isOfflineMode && _pendingWishesCount > 0)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.blue[50],
                child: ListTile(
                  leading: const Icon(Icons.sync_rounded, color: Colors.blue),
                  title: Text('$_pendingWishesCount wishes to sync'),
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
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
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

