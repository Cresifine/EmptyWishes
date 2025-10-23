import 'package:flutter/material.dart';
import '../services/feed_service.dart';
import '../services/sync_service.dart';
import '../services/storage_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'feed_goal_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _isOnline = false;
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Popular', 'Recent'];
  List<Map<String, dynamic>> _feedItems = [];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    
    final isOnline = await SyncService.isOnline();
    final feedItems = await FeedService.getFeed(
      filter: _selectedFilter == 'All' ? null : _selectedFilter,
    );
    
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
        _feedItems = feedItems;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feed'),
        elevation: 0,
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFeed,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                      _loadFeed();
                    },
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                );
              },
            ),
          ),
          
          // Feed content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadFeed,
                    child: _feedItems.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _feedItems.length,
                            itemBuilder: (context, index) {
                              return _FeedWishCard(
                                feedItem: _feedItems[index],
                                isOnline: _isOnline,
                                onRefresh: _loadFeed,
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (!_isOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 100,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No cached posts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to internet to see community feed',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadFeed,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.public_rounded,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share your goals!',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _FeedWishCard extends StatefulWidget {
  final Map<String, dynamic> feedItem;
  final bool isOnline;
  final VoidCallback onRefresh;

  const _FeedWishCard({
    required this.feedItem,
    required this.isOnline,
    required this.onRefresh,
  });

  @override
  State<_FeedWishCard> createState() => _FeedWishCardState();
}

class _FeedWishCardState extends State<_FeedWishCard> {
  late bool _isLiked;
  late int _likeCount;
  late int _commentCount;
  late int _viewCount;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    final engagement = widget.feedItem['engagement'] ?? {};
    _isLiked = engagement['is_liked'] ?? false;
    _likeCount = engagement['likes_count'] ?? 0;
    _commentCount = engagement['comments_count'] ?? 0;
    _viewCount = engagement['views_count'] ?? 0;
  }

  Future<void> _handleLike() async {
    if (!widget.isOnline) {
      _showOfflineMessage();
      return;
    }

    if (_isLiking) return;

    setState(() => _isLiking = true);

    final wish = widget.feedItem['wish'];
    final result = await FeedService.toggleLike(wish['id']);

    if (result != null && mounted) {
      setState(() {
        final wasLiked = _isLiked;
        _isLiked = result['liked'] ?? !wasLiked;
        _likeCount += _isLiked ? 1 : -1;
        _isLiking = false;
      });
    } else if (mounted) {
      setState(() => _isLiking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update like'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOfflineMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You must be online to interact with posts'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showCommentDialog() {
    if (!widget.isOnline) {
      _showOfflineMessage();
      return;
    }

    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(
            hintText: 'Write your comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final content = commentController.text.trim();
              if (content.isEmpty) {
                return;
              }

              Navigator.pop(context);

              final wish = widget.feedItem['wish'];
              final success = await FeedService.addComment(wish['id'], content);

              if (success && mounted) {
                setState(() => _commentCount++);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Comment added'),
                    backgroundColor: Colors.green,
                  ),
                );
                widget.onRefresh();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to add comment'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  String _getInitials(String username) {
    final parts = username.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.substring(0, 2).toUpperCase();
  }

  void _navigateToGoalDetail() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FeedGoalDetailScreen(feedItem: widget.feedItem),
      ),
    );
    
    // Refresh feed if changes were made
    if (result == true && mounted) {
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wish = widget.feedItem['wish'];
    final user = widget.feedItem['user'];
    final createdAt = DateTime.parse(wish['created_at']);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _navigateToGoalDetail,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                _getInitials(user['username']),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              user['username'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              timeago.format(createdAt),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () {
                // TODO: Show options menu
              },
            ),
          ),
          
          // Goal content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wish['title'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  wish['description'] ?? '',
                  style: TextStyle(color: Colors.grey[700]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (wish['progress'] ?? 0) / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${wish['progress'] ?? 0}% complete',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 24),
          
          // Engagement stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.visibility_rounded,
                  count: _viewCount,
                  label: 'views',
                ),
                const SizedBox(width: 16),
                _StatChip(
                  icon: Icons.favorite_rounded,
                  count: _likeCount,
                  label: 'likes',
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _StatChip(
                  icon: Icons.comment_rounded,
                  count: _commentCount,
                  label: 'comments',
                ),
              ],
            ),
          ),
          
          const Divider(height: 24),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(
                  icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  label: 'Like',
                  color: _isLiked ? Colors.red : null,
                  onPressed: _handleLike,
                  isDisabled: !widget.isOnline || _isLiking,
                ),
                _ActionButton(
                  icon: Icons.comment_outlined,
                  label: 'Comment',
                  onPressed: _showCommentDialog,
                  isDisabled: !widget.isOnline,
                ),
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onPressed: () {
                    // TODO: Implement share functionality
                  },
                  isDisabled: false,
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color? color;

  const _StatChip({
    required this.icon,
    required this.count,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onPressed;
  final bool isDisabled;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onPressed,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: TextButton.icon(
        onPressed: isDisabled ? null : onPressed,
        icon: Icon(icon, color: color),
        label: Text(label, style: TextStyle(color: color)),
      ),
    );
  }
}
