import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/wish.dart';
import '../services/progress_update_service.dart';
import '../services/wish_service.dart';
import '../services/auth_service.dart';

class GoalDetailScreen extends StatefulWidget {
  final Wish wish;

  const GoalDetailScreen({super.key, required this.wish});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  List<Map<String, dynamic>> _progressUpdates = [];
  bool _isLoading = true;
  final _updateController = TextEditingController();
  List<File> _selectedFiles = [];
  int? _progressValue;
  final ImagePicker _picker = ImagePicker();
  late Wish _currentWish; // Track the current wish state
  int? _currentUserId; // Track the current logged-in user's ID
  bool _isOwner = false; // Whether the current user owns this goal

  @override
  void initState() {
    super.initState();
    _currentWish = widget.wish; // Initialize with the passed wish
    _checkOwnership();
    _loadProgressUpdates();
  }

  Future<void> _checkOwnership() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser != null && mounted) {
        setState(() {
          _currentUserId = currentUser['id'];
          _isOwner = (_currentUserId == _currentWish.userId);
        });
        print('[GoalDetailScreen] Current user ID: $_currentUserId, Goal owner ID: ${_currentWish.userId}, Is owner: $_isOwner');
      }
    } catch (e) {
      print('[GoalDetailScreen] Error checking ownership: $e');
    }
  }

  @override
  void dispose() {
    _updateController.dispose();
    super.dispose();
  }

  Future<void> _loadProgressUpdates() async {
    print('[GoalDetailScreen] ===== Loading progress updates for wish ${_currentWish.id} =====');
    setState(() => _isLoading = true);
    
    final updates = await ProgressUpdateService.getProgressUpdates(_currentWish.id);
    print('[GoalDetailScreen] Received ${updates.length} updates');
    
    // Sort updates: newest first (top), oldest last (bottom)
    updates.sort((a, b) {
      final aDate = DateTime.parse(a['created_at']);
      final bDate = DateTime.parse(b['created_at']);
      return bDate.compareTo(aDate); // Descending order (newest first)
    });
    
    print('[GoalDetailScreen] After sorting: ${updates.length} updates');
    if (updates.isNotEmpty) {
      print('[GoalDetailScreen] First update: ${updates.first['content']}');
    } else {
      print('[GoalDetailScreen] ⚠️ No updates to display!');
    }
    
    if (mounted) {
      setState(() {
        _progressUpdates = updates;
        _isLoading = false;
      });
      print('[GoalDetailScreen] UI updated with ${_progressUpdates.length} updates');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedFiles.add(File(image.path));
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }
  
  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(
            result.paths.where((path) => path != null).map((path) => File(path!))
          );
        });
      }
    } catch (e) {
      print('Error picking files: $e');
    }
  }
  
  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _showAddUpdateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Add Progress Update',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _updateController,
                  decoration: const InputDecoration(
                    labelText: 'Update message',
                    hintText: 'Share your progress...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                
                // Progress slider
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        children: [
                          const Text(
                            'Update Progress',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Text(
                            '${_progressValue ?? _currentWish.progress}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    Slider(
                      value: (_progressValue ?? _currentWish.progress).toDouble(),
                      min: _currentWish.progress.toDouble(), // Can't go below current progress
                      max: 100,
                      divisions: (100 - _currentWish.progress) ~/ 5, // Dynamic divisions based on remaining progress
                      label: '${_progressValue ?? _currentWish.progress}%',
                      onChanged: (value) {
                        final newValue = value.toInt();
                        if (newValue < _currentWish.progress) {
                          // Show warning if trying to decrease
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Cannot decrease progress below ${_currentWish.progress}%'),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        setModalState(() {
                          setState(() {
                            _progressValue = newValue;
                          });
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // File attachments
                if (_selectedFiles.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedFiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      final fileName = file.path.split('/').last;
                      return Chip(
                        label: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          _removeFile(index);
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _pickImage();
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Photo'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _pickFiles();
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.attach_file_rounded),
                        label: const Text('Files'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Don't clear here - will clear after successful update
                    Navigator.pop(context);
                    _addProgressUpdate();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text('Post Update', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addProgressUpdate() async {
    // Validate progress isn't decreasing
    if (_progressValue != null && _progressValue! < _currentWish.progress) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot decrease progress below ${_currentWish.progress}%'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Allow empty content if progress changed or files added
    final hasContent = _updateController.text.trim().isNotEmpty;
    final hasProgressChange = _progressValue != null && _progressValue != _currentWish.progress;
    final hasFiles = _selectedFiles.isNotEmpty;
    
    final contentToSend = _updateController.text.trim();
    print('[GoalDetailScreen] hasContent: $hasContent, hasProgressChange: $hasProgressChange, hasFiles: $hasFiles, filesCount: ${_selectedFiles.length}');
    print('[GoalDetailScreen] Content to send: "$contentToSend"');
    print('[GoalDetailScreen] Progress value: $_progressValue');
    
    if (!hasContent && !hasProgressChange && !hasFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add content, change progress, or attach files'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await ProgressUpdateService.createProgressUpdate(
      wishId: _currentWish.id,
      content: contentToSend,
      progressValue: _progressValue,
      files: _selectedFiles.isNotEmpty ? _selectedFiles : null,
    );

    if (mounted) Navigator.pop(context);

    // Clear form data regardless of success
    _updateController.clear();
    final savedProgressValue = _progressValue;
    setState(() {
      _selectedFiles.clear();
      _progressValue = null;
    });

    if (success) {
      // Update the local wish progress if a new value was set
      if (savedProgressValue != null && mounted) {
        setState(() {
          _currentWish = Wish(
            id: _currentWish.id,
            userId: _currentWish.userId,
            title: _currentWish.title,
            description: _currentWish.description,
            progress: savedProgressValue,
            isCompleted: savedProgressValue >= 100,
            status: savedProgressValue >= 100 ? 'completed' : _currentWish.status,
            createdAt: _currentWish.createdAt,
            targetDate: _currentWish.targetDate,
            consequence: _currentWish.consequence,
            coverImage: _currentWish.coverImage,
          );
        });
        print('[GoalDetailScreen] Updated local wish progress to $savedProgressValue%');
      }
      
      // Refresh the progress updates immediately
      await _loadProgressUpdates();
      
      // Pop back to refresh the goals list if completed
      final finalProgress = savedProgressValue ?? _currentWish.progress;
      if (finalProgress >= 100 && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(finalProgress >= 100 ? 'Goal completed! 🎉' : 'Progress update added!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add update'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _markAsFailed() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Failed?'),
        content: const Text('Are you sure you want to mark this goal as failed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              
              // Call API to mark as failed
              final success = await WishService.markAsFailed(_currentWish.id);
              
              if (mounted) Navigator.pop(context); // Close loading dialog
              
              if (success && mounted) {
                // Add a progress update for history
                await ProgressUpdateService.createProgressUpdate(
                  wishId: _currentWish.id,
                  content: 'Goal marked as failed 😔',
                  progressValue: _currentWish.progress,
                  files: null,
                );
                
                await _loadProgressUpdates();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Goal marked as failed'),
                    backgroundColor: Colors.orange,
                  ),
                );
                
                // Return to home and refresh
                Navigator.pop(context, true);
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to mark goal as failed'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Mark as Failed'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal Details'),
        actions: [
          if (_currentWish.status == 'current')
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'fail') {
                  _markAsFailed();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'fail',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Mark as Failed'),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProgressUpdates,
          ),
        ],
      ),
      body: Column(
        children: [
          // Goal Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentWish.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_currentWish.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _currentWish.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
                // Consequence
                if (_currentWish.consequence != null && _currentWish.consequence!.isNotEmpty) ...[
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
                                _currentWish.consequence!,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: _currentWish.progress / 100,
                                    backgroundColor: Colors.grey[300],
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_currentWish.progress}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_currentWish.consequence != null && _currentWish.consequence!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Consequence if not completed:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentWish.consequence!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Progress Updates Timeline
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _progressUpdates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timeline_rounded,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No progress updates yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share your progress below',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProgressUpdates,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _progressUpdates.length,
                          itemBuilder: (context, index) {
                            final update = _progressUpdates[index];
                            final isFirst = index == 0;
                            final isLast = index == _progressUpdates.length - 1;

                            return _ProgressUpdateCard(
                              update: update,
                              isFirst: isFirst,
                              isLast: isLast,
                            );
                          },
                        ),
                      ),
          ),

          // Add Update Button (only for goal owner)
          if (_isOwner)
            Container(
              padding: const EdgeInsets.all(16),
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
              child: ElevatedButton.icon(
                onPressed: _showAddUpdateDialog,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Add Progress Update', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressUpdateCard extends StatelessWidget {
  final Map<String, dynamic> update;
  final bool isFirst;
  final bool isLast;

  const _ProgressUpdateCard({
    required this.update,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.parse(update['created_at']);
    final timeAgo = _getTimeAgo(createdAt);
    final hasImage = update['image_url'] != null && update['image_url'].toString().isNotEmpty;
    final List<dynamic> attachments = update['attachments'] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline indicator with line
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  // Circle indicator
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isFirst
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[400],
                      shape: BoxShape.circle,
                      boxShadow: isFirst ? [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ] : null,
                    ),
                    child: Icon(
                      isFirst ? Icons.auto_awesome_rounded : Icons.circle,
                      color: Colors.white,
                      size: isFirst ? 20 : 12,
                    ),
                  ),
                  // Connecting line
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 3,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              isFirst 
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[400]!,
                              Colors.grey[300]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Update content
            Expanded(
              child: Card(
                elevation: isFirst ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isFirst 
                      ? BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), width: 2)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: isFirst ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          if (update['progress_value'] != null) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${update['progress_value']}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        update['content'],
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: isFirst ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      if (hasImage) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            'http://10.0.2.2:8000${update['image_url']}',
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading image: $error');
                              return Container(
                                height: 150,
                                color: Colors.grey[200],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image_rounded, color: Colors.grey[400], size: 48),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Failed to load image',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                color: Colors.grey[100],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      // Display attachments
                      if (attachments.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.attach_file_rounded, size: 16, color: Colors.grey[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${attachments.length} Attachment${attachments.length > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...attachments.map((attachment) {
                                final String fileName = attachment['file_name'];
                                final String filePath = attachment['file_path'];
                                final String fileType = attachment['file_type'] ?? 'application/octet-stream';
                                final int fileSize = attachment['file_size'] ?? 0;
                                final bool isLocal = attachment['is_local'] == true;
                                final String fullUrl = isLocal ? filePath : 'http://10.0.2.2:8000$filePath';
                                
                                IconData icon;
                                Color iconColor;
                                if (fileType.startsWith('image/')) {
                                  icon = Icons.image_rounded;
                                  iconColor = Colors.blue;
                                } else if (fileType == 'application/pdf') {
                                  icon = Icons.picture_as_pdf_rounded;
                                  iconColor = Colors.red;
                                } else if (fileType.contains('spreadsheet') || fileType.contains('excel')) {
                                  icon = Icons.table_chart_rounded;
                                  iconColor = Colors.green;
                                } else if (fileType.contains('presentation') || fileType.contains('powerpoint')) {
                                  icon = Icons.slideshow_rounded;
                                  iconColor = Colors.orange;
                                } else if (fileType.contains('word') || fileType.contains('document')) {
                                  icon = Icons.description_rounded;
                                  iconColor = Colors.blue[700]!;
                                } else {
                                  icon = Icons.insert_drive_file_rounded;
                                  iconColor = Colors.grey[700]!;
                                }

                                String formatFileSize(int bytes) {
                                  if (bytes < 1024) return '$bytes B';
                                  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
                                  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: InkWell(
                                    onTap: () {
                                      if (fileType.startsWith('image/')) {
                                        // Show image in full screen
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => _FullScreenImage(
                                              imageUrl: fullUrl,
                                              fileName: fileName,
                                              isLocal: isLocal,
                                            ),
                                          ),
                                        );
                                      } else {
                                        // For non-image files, show info dialog
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('File Preview'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('File: $fileName'),
                                                const SizedBox(height: 8),
                                                Text('Type: $fileType'),
                                                const SizedBox(height: 8),
                                                Text('Size: ${formatFileSize(fileSize)}'),
                                                const SizedBox(height: 16),
                                                const Text(
                                                  'Note: File downloads are not yet supported on the emulator. Files will be accessible when deploying to a real device.',
                                                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: iconColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(icon, color: iconColor, size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fileName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  formatFileSize(fileSize),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.download_rounded, color: Colors.grey[600], size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

// Full-screen image viewer
class _FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String fileName;
  final bool isLocal;

  const _FullScreenImage({
    required this.imageUrl,
    required this.fileName,
    this.isLocal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: isLocal
              ? Image.file(
                  File(imageUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load local image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / 
                              loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

