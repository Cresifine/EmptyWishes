import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/wish.dart';
import '../models/milestone.dart';
import '../services/progress_update_service.dart';
import '../services/wish_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/milestone_service.dart';
import '../services/verification_service.dart';
import '../services/feed_service.dart';

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
  bool _shouldUpdateProgress = false; // Checkbox for progress update
  final ImagePicker _picker = ImagePicker();
  late Wish _currentWish; // Track the current wish state
  int? _currentUserId; // Track the current logged-in user's ID
  bool _isOwner = false; // Whether the current user owns this goal
  List<Milestone> _milestones = [];
  final MilestoneService _milestoneService = MilestoneService();
  List<Map<String, dynamic>> _verifications = [];
  bool _isLoadingVerifications = false;
  String? _ownerDisputeResponse; // Owner's response to disputes
  
  // Engagement data
  int _viewsCount = 0;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _isLiked = false;
  bool _isLoadingEngagement = false;
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _currentWish = widget.wish; // Initialize with the passed wish
    _checkOwnership();
    _loadProgressUpdates();
    _loadMilestones();
    _loadVerifications();
    _loadEngagementData();
    _loadComments();
    FeedService.recordView(_currentWish.id); // Record view
  }

  Future<void> _checkOwnership() async {
    try {
      final isOfflineMode = await StorageService.isOfflineMode();
      final currentUser = await AuthService.getCurrentUser();
      
      print('[GoalDetailScreen] Checking ownership - Offline: $isOfflineMode, Current user: $currentUser, Wish owner: ${_currentWish.userId}');
      
      if (mounted) {
        setState(() {
          // If offline mode, user owns all wishes they can access
          if (isOfflineMode) {
            _isOwner = true;
            _currentUserId = _currentWish.userId; // Set to wish owner ID in offline mode
            print('[GoalDetailScreen] Offline mode - user owns this goal');
          } else if (currentUser != null) {
            _currentUserId = currentUser['id'];
            _isOwner = (_currentUserId == _currentWish.userId);
            
            print('[GoalDetailScreen] Current user ID: $_currentUserId, Goal owner ID: ${_currentWish.userId}, Is owner: $_isOwner');
          } else {
            _isOwner = false;
            print('[GoalDetailScreen] No current user - not owner');
          }
        });
      }
    } catch (e) {
      print('[GoalDetailScreen] Error checking ownership: $e');
      if (mounted) {
        setState(() {
          _isOwner = false; // Don't assume ownership on error
        });
      }
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

  Future<void> _loadMilestones() async {
    print('[GoalDetailScreen] Loading milestones for wish ${_currentWish.id}');
    final milestones = await _milestoneService.getWishMilestones(_currentWish.id);
    print('[GoalDetailScreen] Loaded ${milestones.length} milestones');
    
    if (mounted) {
      setState(() {
        _milestones = milestones;
      });
    }
  }

  Future<void> _loadVerifications() async {
    if (!_currentWish.requiresVerification) return;
    
    setState(() => _isLoadingVerifications = true);
    
    final response = await VerificationService.getVerifications(_currentWish.id);
    
    if (mounted) {
      setState(() {
        _verifications = response['verifications'] ?? [];
        _ownerDisputeResponse = response['owner_dispute_response'];
        _isLoadingVerifications = false;
      });
      
      // Debug: Log verification details
      print('[GoalDetailScreen] Loaded ${_verifications.length} verifications');
      for (var v in _verifications) {
        print('[GoalDetailScreen] Verification: ${v['verifier']['username']} - ${v['status']} - dispute_reason: ${v['dispute_reason']} - comment: ${v['comment']}');
      }
      if (_ownerDisputeResponse != null) {
        print('[GoalDetailScreen] Owner response: $_ownerDisputeResponse');
      }
    }
  }

  Future<void> _loadEngagementData() async {
    setState(() => _isLoadingEngagement = true);
    
    try {
      final response = await FeedService.getEngagementStats(_currentWish.id);
      if (mounted && response != null) {
        setState(() {
          _viewsCount = response['views_count'] ?? 0;
          _likesCount = response['likes_count'] ?? 0;
          _commentsCount = response['comments_count'] ?? 0;
          _isLiked = response['is_liked'] ?? false;
          _isLoadingEngagement = false;
        });
      }
    } catch (e) {
      print('[GoalDetailScreen] Error loading engagement: $e');
      if (mounted) {
        setState(() => _isLoadingEngagement = false);
      }
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await FeedService.getComments(_currentWish.id);
      if (mounted) {
        setState(() {
          _comments = comments;
        });
      }
    } catch (e) {
      print('[GoalDetailScreen] Error loading comments: $e');
    }
  }

  Future<void> _handleLike() async {
    final result = await FeedService.toggleLike(_currentWish.id);
    if (result != null && mounted) {
      setState(() {
        _isLiked = result['liked'];
        _likesCount = result['liked'] ? _likesCount + 1 : _likesCount - 1;
      });
    }
  }

  Future<void> _handleAddComment(String content) async {
    if (content.trim().isEmpty) return;
    
    final success = await FeedService.addComment(_currentWish.id, content);
    if (success && mounted) {
      await _loadComments();
      await _loadEngagementData(); // Refresh counts
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleVerification(bool approved) async{
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

      final success = await VerificationService.verifyCompletion(
        wishId: _currentWish.id,
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

  Future<void> _handleRespondToDispute() async {
    final TextEditingController responseController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Respond to Dispute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Address the concerns raised by the verifiers. Explain what you\'ve done or provide additional proof.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              decoration: const InputDecoration(
                labelText: 'Your response',
                hintText: 'Explain or provide additional proof...',
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
            child: const Text('Send Response'),
          ),
        ],
      ),
    );

    if (result == true && responseController.text.trim().isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final success = await VerificationService.respondToDispute(
        wishId: _currentWish.id,
        responseText: responseController.text.trim(),
      );

      if (mounted) Navigator.pop(context); // Close loading

      if (success) {
        await _loadVerifications(); // Reload to show the owner's response
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Response sent to verifiers!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send response'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleReRequestVerification() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-request Verification'),
        content: const Text(
          'This will reset all disputed verifications back to pending status. '
          'Verifiers will be notified to review your goal again. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Re-request'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final success = await VerificationService.reRequestVerification(
        wishId: _currentWish.id,
      );

      if (mounted) Navigator.pop(context); // Close loading

      if (success) {
        await _loadVerifications();
        await _refreshWishData(); // Reload wish to update completion_status
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification re-requested! Verifiers have been notified.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to re-request verification'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _refreshWishData() async{
    print('[GoalDetailScreen] Refreshing wish data for ID: ${_currentWish.id}');
    try {
      // Fetch all wishes to find the updated one (might have changed status)
      final statuses = ['current', 'completed', 'failed', 'missed', 'archived'];
      for (final status in statuses) {
        final wishes = await WishService.getWishesByStatus(status);
        try {
          final refreshedWish = wishes.firstWhere((w) => w.id == _currentWish.id);
          if (mounted) {
            setState(() {
              _currentWish = refreshedWish;
            });
          }
          print('[GoalDetailScreen] Wish refreshed with progress: ${refreshedWish.progress}%');
          return;
        } catch (e) {
          // Not found in this status, try next
          continue;
        }
      }
      print('[GoalDetailScreen] WARNING: Could not find wish ${_currentWish.id} in any status');
    } catch (e) {
      print('[GoalDetailScreen] Error refreshing wish data: $e');
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
                      // Only show progress slider if NOT using milestone mode
                      if (_currentWish.progressMode != 'milestone') ...[
                        // Checkbox to enable progress update
                        CheckboxListTile(
                          value: _shouldUpdateProgress,
                          onChanged: (value) {
                            setModalState(() {
                              setState(() {
                                _shouldUpdateProgress = value ?? false;
                                if (!_shouldUpdateProgress) {
                                  _progressValue = _currentWish.progress; // Reset to current
                                }
                              });
                            });
                          },
                          title: const Text(
                            'Update Progress',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            'Current: ${_currentWish.progress}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        // Show slider only if checkbox is checked
                        if (_shouldUpdateProgress) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Spacer(),
                              Text(
                                '${_progressValue ?? _currentWish.progress}%',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: (_progressValue != null && _progressValue != _currentWish.progress)
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: (_progressValue ?? _currentWish.progress).toDouble(),
                            min: _currentWish.progress.toDouble(), // Can't go below current progress
                            max: 100,
                            divisions: ((100 - _currentWish.progress) ~/ 5).clamp(1, 100), // Ensure divisions is at least 1
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
                          const SizedBox(height: 8),
                          // Quick increment buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildQuickIncrementButton(context, setModalState, '+5%', 5),
                              _buildQuickIncrementButton(context, setModalState, '+10%', 10),
                              _buildQuickIncrementButton(context, setModalState, '+25%', 25),
                              _buildQuickIncrementButton(context, setModalState, '+50%', 50),
                            ],
                          ),
                        ],
                      ],
                      // Show message for milestone mode
                      if (_currentWish.progressMode == 'milestone')
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '📊 Progress is tracked by completing milestones',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
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
    // Progress only changes if checkbox is checked AND value is different
    final hasProgressChange = _shouldUpdateProgress && 
                              _progressValue != null && 
                              _progressValue != _currentWish.progress;
    final hasFiles = _selectedFiles.isNotEmpty;
    
    final contentToSend = _updateController.text.trim();
    print('[GoalDetailScreen] hasContent: $hasContent, hasProgressChange: $hasProgressChange, shouldUpdateProgress: $_shouldUpdateProgress, hasFiles: $hasFiles, filesCount: ${_selectedFiles.length}');
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

    // Only send progress value if checkbox is checked AND value actually changed
    final progressToSend = hasProgressChange ? _progressValue : null;
    
    final success = await ProgressUpdateService.createProgressUpdate(
      wishId: _currentWish.id,
      content: contentToSend,
      progressValue: progressToSend,
      files: _selectedFiles.isNotEmpty ? _selectedFiles : null,
    );

    if (mounted) Navigator.pop(context);

    // Clear form data regardless of success
    _updateController.clear();
    final savedProgressValue = _progressValue;
    final progressWasActuallyUpdated = hasProgressChange; // Save before clearing
    setState(() {
      _selectedFiles.clear();
      _progressValue = null;
      _shouldUpdateProgress = false; // Reset checkbox
    });

    if (success) {
      // Update the local wish progress ONLY if progress was actually sent to backend
      if (progressWasActuallyUpdated && savedProgressValue != null && mounted) {
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
      
      // Pop back to refresh the goals list ONLY if progress was actually updated to 100%
      if (progressWasActuallyUpdated && savedProgressValue != null && savedProgressValue >= 100 && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              progressWasActuallyUpdated && savedProgressValue != null && savedProgressValue >= 100
                  ? 'Goal completed! 🎉'
                  : 'Progress update added!'
            ),
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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
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

          // Engagement Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                _buildStatBadge(Icons.visibility_rounded, _viewsCount, 'views'),
                const SizedBox(width: 16),
                _buildStatBadge(Icons.favorite_rounded, _likesCount, 'likes', color: Colors.red),
                const SizedBox(width: 16),
                _buildStatBadge(Icons.comment_rounded, _commentsCount, 'comments'),
              ],
            ),
          ),

          // Action Buttons (Like, Comment, Share)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  label: 'Like',
                  color: _isLiked ? Colors.red : null,
                  onPressed: _handleLike,
                ),
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  label: 'Comment',
                  onPressed: () {
                    // Scroll to comments section
                    // Will implement after adding comments section
                  },
                ),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share feature coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ),

          // Milestones Section
          if (_milestones.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  const SizedBox(height: 12),
                  ...List.generate(_milestones.length, (index) {
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
                                borderRadius: BorderRadius.circular(10),
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
                        trailing: _isOwner
                            ? Checkbox(
                                value: milestone.isCompleted,
                                onChanged: (value) async {
                                      if (value != null) {
                                        final updated = await _milestoneService
                                            .toggleMilestoneCompletion(milestone.id, value);
                                        if (updated != null) {
                                          _loadMilestones();
                                          // Force refresh the wish from backend to get updated progress
                                          await _refreshWishData();
                                        }
                                      }
                                    },
                                  )
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Verification Section
          if (_currentWish.requiresVerification)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user,
                        size: 20,
                        color: _currentWish.completionStatus == 'verified'
                            ? Colors.green
                            : _currentWish.completionStatus == 'disputed'
                                ? Colors.orange
                                : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Verification Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _currentWish.completionStatus == 'verified'
                              ? Colors.green.withOpacity(0.1)
                              : _currentWish.completionStatus == 'disputed'
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _currentWish.completionStatus == 'verified'
                              ? 'Verified'
                              : _currentWish.completionStatus == 'disputed'
                                  ? 'Disputed'
                                  : _currentWish.completionStatus == 'pending_verification'
                                      ? 'Pending'
                                      : 'Required',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _currentWish.completionStatus == 'verified'
                                ? Colors.green
                                : _currentWish.completionStatus == 'disputed'
                                    ? Colors.orange
                                    : Colors.blue,
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
                  // Owner's Response to Disputes (if any)
                  if (_ownerDisputeResponse != null && _ownerDisputeResponse!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.reply_rounded, size: 18, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Owner\'s Response',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _ownerDisputeResponse!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Debug logging
                  Builder(
                    builder: (context) {
                      final hasAnyDispute = _verifications.any((v) => v['status'] == 'disputed');
                      print('[GoalDetailScreen] Dispute UI check: completionStatus=${_currentWish.completionStatus}, hasAnyDispute=$hasAnyDispute, isOwner=$_isOwner, currentUserId=$_currentUserId, wishUserId=${_currentWish.userId}');
                      return const SizedBox.shrink();
                    },
                  ),
                  // Respond to Dispute & Re-request Verification Buttons (for owner when ANY verifier disputed)
                  if ((_isOwner || _currentUserId == _currentWish.userId) && _verifications.any((v) => v['status'] == 'disputed')) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Colors.orange[800]),
                              const SizedBox(width: 8),
                              Text(
                                'Action Required',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your goal has been disputed. Respond to the concerns or re-request verification.',
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _handleRespondToDispute,
                                  icon: const Icon(Icons.reply_rounded, size: 18),
                                  label: const Text('Respond'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _handleReRequestVerification,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Re-request'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Progress Updates Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                const SizedBox(height: 12),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
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
                    (index) => _ProgressUpdateCard(
                      update: _progressUpdates[index],
                      isFirst: index == 0,
                      isLast: index == _progressUpdates.length - 1,
                    ),
                  ),
              ],
            ),
          ),

          // Comments Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                const SizedBox(height: 12),
                if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to comment!',
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
            ),
          ),

                ],
              ),
            ),
          ),
          
          // Bottom Action Bar (Update button for owner, Comment input for everyone)
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
          
          // Comment Input (for everyone)
          Container(
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
                      controller: _updateController, // Reuse update controller for comments
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
                    onPressed: () {
                      if (_updateController.text.trim().isNotEmpty) {
                        _handleAddComment(_updateController.text.trim());
                        _updateController.clear();
                        FocusScope.of(context).unfocus();
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, int count, String label, {Color? color}) {
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color ?? Colors.grey[700],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildQuickIncrementButton(
    BuildContext context,
    StateSetter setModalState,
    String label,
    int increment,
  ) {
    final currentProgress = _progressValue ?? _currentWish.progress;
    final newProgress = (currentProgress + increment).clamp(0, 100);
    final isDisabled = newProgress > 100 || currentProgress >= 100;

    return OutlinedButton(
      onPressed: isDisabled
          ? null
          : () {
              setModalState(() {
                setState(() {
                  _progressValue = newProgress;
                });
              });
            },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        side: BorderSide(
          color: isDisabled ? Colors.grey[300]! : Colors.blue,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDisabled ? Colors.grey[400] : Colors.blue,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
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
                  _formatTimeAgo(createdAt),
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _ProgressUpdateCard extends StatelessWidget{
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

