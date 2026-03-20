import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class AddCollectionDialog extends StatefulWidget {
  const AddCollectionDialog({super.key});

  @override
  State<AddCollectionDialog> createState() => _AddCollectionDialogState();
}

class _AddCollectionDialogState extends State<AddCollectionDialog> {
  final FirestoreService _dbService = FirestoreService();
  final TextEditingController _controller = TextEditingController();
  String _selectedContextType = 'Academy';

  // Colors
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _accentColor = const Color(0xFFD0BCFF); // Light Purple Accent
  final TextStyle _textStyle = const TextStyle(
    fontFamily: 'Roboto',
    color: Colors.white,
    letterSpacing: 0.5,
  );

  final List<Map<String, dynamic>> _modes = [
    {'id': 'Academy', 'icon': Icons.school_outlined, 'label': 'Academy'},
    {'id': 'Cinema', 'icon': Icons.movie_outlined, 'label': 'Cinema'},
    {'id': 'Practical', 'icon': Icons.chat_bubble_outline, 'label': 'Practical'},
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        "New Collection",
        style: _textStyle.copyWith(
          color: _accentColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Ex: A1 Verbs",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "AI Context Mode",
              style: _textStyle.copyWith(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
              // Unified Mode Switcher (Stabilized & Responsive)
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: _modes.map((mode) {
                    final bool isSelected = _selectedContextType == mode['id'];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _selectedContextType = mode['id'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _accentColor.withOpacity(0.9)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      mode['icon'] as IconData,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.white60,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      mode['label'] as String,
                                      style: _textStyle.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500, // Fixed weight prevents jumping
                                        color: isSelected
                                            ? Colors.black
                                            : Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Cancel",
            style: _textStyle.copyWith(color: Colors.grey.shade400),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () async {
            if (_controller.text.isNotEmpty) {
              await _dbService.createCollection(
                _controller.text, 
                false, 
                contextType: _selectedContextType
              );
              if (mounted) {
                Navigator.pop(context);
              }
            }
          },
          child: const Text(
            "Create",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
