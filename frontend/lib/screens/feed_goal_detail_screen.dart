import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/feed_service.dart';
import '../services/progress_update_service.dart';
import '../services/sync_service.dart';
import 'feed_screen.dart';
import 'user_profile_screen.dart';

class FeedGoalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> feedItem;

  const FeedGoalDetailScreen({super.key, required this.feedItem});

  @override
  State<FeedGoalDetailScreen> createState() => _FeedGoalDetailScreenState();
}

class _FeedGoalDetailScreenState extends State<FeedGoalDetailScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _progressUpdates = [];
  bool _isLoadingComments = true;
  bool _isLoadingProgress = true;
  bool _isOnline = false;
  late Map<String, dynamic> _currentFeedItem;

  @override
  void initState() {
    super.initState();
    _currentFeedItem = widget.feedItem;
    _checkOnlineStatus();
    _loadComments();
    _loadProgressUpdates();
    _recordView();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkOnlineStatus() async {
    final online = await SyncService.isOnline();
    if (mounted) {
      setState(() => _isOnline = online);
    }
  }

  Future<void> _recordView() async {
    final wish = _currentFeedItem['wish'];
    await FeedService.recordView(wish['id']);
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    
    try {
      final wish = _currentFeedItem['wish'];
      final comments = await FeedService.getComments(wish['id']);
      
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
        print('[FeedGoalDetail] Loaded ${comments.length} comments');
      }
    } catch (e) {
      print('[FeedGoalDetail] Error loading comments: $e');
      if (mounted) {
        setState(() {
          _comments = [];
          _isLoadingComments = false;
        });
      }
    }
  }

  Future<void> _loadProgressUpdates() async {
    setState(() => _isLoadingProgress = true);
    
    try {
      final wish = _currentFeedItem['wish'];
      final updates = await ProgressUpdateService.getProgressUpdates(wish['id']);
      
      // Sort by newest first
      updates.sort((a, b) {
        final aDate = DateTime.parse(a['created_at']);
        final bDate = DateTime.parse(b['created_at']);
        return bDate.compareTo(aDate);
      });
      
      if (mounted) {
        setState(() {
          _progressUpdates = updates;
          _isLoadingProgress = false;
        });
      }
    } catch (e) {
      print('[FeedGoalDetail] Error loading progress updates: $e');
      if (mounted) {
        setState(() => _isLoadingProgress = false);
      }
    }
  }

  Future<void> _handleLike() async {
    if (!_isOnline) {
      _showOfflineMessage();
      return;
    }

    final wish = _currentFeedItem['wish'];
    final result = await FeedService.toggleLike(wish['id']);

    if (result != null && mounted) {
      final engagement = _currentFeedItem['engagement'];
      setState(() {
        engagement['is_liked'] = result['liked'];
        engagement['likes_count'] = result['liked'] 
            ? (engagement['likes_count'] + 1)
            : (engagement['likes_count'] - 1);
      });
    }
  }

  Future<void> _addComment() async {
    if (!_isOnline) {
      _showOfflineMessage();
      return;
    }

    final content = _commentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final wish = _currentFeedItem['wish'];
    final success = await FeedService.addComment(wish['id'], content);

    if (success && mounted) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
      
      // Update comment count
      setState(() {
        _currentFeedItem['engagement']['comments_count']++;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment added!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Reload comments
      _loadComments();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add comment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOfflineMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You are offline. Connect to interact with goals.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wish = _currentFeedItem['wish'];
    final user = _currentFeedItem['user'];
    final engagement = _currentFeedItem['engagement'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal Details'),
        actions: [
          if (!_isOnline)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 14, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: TextStyle(color: Colors.orange, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _loadComments();
              _loadProgressUpdates();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User header
                  _buildUserHeader(user, wish),
                  
                  // Goal content
                  _buildGoalContent(wish),
                  
                  // Engagement stats
                  _buildEngagementStats(engagement),
                  
                  const Divider(height: 1),
                  
                  // Action buttons
                  _buildActionButtons(engagement),
                  
                  const Divider(height: 1),
                  
                  // Progress updates section
                  _buildProgressUpdatesSection(),
                  
                  const Divider(height: 1),
                  
                  // Comments section
                  _buildCommentsSection(),
                ],
              ),
            ),
          ),
          
          // Comment input
          if (_isOnline) _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildUserHeader(Map<String, dynamic> user, Map<String, dynamic> wish) {
    final createdAt = DateTime.parse(wish['created_at']);
    
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(userId: user['id']),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                _getInitials(user['username']),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['username'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    timeago.format(createdAt),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalContent(Map<String, dynamic> wish) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wish['title'],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (wish['description'] != null && wish['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              wish['description'],
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ],
          // Consequence
          if (wish['consequence'] != null && wish['consequence'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Consequence',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          wish['consequence'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Tags
          if (wish['tags'] != null && (wish['tags'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (wish['tags'] as List).map((tag) {
                final tagName = tag is Map ? tag['name'] : tag.toString();
                return InkWell(
                  onTap: () {
                    // Navigate to feed screen with tag filter
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => FeedScreen(initialTag: tagName),
                      ),
                    );
                  },
                  child: Chip(
                    label: Text(
                      '#$tagName',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '${wish['progress']}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (wish['progress'] ?? 0) / 100,
                  minHeight: 10,
                  backgroundColor: Colors.grey[200],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEngagementStats(Map<String, dynamic> engagement) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _StatBadge(
            icon: Icons.visibility_rounded,
            count: engagement['views_count'] ?? 0,
            label: 'views',
          ),
          const SizedBox(width: 16),
          _StatBadge(
            icon: Icons.favorite_rounded,
            count: engagement['likes_count'] ?? 0,
            label: 'likes',
            color: Colors.red,
          ),
          const SizedBox(width: 16),
          _StatBadge(
            icon: Icons.comment_rounded,
            count: engagement['comments_count'] ?? 0,
            label: 'comments',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> engagement) {
    final isLiked = engagement['is_liked'] ?? false;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionButton(
            icon: isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
            label: 'Like',
            color: isLiked ? Colors.red : null,
            onPressed: _handleLike,
            isDisabled: !_isOnline,
          ),
          _ActionButton(
            icon: Icons.comment_outlined,
            label: 'Comment',
            onPressed: () {
              // Scroll to comment input
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
              // Focus comment input after a delay
              Future.delayed(const Duration(milliseconds: 350), () {
                if (mounted) {
                  FocusScope.of(context).requestFocus(FocusNode());
                }
              });
            },
            isDisabled: !_isOnline,
          ),
          _ActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
            isDisabled: false,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressUpdatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.timeline_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Progress Updates',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              if (_progressUpdates.isNotEmpty)
                Text(
                  '${_progressUpdates.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        if (_isLoadingProgress)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_progressUpdates.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No progress updates yet',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          ...List.generate(
            _progressUpdates.length,
            (index) => _ProgressUpdateItem(
              update: _progressUpdates[index],
              isLast: index == _progressUpdates.length - 1,
            ),
          ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.comment_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Comments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              if (_comments.isNotEmpty)
                Text(
                  '${_comments.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        if (_isLoadingComments)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text(
                    _isOnline ? 'Be the first to comment!' : 'No comments yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ..._comments.map((comment) => _CommentItem(comment: comment)),
        const SizedBox(height: 80), // Space for comment input
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addComment,
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String username) {
    final parts = username.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.substring(0, username.length > 1 ? 2 : 1).toUpperCase();
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color? color;

  const _StatBadge({
    required this.icon,
    required this.count,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(width: 2),
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final bool isDisabled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: isDisabled ? null : onPressed,
      icon: Icon(icon, size: 20, color: color),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color ?? Colors.grey[700],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

class _ProgressUpdateItem extends StatelessWidget {
  final Map<String, dynamic> update;
  final bool isLast;

  const _ProgressUpdateItem({
    required this.update,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.parse(update['created_at']);
    final progressValue = update['progress_value'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: progressValue != null 
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    progressValue != null 
                        ? Icons.trending_up_rounded 
                        : Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: progressValue != null
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[600],
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (progressValue != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$progressValue%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  update['content'] ?? '',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;

  const _CommentItem({required this.comment});

  String _getInitials(String username) {
    final parts = username.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.substring(0, username.length > 1 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = comment['created_at'] != null 
        ? DateTime.parse(comment['created_at'])
        : DateTime.now();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              _getInitials(comment['username'] ?? 'User'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment['username'] ?? 'User',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment['content'] ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.3),
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
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

