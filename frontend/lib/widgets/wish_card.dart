import 'package:flutter/material.dart';
import '../models/wish.dart';
import '../screens/goal_detail_screen.dart';
import '../services/feed_service.dart';

class WishCard extends StatefulWidget {
  final Wish wish;

  const WishCard({super.key, required this.wish});

  @override
  State<WishCard> createState() => _WishCardState();
}

class _WishCardState extends State<WishCard> {
  int _viewsCount = 0;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _isLoadingEngagement = true;

  @override
  void initState() {
    super.initState();
    // Only load engagement data for non-private goals
    if (widget.wish.visibility != 'private') {
      _loadEngagementData();
    } else {
      _isLoadingEngagement = false;
    }
  }

  Future<void> _loadEngagementData() async {
    try {
      final response = await FeedService.getEngagementStats(widget.wish.id);
      if (mounted && response != null) {
        setState(() {
          _viewsCount = response['views_count'] ?? 0;
          _likesCount = response['likes_count'] ?? 0;
          _commentsCount = response['comments_count'] ?? 0;
          _isLoadingEngagement = false;
        });
      }
    } catch (e) {
      print('[WishCard] Error loading engagement for wish ${widget.wish.id}: $e');
      if (mounted) {
        setState(() => _isLoadingEngagement = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GoalDetailScreen(wish: widget.wish),
        ),
      );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.wish.coverImage != null) ...[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  'http://10.0.2.2:8000${widget.wish.coverImage}',
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                    Expanded(
                      child: Text(
                        widget.wish.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getProgressColor(widget.wish.progress).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.wish.progress}%',
                        style: TextStyle(
                          color: _getProgressColor(widget.wish.progress),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ],
                  ),
                  if (widget.wish.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.wish.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: widget.wish.progress / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getProgressColor(widget.wish.progress),
                      ),
                    ),
                  ),
                  if (widget.wish.targetDate != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Target: ${widget.wish.targetDate!.day}/${widget.wish.targetDate!.month}/${widget.wish.targetDate!.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Engagement Stats (only for non-private goals)
                  if (widget.wish.visibility != 'private') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          _buildEngagementItem(
                            Icons.visibility_rounded,
                            _viewsCount,
                            null,
                          ),
                          const SizedBox(width: 16),
                          _buildEngagementItem(
                            Icons.favorite_rounded,
                            _likesCount,
                            Colors.red,
                          ),
                          const SizedBox(width: 16),
                          _buildEngagementItem(
                            Icons.comment_rounded,
                            _commentsCount,
                            null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementItem(IconData icon, int count, Color? color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          _isLoadingEngagement ? '...' : count.toString(),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(int progress) {
    if (progress < 33) {
      return Colors.red;
    } else if (progress < 66) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
}

