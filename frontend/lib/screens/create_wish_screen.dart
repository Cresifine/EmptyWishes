import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/wish_service.dart';
import '../services/tag_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateWishScreen extends StatefulWidget {
  const CreateWishScreen({super.key});

  @override
  State<CreateWishScreen> createState() => _CreateWishScreenState();
}

class _CreateWishScreenState extends State<CreateWishScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _consequenceController = TextEditingController();
  final _tagController = TextEditingController();
  DateTime? _targetDate;
  File? _coverImage;
  final ImagePicker _picker = ImagePicker();
  final List<String> _selectedTags = [];
  List<Map<String, dynamic>> _suggestedTags = [];
  List<Map<String, dynamic>> _popularTags = [];
  bool _useMilestones = false;
  final List<Map<String, String>> _milestones = [];
  String _visibility = 'public'; // 'public', 'private', 'followers', 'friends'
  bool _requiresVerification = false;
  final List<Map<String, dynamic>> _selectedVerifiers = [];
  List<Map<String, dynamic>> _suggestedVerifiers = [];
  final _verifierSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPopularTags();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _consequenceController.dispose();
    _tagController.dispose();
    _verifierSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadPopularTags() async {
    final tags = await TagService.getPopularTags(limit: 10);
    if (mounted) {
      setState(() {
        _popularTags = tags;
      });
    }
  }

  Future<void> _searchTags(String query) async {
    if (query.length < 2) {
      setState(() => _suggestedTags = []);
      return;
    }
    
    final tags = await TagService.searchTags(query);
    if (mounted) {
      setState(() {
        _suggestedTags = tags;
      });
    }
  }

  void _addTag(String tagName) {
    final normalized = tagName.trim().toLowerCase();
    if (normalized.isNotEmpty && !_selectedTags.contains(normalized)) {
      setState(() {
        _selectedTags.add(normalized);
        _tagController.clear();
        _suggestedTags = [];
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
  }

  Future<void> _searchVerifiers(String query) async {
    if (query.length < 2) {
      setState(() => _suggestedVerifiers = []);
      return;
    }
    
    try {
      final token = await StorageService.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/users/search?q=$query'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> users = json.decode(response.body);
        if (mounted) {
          setState(() {
            _suggestedVerifiers = users.map((u) => {
              'id': u['id'],
              'username': u['username'],
              'email': u['email'],
            }).toList();
          });
        }
      }
    } catch (e) {
      print('Error searching verifiers: $e');
    }
  }

  void _addVerifier(Map<String, dynamic> user) {
    if (_selectedVerifiers.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 10 verifiers allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_selectedVerifiers.any((v) => v['id'] == user['id'])) {
      setState(() {
        _selectedVerifiers.add(user);
        _verifierSearchController.clear();
        _suggestedVerifiers = [];
      });
    }
  }

  void _removeVerifier(Map<String, dynamic> user) {
    setState(() {
      _selectedVerifiers.removeWhere((v) => v['id'] == user['id']);
    });
  }

  Future<void> _pickCoverImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _coverImage = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
      });
    }
  }

  void _addMilestone() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final pointsController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Milestone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Milestone Title',
                hintText: 'e.g., Complete first chapter',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Add details...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pointsController,
              decoration: const InputDecoration(
                labelText: 'Points (Weight)',
                hintText: 'How valuable is this milestone?',
                prefixIcon: Icon(Icons.star),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                final points = int.tryParse(pointsController.text.trim()) ?? 1;
                setState(() {
                  _milestones.add({
                    'title': titleController.text.trim(),
                    'description': descController.text.trim(),
                    'points': points.toString(),
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editMilestone(int index) {
    final milestone = _milestones[index];
    final titleController = TextEditingController(text: milestone['title']);
    final descController = TextEditingController(text: milestone['description']);
    final pointsController = TextEditingController(text: milestone['points']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Milestone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Milestone Title',
                hintText: 'e.g., Complete first chapter',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Add details...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pointsController,
              decoration: const InputDecoration(
                labelText: 'Points (Weight)',
                hintText: 'How valuable is this milestone?',
                prefixIcon: Icon(Icons.star),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                final points = int.tryParse(pointsController.text.trim()) ?? 1;
                setState(() {
                  _milestones[index] = {
                    'title': titleController.text.trim(),
                    'description': descController.text.trim(),
                    'points': points.toString(),
                  };
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _removeMilestone(int index) {
    setState(() {
      _milestones.removeAt(index);
    });
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final success = await WishService.createWish(
        title: _titleController.text,
        description: _descriptionController.text ?? '',
        targetDate: _targetDate,
        consequence: _consequenceController.text.isEmpty ? null : _consequenceController.text,
        coverImage: _coverImage,
        tags: _selectedTags,
        useMilestones: _useMilestones,
        milestones: _useMilestones ? _milestones : null,
        visibility: _visibility,
        verifierIds: _requiresVerification && _selectedVerifiers.isNotEmpty
            ? _selectedVerifiers.map((v) => v['id'] as int).toList()
            : null,
      );

      if (mounted) Navigator.pop(context); // Close loading

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Goal created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _titleController.clear();
          _descriptionController.clear();
          _consequenceController.clear();
          _tagController.clear();
          setState(() {
            _targetDate = null;
            _coverImage = null;
            _selectedTags.clear();
            _useMilestones = false;
            _milestones.clear();
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create goal. Try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Goal'),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          hintText: 'What do you wish to achieve?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.auto_awesome_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe your wish in detail',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.description_rounded),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _consequenceController,
                        decoration: InputDecoration(
                          labelText: 'Consequence (Optional)',
                          hintText: 'What happens if you don\'t complete this?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.warning_amber_rounded),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      // Tags Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _tagController,
                            decoration: InputDecoration(
                              labelText: 'Tags',
                              hintText: 'Add tags (e.g., fitness, study)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.label_rounded),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add_rounded),
                                onPressed: () {
                                  if (_tagController.text.isNotEmpty) {
                                    _addTag(_tagController.text);
                                  }
                                },
                              ),
                            ),
                            onChanged: _searchTags,
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                _addTag(value);
                              }
                            },
                          ),
                          // Tag suggestions
                          if (_suggestedTags.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _suggestedTags.map((tag) {
                                  return InkWell(
                                    onTap: () => _addTag(tag['name']),
                                    child: Chip(
                                      label: Text(tag['name']),
                                      avatar: const Icon(Icons.add, size: 16),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          // Selected tags
                          if (_selectedTags.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedTags.map((tag) {
                                  return Chip(
                                    label: Text(tag),
                                    deleteIcon: const Icon(Icons.close, size: 16),
                                    onDeleted: () => _removeTag(tag),
                                  );
                                }).toList(),
                              ),
                            ),
                          // Popular tags
                          if (_popularTags.isNotEmpty && _selectedTags.isEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Popular tags:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _popularTags.map((tag) {
                                      return InkWell(
                                        onTap: () => _addTag(tag['name']),
                                        child: Chip(
                                          label: Text(tag['name']),
                                          labelStyle: const TextStyle(fontSize: 12),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Privacy/Visibility Settings
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.visibility, size: 20, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text(
                                  'Who can see this goal?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _visibility,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'public',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.public, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Public',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'followers',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.people, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Followers - Only my followers',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'friends',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.group, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Friends',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'private',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Private',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _visibility = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Milestones Option
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _useMilestones ? Colors.blue : Colors.grey[300]!,
                            width: _useMilestones ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: _useMilestones ? Colors.blue.withOpacity(0.05) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _useMilestones,
                                  onChanged: (value) {
                                    setState(() {
                                      _useMilestones = value ?? false;
                                      if (!_useMilestones) {
                                        _milestones.clear();
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.auto_awesome,
                                            size: 16,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Advanced: Track with Milestones',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Break your goal into checkpoints that auto-calculate progress',
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
                            if (_useMilestones) ...[
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'Milestones',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _addMilestone,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add Milestone'),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                              if (_milestones.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      'Break your goal into smaller milestones',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ...List.generate(_milestones.length, (index) {
                                  final milestone = _milestones[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.blue.withOpacity(0.2),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              milestone['title']!,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.star, size: 12, color: Colors.amber),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${milestone['points'] ?? '1'}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.amber,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: milestone['description']!.isNotEmpty
                                          ? Text(
                                              milestone['description']!,
                                              style: const TextStyle(fontSize: 12),
                                            )
                                          : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            onPressed: () => _editMilestone(index),
                                            color: Colors.blue,
                                            tooltip: 'Edit',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20),
                                            onPressed: () => _removeMilestone(index),
                                            color: Colors.red,
                                            tooltip: 'Delete',
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _selectDate(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _targetDate == null
                                      ? 'Set Target Date (Optional)'
                                      : 'Target: ${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}',
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Cover Image Section
                      if (_coverImage != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _coverImage!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _coverImage = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _pickCoverImage,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Add Cover Image (Optional)'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Verification Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Goal Verification',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select trusted people to verify when you complete this goal',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Require verification'),
                        subtitle: const Text('Others must approve goal completion'),
                        value: _requiresVerification,
                        onChanged: (value) {
                          setState(() {
                            _requiresVerification = value;
                            if (!value) {
                              _selectedVerifiers.clear();
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_requiresVerification) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _verifierSearchController,
                          decoration: InputDecoration(
                            labelText: 'Search for verifiers',
                            hintText: 'Enter username or email',
                            prefixIcon: const Icon(Icons.person_search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: _verifierSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _verifierSearchController.clear();
                                      setState(() => _suggestedVerifiers = []);
                                    },
                                  )
                                : null,
                          ),
                          onChanged: _searchVerifiers,
                        ),
                        // Verifier suggestions
                        if (_suggestedVerifiers.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _suggestedVerifiers.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final user = _suggestedVerifiers[index];
                                final alreadySelected = _selectedVerifiers.any((v) => v['id'] == user['id']);
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    child: Text(
                                      user['username'][0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(user['username']),
                                  subtitle: Text(user['email'] ?? ''),
                                  trailing: alreadySelected
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : const Icon(Icons.add_circle_outline, color: Colors.blue),
                                  onTap: alreadySelected ? null : () => _addVerifier(user),
                                  dense: true,
                                );
                              },
                            ),
                          ),
                        // Selected verifiers
                        if (_selectedVerifiers.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Selected Verifiers (${_selectedVerifiers.length}/10)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedVerifiers.map((user) {
                              return Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Text(
                                    user['username'][0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                label: Text(user['username']),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () => _removeVerifier(user),
                                backgroundColor: Colors.blue.withOpacity(0.1),
                              );
                            }).toList(),
                          ),
                        ],
                        if (_selectedVerifiers.isEmpty && _requiresVerification)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Please select at least one verifier',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.orange[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Create Goal'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

