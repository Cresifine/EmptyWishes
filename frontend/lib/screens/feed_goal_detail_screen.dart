import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/feed_service.dart';
import '../services/progress_update_service.dart';
import '../services/sync_service.dart';
import '../services/milestone_service.dart';
import '../services/verification_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../models/milestone.dart';
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
  List<Milestone> _milestones = [];
  List<Map<String, dynamic>> _verifications = [];
  String? _ownerDisputeResponse;
  bool _isLoadingComments = true;
  bool _isLoadingProgress = true;
  bool _isLoadingMilestones = true;
  bool _isLoadingVerifications = false;
  bool _isOnline = false;
  int? _currentUserId;
  late Map<String, dynamic> _currentFeedItem;
  final MilestoneService _milestoneService = MilestoneService();

  @override
  void initState() {
    super.initState();
    _currentFeedItem = widget.feedItem;
    _checkOnlineStatus();
    _loadCurrentUser();
    _loadComments();
    _loadProgressUpdates();
    _loadMilestones();
    _loadVerifications();
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

  Future<void> _loadCurrentUser() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (mounted && currentUser != null) {
        setState(() {
          _currentUserId = currentUser['id'];
        });
      }
    } catch (e) {
      print('[FeedGoalDetail] Error loading current user: $e');
    }
  }

  Future<void> _loadVerifications() async {
    final wish = _currentFeedItem['wish'];
    if (wish['requires_verification'] != true) return;
    
    setState(() => _isLoadingVerifications = true);
    
    try {
      final response = await VerificationService.getVerifications(wish['id']);
      
      if (mounted) {
        setState(() {
          _verifications = response['verifications'] ?? [];
          _ownerDisputeResponse = response['owner_dispute_response'];
          _isLoadingVerifications = false;
        });
        
        // Debug: Log verification details
        print('[FeedGoalDetail] Loaded ${_verifications.length} verifications');
        for (var v in _verifications) {
          print('[FeedGoalDetail] Verification: ${v['verifier']['username']} - ${v['status']} - dispute_reason: ${v['dispute_reason']} - comment: ${v['comment']}');
        }
        if (_ownerDisputeResponse != null) {
          print('[FeedGoalDetail] Owner response: $_ownerDisputeResponse');
        }
      }
    } catch (e) {
      print('[FeedGoalDetail] Error loading verifications: $e');
      if (mounted) {
        setState(() => _isLoadingVerifications = false);
      }
    }
  }

  Future<void> _handleVerification(bool approved) async {
    final TextEditingController commentController = TextEditingController();
    final TextEditingController disputeController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approved ? 'Approve Goal' : 'Dispute Goal'),
        content: approved
            ? TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  hintText: 'Add your feedback...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              )
            : TextField(
                controller: disputeController,
                decoration: const InputDecoration(
                  labelText: 'Reason for dispute',
                  hintText: 'Why are you disputing this?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approved ? 'Approve' : 'Dispute'),
          ),
        ],
      ),
    );

    if (result == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final wish = _currentFeedItem['wish'];
      final success = await VerificationService.verifyCompletion(
        wishId: wish['id'],
        status: approved ? 'approved' : 'disputed',
        comment: approved && commentController.text.isNotEmpty ? commentController.text : null,
        disputeReason: !approved && disputeController.text.isNotEmpty ? disputeController.text : null,
      );

      if (mounted) Navigator.pop(context); // Close loading

      if (success) {
        await _loadVerifications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approved ? 'Goal approved!' : 'Goal disputed'),
              backgroundColor: approved ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit verification'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleVerifierReply() async {
    final TextEditingController replyController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply to Owner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Respond to the owner\'s explanation. You can then approve or re-dispute the goal.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: replyController,
              decoration: const InputDecoration(
                labelText: 'Your reply',
                hintText: 'Type your response...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );

    if (result == true && replyController.text.trim().isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get the current user's verification
      final myVerification = _verifications.firstWhere(
        (v) => v['verifier']['id'] == _currentUserId && v['status'] == 'disputed'
      );

      final wish = _currentFeedItem['wish'];
      final success = await VerificationService.verifierReplyToOwner(
        wishId: wish['id'],
        verificationId: myVerification['id'],
        reply: replyController.text.trim(),
      );

      if (mounted) Navigator.pop(context); // Close loading

      if (success) {
        await _loadVerifications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reply sent to owner!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send reply'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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

  Future<void> _loadMilestones() async {
    setState(() => _isLoadingMilestones = true);
    
    try {
      final wish = _currentFeedItem['wish'];
      final milestones = await _milestoneService.getWishMilestones(wish['id']);
      
      if (mounted) {
        setState(() {
          _milestones = milestones;
          _isLoadingMilestones = false;
        });
      }
    } catch (e) {
      print('[FeedGoalDetail] Error loading milestones: $e');
      if (mounted) {
        setState(() => _isLoadingMilestones = false);
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
              _loadMilestones();
              _loadVerifications();
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
                  
                  // Milestones section
                  if (_milestones.isNotEmpty) _buildMilestonesSection(),
                  
                  if (_milestones.isNotEmpty) const Divider(height: 1),
                  
                  // Verifications section
                  _buildVerificationsSection(),
                  
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

  Widget _buildMilestonesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.flag_outlined, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Milestones',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_milestones.where((m) => m.isCompleted).length}/${_milestones.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (_isLoadingMilestones)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_milestones.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No milestones set',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: List.generate(_milestones.length, (index) {
                final milestone = _milestones[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 1,
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: milestone.isCompleted
                          ? Colors.green.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.2),
                      child: Icon(
                        milestone.isCompleted
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 20,
                        color: milestone.isCompleted ? Colors.green : Colors.blue,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            milestone.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: milestone.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 10, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                '${milestone.points}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    subtitle: milestone.description != null && milestone.description!.isNotEmpty
                        ? Text(
                            milestone.description!,
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                  ),
                );
              }),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildVerificationsSection() {
    final wish = _currentFeedItem['wish'];
    if (wish['requires_verification'] != true) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Verification Required',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_verifications.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_verifications.where((v) => v['status'] == 'approved').length}/${_verifications.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoadingVerifications)
                const Center(child: CircularProgressIndicator())
              else if (_verifications.isEmpty)
                Text(
                  'No verifiers assigned yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                )
              else
                Column(
                  children: _verifications.map((verification) {
                    final isPending = verification['status'] == 'pending';
                    final isApproved = verification['status'] == 'approved';
                    final isDisputed = verification['status'] == 'disputed';
                    final verifierId = verification['verifier'] != null 
                        ? verification['verifier']['id']
                        : null;
                    final isVerifier = _currentUserId != null && _currentUserId == verifierId;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isApproved
                              ? Colors.green.withOpacity(0.2)
                              : isDisputed
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                          child: Icon(
                            isApproved
                                ? Icons.check_circle
                                : isDisputed
                                    ? Icons.error_outline
                                    : Icons.schedule,
                            size: 20,
                            color: isApproved
                                ? Colors.green
                                : isDisputed
                                    ? Colors.orange
                                    : Colors.grey,
                          ),
                        ),
                        title: Text(
                          verification['verifier'] != null 
                              ? verification['verifier']['username'] ?? 'Unknown'
                              : 'Unknown',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: isDisputed && verification['dispute_reason'] != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dispute reason:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[900],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    verification['dispute_reason'],
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              )
                            : verification['comment'] != null
                                ? Text(
                                    verification['comment'],
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text(
                                    isPending ? 'Pending review' : verification['status'],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                        trailing: isVerifier && isPending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                    onPressed: () => _handleVerification(true),
                                    tooltip: 'Approve',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.orange),
                                    onPressed: () => _handleVerification(false),
                                    tooltip: 'Dispute',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              
              // Owner's Dispute Response
              if (_ownerDisputeResponse != null && _ownerDisputeResponse!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.reply_rounded, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 6),
                          Text(
                            'Owner\'s Response',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _ownerDisputeResponse!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                      
                      // Show verifier's reply if exists
                      if (_verifications.isNotEmpty && _verifications.first['verifier_reply_to_owner'] != null) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.message_rounded, size: 16, color: Colors.orange[700]),
                            const SizedBox(width: 6),
                            Text(
                              'Your Reply',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _verifications.first['verifier_reply_to_owner'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                      
                      // Reply button for verifier (only if they haven't replied yet and they disputed)
                      if (_verifications.isNotEmpty && 
                          _verifications.any((v) => 
                            v['verifier']['id'] == _currentUserId && 
                            v['status'] == 'disputed' &&
                            (v['verifier_reply_to_owner'] == null || v['verifier_reply_to_owner'].isEmpty)
                          )) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _handleVerifierReply,
                          icon: const Icon(Icons.reply_rounded, size: 18),
                          label: const Text('Reply to Owner'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
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

