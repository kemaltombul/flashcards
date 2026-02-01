import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/collection.dart';

class RenameCollectionDialog extends StatefulWidget {
  final Collection collection;
  const RenameCollectionDialog({super.key, required this.collection});

  @override
  State<RenameCollectionDialog> createState() => _RenameCollectionDialogState();
}

class _RenameCollectionDialogState extends State<RenameCollectionDialog> {
  final FirestoreService _dbService = FirestoreService();
  late TextEditingController _controller;

  // Colors
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _accentColor = const Color(0xFFBB86FC);
  final TextStyle _textStyle = const TextStyle(
    fontFamily: 'Roboto',
    color: Colors.white,
    letterSpacing: 0.5,
  );

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.collection.name);
  }

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
      title: Text("Rename Collection",
          style: _textStyle.copyWith(
              color: _accentColor, fontSize: 20, fontWeight: FontWeight.bold)),
      content: TextField(
        controller: _controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Enter new name",
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          filled: true,
          fillColor: Colors.black12,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel",
                style: _textStyle.copyWith(color: Colors.grey.shade400))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            if (_controller.text.isNotEmpty &&
                _controller.text != widget.collection.name) {
              await _dbService.updateCollectionName(
                  widget.collection.id!, _controller.text);
              if (mounted) {
                Navigator.pop(context);
              }
            }
          },
          child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
