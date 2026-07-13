import 'package:flutter/material.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/singletons/prefs.dart';

/// Modal dialog allowing users to create new custom activity tags.
class TagCreateDialog extends StatefulWidget {
  const TagCreateDialog({super.key});

  @override
  State<TagCreateDialog> createState() => _TagCreateDialogState();
}

class _TagCreateDialogState extends State<TagCreateDialog> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedIcon = '💼';
  String _selectedColorHex = '#4285F4';

  final List<String> _emojiOptions = [
    '💻',
    '📞',
    '🧠',
    '📚',
    '🏋️',
    '📝',
    '😴',
    '💼',
    '🎨',
    '🛒',
    '🍳',
    '🚶',
    '✈️',
    '🎮',
    '✍️',
    '📈',
    '🧹',
    '🧘',
  ];

  final List<String> _colorOptions = [
    '#4285F4', // Blue
    '#34A853', // Green
    '#FBBC05', // Yellow
    '#EA4335', // Red
    '#AB47BC', // Purple
    '#00ACC1', // Cyan
    '#FF7043', // Deep Orange
    '#8D6E63', // Brown
    '#78909C', // Blue Grey
    '#E91E63', // Pink
  ];

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  Future<void> _saveTag() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a tag name')),
      );
      return;
    }

    final cleanName = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '_');
    final id = 'tag_custom_${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    final newTag = TrackerTag(
      id: id,
      name: name,
      icon: _selectedIcon,
      colorHex: _selectedColorHex,
    );

    await Prefs.saveTrackerTag(newTag);
    if (!mounted) return;
    Navigator.of(context).pop(newTag);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Create New Activity Tag'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tag Name',
                hintText: 'e.g., Client Work, Side Project',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Text(
              'Select Icon / Emoji',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojiOptions.map((emoji) {
                final isSelected = _selectedIcon == emoji;
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = emoji),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Color Badge',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorOptions.map((hex) {
                final color = _parseHexColor(hex);
                final isSelected = _selectedColorHex == hex;
                return InkWell(
                  onTap: () => setState(() => _selectedColorHex = hex),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveTag,
          child: const Text('Create Tag'),
        ),
      ],
    );
  }
}
