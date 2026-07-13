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
  final TextEditingController _customIconController = TextEditingController();
  String _selectedIcon = '💼';
  String _selectedColorHex = '#4285F4';

  final List<String> _emojiOptions = [
    // Work & Focus
    '💻', '📞', '🧠', '📚', '💼', '📝', '✍️', '📈', '📊', '🧑‍💻', '🎯', '🗂️',
    '📅', '💡', '🔍', '📋',
    // Health, Sleep & Fitness
    '😴', '🛌', '🏋️', '🧘', '🏃', '🚶', '🚴', '🏊', '⚽', '🎾', '🩺', '💊',
    '🥗', '🥦', '🧘‍♂️', '💪',
    // Home, Daily & Errands
    '🧹', '🍳', '🛒', '📦', '🧺', '🪴', '🔧', '🔨', '🏠', '🛁', '🚗', '🚇',
    '✈️', '🛎️', '💡', '💵',
    // Food & Drink
    '☕', '🫖', '🍽️', '🍔', '🍕', '🍱', '🥪', '🍰', '🍎', '🍓', '🥑', '🍷',
    '🍺', '🥤', '🍜', '☕',
    // Creative & Leisure
    '🎨', '🎮', '🎧', '🎸', '🎹', '🎬', '📺', '📷', '🎲', '🧩', '🎤', '🎪',
    '📖', '🧶', '🪴', '🏝️',
    // Status & Symbols
    '⭐', '🔥', '⚡', '🌟', '⚠️', '✅', '🚀', '🔮', '🎉', '🏆', '💎', '⌛', '⏰',
    '📌', '🛠️', '🧭',
  ];

  final List<String> _colorOptions = [
    '#4285F4',
    '#34A853',
    '#FBBC05',
    '#EA4335',
    '#AB47BC',
    '#00ACC1',
    '#FF7043',
    '#8D6E63',
    '#78909C',
    '#E91E63',
    '#5C6BC0',
    '#26A69A',
    '#D4E157',
    '#FFA726',
    '#EC407A',
    '#7E57C2',
    '#29B6F6',
    '#66BB6A',
    '#FFEE58',
    '#FF5722',
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

    final iconToUse = _customIconController.text.trim().isNotEmpty
        ? _customIconController.text.trim().characters.first
        : _selectedIcon;

    final cleanName = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '_');
    final id = 'tag_custom_${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    final newTag = TrackerTag(
      id: id,
      name: name,
      icon: iconToUse,
      colorHex: _selectedColorHex,
    );

    await Prefs.saveTrackerTag(newTag);
    if (!mounted) return;
    Navigator.of(context).pop(newTag);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customIconController.dispose();
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
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _emojiOptions.map((emoji) {
                    final isSelected = _selectedIcon == emoji &&
                        _customIconController.text.isEmpty;
                    return InkWell(
                      onTap: () => setState(() {
                        _selectedIcon = emoji;
                        _customIconController.clear();
                      }),
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
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customIconController,
              decoration: const InputDecoration(
                labelText: 'Or enter a custom emoji',
                hintText: 'Type or paste any single emoji (e.g. 🛸, 🤿, 🧪)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) {
                if (val.isNotEmpty) {
                  setState(() {});
                }
              },
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
