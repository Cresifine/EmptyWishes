import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../services/sync_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _isOnline = false;
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Popular', 'Recent', 'Following'];

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final online = await SyncService.isOnline();
    if (mounted) {
      setState(() {
        _isOnline = online;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isOnline) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Community Feed'),
          elevation: 0,
        ),
        body: Center(
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
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect to internet to see community feed',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _checkConnection,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final publicWishes = MockData.getMockWishes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feed'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _checkConnection,
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
                    },
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _checkConnection,
              child: publicWishes.isEmpty
            ? Center(
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
                      'Follow others to see their goals',
                      style: TextStyle(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: publicWishes.length,
                    itemBuilder: (context, index) {
                      return _FeedWishCard(wish: publicWishes[index]);
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedWishCard extends StatefulWidget {
  final wish;

  const _FeedWishCard({required this.wish});

  @override
  State<_FeedWishCard> createState() => _FeedWishCardState();
}

class _FeedWishCardState extends State<_FeedWishCard> {
  bool _isLiked = false;
  int _likeCount = 42;
  int _commentCount = 12;
  int _viewCount = 234;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                'JD',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: const Text(
              'John Doe',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '2 days ago',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () {},
            ),
          ),
          
          // Goal content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.wish.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.wish.description,
                  style: TextStyle(color: Colors.grey[700]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: widget.wish.progress / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.wish.progress}% complete',
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
                  onPressed: () {
                    setState(() {
                      _isLiked = !_isLiked;
                      _likeCount += _isLiked ? 1 : -1;
                    });
                  },
                ),
                _ActionButton(
                  icon: Icons.comment_outlined,
                  label: 'Comment',
                  onPressed: () {
                    // TODO: Show comment sheet
                  },
                ),
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
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

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      label: Text(label, style: TextStyle(color: color)),
    );
  }
}

