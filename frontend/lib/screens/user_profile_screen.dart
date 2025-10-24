import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/follow_service.dart';
import '../services/auth_service.dart';
import '../models/wish.dart';
import 'goal_detail_screen.dart';
import 'followers_list_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _userStats;
  List<Wish> _userGoals = [];
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isCurrentUser = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    
    try {
      // Check if this is the current user
      final currentUser = await AuthService.getCurrentUser();
      final isCurrentUser = currentUser != null && currentUser['id'] == widget.userId;
      
      final userData = await UserService.getUserById(widget.userId);
      final userStats = await UserService.getUserStats(widget.userId);
      final userGoals = await UserService.getUserWishes(widget.userId);
      
      // Get follow status if not current user
      Map<String, dynamic>? followStatus;
      if (!isCurrentUser) {
        followStatus = await FollowService.getFollowStatus(widget.userId);
      }
      
      if (mounted) {
        setState(() {
          _userData = userData;
          _userStats = userStats;
          _userGoals = userGoals;
          _isCurrentUser = isCurrentUser;
          _isFollowing = followStatus?['is_following'] ?? false;
          _followersCount = followStatus?['followers_count'] ?? 0;
          _followingCount = followStatus?['following_count'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[UserProfileScreen] Error loading user profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load user profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    bool success;
    if (_isFollowing) {
      success = await FollowService.unfollowUser(widget.userId);
    } else {
      success = await FollowService.followUser(widget.userId);
    }

    if (success && mounted) {
      setState(() {
        _isFollowing = !_isFollowing;
        _followersCount += _isFollowing ? 1 : -1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFollowing ? 'Following user!' : 'Unfollowed user'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update follow status'),
          backgroundColor: Colors.red,
        ),
      );
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
        title: const Text('User Profile'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('User not found'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Profile header
                      Container(
                        padding: const EdgeInsets.all(24),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(
                                _getInitials(_userData!['username']),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _userData!['username'],
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _userData!['email'],
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            // Follow button
                            if (!_isCurrentUser) ...[
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _toggleFollow,
                                icon: Icon(_isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded),
                                label: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _isFollowing ? Colors.grey[400] : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // User stats
                      if (_userStats != null || !_isCurrentUser)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatColumn(
                                label: 'Goals',
                                value: '${_userStats?['total_wishes'] ?? 0}',
                              ),
                              InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => FollowersListScreen(
                                        userId: widget.userId,
                                        title: 'Followers',
                                        isFollowers: true,
                                      ),
                                    ),
                                  );
                                },
                                child: _StatColumn(
                                  label: 'Followers',
                                  value: '$_followersCount',
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => FollowersListScreen(
                                        userId: widget.userId,
                                        title: 'Following',
                                        isFollowers: false,
                                      ),
                                    ),
                                  );
                                },
                                child: _StatColumn(
                                  label: 'Following',
                                  value: '$_followingCount',
                                ),
                              ),
                              _StatColumn(
                                label: 'Avg Progress',
                                value: '${_userStats?['average_progress']?.toStringAsFixed(0) ?? 0}%',
                              ),
                            ],
                          ),
                        ),
                      
                      const Divider(),
                      
                      // User goals
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Public Goals',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            if (_userGoals.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text('No public goals yet'),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _userGoals.length,
                                itemBuilder: (context, index) {
                                  final goal = _userGoals[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      title: Text(
                                        goal.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 8),
                                          Text(
                                            goal.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          LinearProgressIndicator(
                                            value: goal.progress / 100,
                                            minHeight: 6,
                                            backgroundColor: Colors.grey[200],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${goal.progress}% complete',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => GoalDetailScreen(wish: goal),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
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
    );
  }
}
