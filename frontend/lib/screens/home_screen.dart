import 'package:flutter/material.dart';
import '../models/wish.dart';
import '../widgets/wish_card.dart';
import '../services/wish_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, List<Wish>> _wishes = {
    'current': [],
    'completed': [],
    'failed': [],
    'missed': [],
    'archived': [],
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadWishes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWishes() async {
    setState(() {
      _isLoading = true;
    });

    // Load wishes for each status
    final current = await WishService.getWishesByStatus('current');
    final completed = await WishService.getWishesByStatus('completed');
    final failed = await WishService.getWishesByStatus('failed');
    final missed = await WishService.getWishesByStatus('missed');
    final archived = await WishService.getWishesByStatus('archived');

    if (mounted) {
      setState(() {
        _wishes['current'] = current;
        _wishes['completed'] = completed;
        _wishes['failed'] = failed;
        _wishes['missed'] = missed;
        _wishes['archived'] = archived;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Goals'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadWishes,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(
              icon: Icon(Icons.play_circle_outline_rounded, size: 20),
              text: 'Current',
              height: 65,
            ),
            const Tab(
              icon: Icon(Icons.check_circle_outline_rounded, size: 20),
              text: 'Completed',
              height: 65,
            ),
            const Tab(
              icon: Icon(Icons.cancel_outlined, size: 20),
              text: 'Failed',
              height: 65,
            ),
            const Tab(
              icon: Icon(Icons.access_time_rounded, size: 20),
              text: 'Missed',
              height: 65,
            ),
            const Tab(
              icon: Icon(Icons.archive_outlined, size: 20),
              text: 'Archived',
              height: 65,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWishList(_wishes['current'] ?? [], 'current'),
                _buildWishList(_wishes['completed'] ?? [], 'completed'),
                _buildWishList(_wishes['failed'] ?? [], 'failed'),
                _buildWishList(_wishes['missed'] ?? [], 'missed'),
                _buildWishList(_wishes['archived'] ?? [], 'archived'),
              ],
            ),
    );
  }

  Widget _buildWishList(List<Wish> wishes, String status) {
    if (wishes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconForStatus(status),
              size: 100,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessageForStatus(status),
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWishes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: wishes.length,
        itemBuilder: (context, index) {
          return WishCard(wish: wishes[index]);
        },
      ),
    );
  }

  IconData _getIconForStatus(String status) {
    switch (status) {
      case 'current':
        return Icons.star_border;
      case 'completed':
        return Icons.check_circle_outline;
      case 'failed':
        return Icons.cancel_outlined;
      case 'missed':
        return Icons.access_time;
      case 'archived':
        return Icons.archive_outlined;
      default:
        return Icons.star_border;
    }
  }

  String _getEmptyMessageForStatus(String status) {
    switch (status) {
      case 'current':
        return 'No current goals';
      case 'completed':
        return 'No completed goals yet';
      case 'failed':
        return 'No failed goals';
      case 'missed':
        return 'No missed goals';
      case 'archived':
        return 'No archived goals';
      default:
        return 'No goals';
    }
  }
}
