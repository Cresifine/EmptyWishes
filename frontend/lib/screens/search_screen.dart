import 'package:flutter/material.dart';
import '../services/feed_service.dart';
import '../services/user_service.dart';
import 'feed_goal_detail_screen.dart';
import 'user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Goals', 'Users', 'Tags'];
  
  List<Map<String, dynamic>> _goalResults = [];
  List<Map<String, dynamic>> _userResults = [];
  List<String> _tagResults = [];
  
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _hasSearched = false;
        _goalResults = [];
        _userResults = [];
        _tagResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      // Search based on filter
      if (_selectedFilter == 'All' || _selectedFilter == 'Goals') {
        await _searchGoals(query);
      }
      
      if (_selectedFilter == 'All' || _selectedFilter == 'Users') {
        await _searchUsers(query);
      }
      
      if (_selectedFilter == 'All' || _selectedFilter == 'Tags') {
        await _searchTags(query);
      }

      setState(() {
        _hasSearched = true;
        _isSearching = false;
      });
    } catch (e) {
      print('[SearchScreen] Error: $e');
      setState(() => _isSearching = false);
    }
  }

  Future<void> _searchGoals(String query) async {
    try {
      // Search in feed for goals matching query
      final feed = await FeedService.getFeed();
      
      final results = feed.where((item) {
        final wish = item['wish'] as Map<String, dynamic>;
        final title = wish['title']?.toString().toLowerCase() ?? '';
        final description = wish['description']?.toString().toLowerCase() ?? '';
        final tags = wish['tags'] as List<dynamic>?;
        final queryLower = query.toLowerCase();
        
        // Search in title, description, or tags
        bool matchesTitle = title.contains(queryLower);
        bool matchesDescription = description.contains(queryLower);
        bool matchesTags = tags?.any((tag) {
          final tagName = (tag is Map ? tag['name']?.toString() : tag.toString())?.toLowerCase() ?? '';
          return tagName.contains(queryLower);
        }) ?? false;
        
        return matchesTitle || matchesDescription || matchesTags;
      }).toList();
      
      setState(() {
        _goalResults = results;
      });
    } catch (e) {
      print('[SearchScreen] Error searching goals: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    try {
      final users = await UserService.searchUsers(query);
      setState(() {
        _userResults = users;
      });
    } catch (e) {
      print('[SearchScreen] Error searching users: $e');
    }
  }

  Future<void> _searchTags(String query) async {
    try {
      // Get unique tags from goals
      final feed = await FeedService.getFeed();
      final Set<String> tags = {};
      
      for (var item in feed) {
        final wish = item['wish'] as Map<String, dynamic>;
        final wishTags = wish['tags'] as List<dynamic>?;
        if (wishTags != null) {
          for (var tag in wishTags) {
            final tagName = (tag is Map ? tag['name']?.toString() : tag.toString()) ?? '';
            if (tagName.toLowerCase().contains(query.toLowerCase())) {
              tags.add(tagName);
            }
          }
        }
      }
      
      setState(() {
        _tagResults = tags.toList();
      });
    } catch (e) {
      print('[SearchScreen] Error searching tags: $e');
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    if (_searchQuery.isNotEmpty) {
      _performSearch(_searchQuery);
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
    final showGoals = _selectedFilter == 'All' || _selectedFilter == 'Goals';
    final showUsers = _selectedFilter == 'All' || _selectedFilter == 'Users';
    final showTags = _selectedFilter == 'All' || _selectedFilter == 'Tags';

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.black, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search goals, users, tags...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: Colors.black),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.black),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            if (value.length >= 2) {
              _performSearch(value);
            } else if (value.isEmpty) {
              _performSearch('');
            }
          },
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) _onFilterChanged(filter);
                      },
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          
          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Search for goals, users, or tags',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _goalResults.isEmpty && _userResults.isEmpty && _tagResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 80,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No results found for "$_searchQuery"',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            children: [
                              // Users results
                              if (showUsers && _userResults.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.people_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Users (${_userResults.length})',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ..._userResults.map((user) => ListTile(
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      subtitle: Text(
                                        user['email'],
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => UserProfileScreen(userId: user['id']),
                                          ),
                                        );
                                      },
                                    )),
                                const Divider(height: 24),
                              ],
                              
                              // Tags results
                              if (showTags && _tagResults.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.tag_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tags (${_tagResults.length})',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _tagResults.map((tag) => ActionChip(
                                          label: Text(
                                            '#$tag',
                                            style: const TextStyle(color: Colors.black),
                                          ),
                                          onPressed: () {
                                            // Navigate to feed with tag filter
                                            Navigator.of(context).pop();
                                            // TODO: Navigate to feed with tag filter
                                          },
                                        )).toList(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Divider(height: 24),
                              ],
                              
                              // Goals results
                              if (showGoals && _goalResults.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.flag_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Goals (${_goalResults.length})',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ..._goalResults.map((item) {
                                  final wish = item['wish'] as Map<String, dynamic>;
                                  final user = item['user'] as Map<String, dynamic>;
                                  
                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: ListTile(
                                      title: Text(
                                        wish['title'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (wish['description'] != null && wish['description'].toString().isNotEmpty)
                                            Text(
                                              wish['description'],
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(color: Colors.grey[700]),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'by ${user['username']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => FeedGoalDetailScreen(feedItem: item),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

