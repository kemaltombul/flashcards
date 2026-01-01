import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/word.dart';

/// Page for adding a new word to a specific collection.
class AddWordPage extends StatefulWidget {
  final int collectionId;
  const AddWordPage({super.key, required this.collectionId});

  @override
  State<AddWordPage> createState() => _AddWordPageState();
}

class _AddWordPageState extends State<AddWordPage> {
  final _wordController = TextEditingController();
  final _defController = TextEditingController();
  final _trController = TextEditingController();
  final _exController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    // Check if Mobile or Web
    bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    Widget content = Scaffold(
      appBar: AppBar(
        title: const Text("Add Word"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Learn a new word!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
            ),
            const SizedBox(height: 5),
            const Text("Enter details below.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            _buildModernTextField(controller: _wordController, label: "English Word", icon: Icons.translate),
            const SizedBox(height: 15),
            
            _buildModernTextField(controller: _defController, label: "English Definition", icon: Icons.menu_book),
            const SizedBox(height: 15),

            _buildModernTextField(controller: _trController, label: "Turkish Meaning", icon: Icons.language),
            const SizedBox(height: 15),

            _buildModernTextField(controller: _exController, label: "Example Sentence", icon: Icons.format_quote_rounded, maxLines: 2),
            const SizedBox(height: 30),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _saveWord,
                child: const Text("SAVE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );

    // Constrain layout for Web/Desktop
    if (isMobile) {
      return content;
    } else {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 800),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.grey.shade800, width: 6),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20)],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(34)),
              child: content,
            ),
          ),
        ),
      );
    }
  }

  // Modern TextField builder
  /// Builds a modern text field with an icon and label.
  Widget _buildModernTextField({required TextEditingController controller, required String label, required IconData icon, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.deepPurpleAccent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  // Save word and clear fields
  /// Validates input and saves the new word to the database.
  Future<void> _saveWord() async {
    if (_wordController.text.isNotEmpty && _trController.text.isNotEmpty) {
      await _dbService.insertWord(Word(
        collectionId: widget.collectionId,
        word: _wordController.text,
        definition: _defController.text,
        meaningTr: _trController.text,
        example: _exController.text,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Successfully Added!"), backgroundColor: Colors.green));
        _wordController.clear();
        _defController.clear();
        _trController.clear();
        _exController.clear();
      }
    }
  }
}