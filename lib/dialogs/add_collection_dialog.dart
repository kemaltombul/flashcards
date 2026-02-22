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
  bool _isGameMode = false;

  // Colors
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _accentColor = const Color(0xFFBB86FC);
  final TextStyle _textStyle = const TextStyle(
    fontFamily: 'Roboto',
    color: Colors.white,
    letterSpacing: 0.5,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "New Collection",
        style: _textStyle.copyWith(
          color: _accentColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Ex: A1 Verbs",
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: Colors.black12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: Text("Game Mode", style: _textStyle.copyWith(fontSize: 16)),
            subtitle: Text(
              _isGameMode
                  ? "Timer ON, Meaning Hidden"
                  : "Timer OFF, Show Meaning",
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            value: _isGameMode,
            activeTrackColor: _accentColor,
            onChanged: (val) {
              setState(() {
                _isGameMode = val;
              });
            },
          ),
        ],
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
              await _dbService.createCollection(_controller.text, _isGameMode);
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
