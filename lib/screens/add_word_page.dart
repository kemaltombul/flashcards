import 'dart:convert';
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
  bool _isManualMode = true;
  final _wordController = TextEditingController();
  final _defController = TextEditingController();
  final _trController = TextEditingController();

  final _exController = TextEditingController();
  final _jsonController = TextEditingController(); 
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
        foregroundColor: Colors.white,
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
            const SizedBox(height: 5),
            const Text("Choose input method below.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // Mode Toggle Buttons
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isManualMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isManualMode ? Colors.deepPurple : Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Center(
                          child: Text("Manual Entry", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isManualMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isManualMode ? Colors.deepPurple : Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Center(
                          child: Text("JSON Import", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            if (_isManualMode) ...[
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
            ),
            ] else ...[
             // JSON Import Section
            const Text(
              "Bulk Import (JSON)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
            ),
            const SizedBox(height: 10),
            const Text(
              "Paste a JSON array of words below.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
             const SizedBox(height: 10),
            _buildModernTextField(
              controller: _jsonController, 
              label: "Paste JSON Here", 
              icon: Icons.data_array, 
              maxLines: 10
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C2C2C),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.deepPurple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _importJson,
                icon: const Icon(Icons.download),
                label: const Text("IMPORT JSON", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            ],
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
              color: const Color(0xFF1E1E1E), // Dark card color
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.grey.shade800, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
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
        color: const Color(0xFF2C2C2C), // Dark input background
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white), // Explicit white text
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade400),
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


  /// Parses JSON and imports words with deduplication.
  Future<void> _importJson() async {
    String jsonString = _jsonController.text.trim();
    if (jsonString.isEmpty) return;

    try {
      // Clean up potential formatting issues (basic)
      if (!jsonString.startsWith('[') && !jsonString.endsWith(']')) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid JSON: Must be a list [...]"), backgroundColor: Colors.red),
        );
        return;
      }

      List<dynamic> data = jsonDecode(jsonString);
      
      var stats = await _dbService.importWordsWithDeduplication(widget.collectionId, data);
      
      int imported = stats['inserted'] ?? 0;
      int skipped = stats['skipped'] ?? 0;

      if (mounted) {
        String message = "Imported $imported words.";
        if (skipped > 0) {
          message += " $skipped duplicates skipped.";
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message), 
            backgroundColor: imported > 0 ? Colors.green : Colors.orange
          ),
        );

        if (imported > 0) {
          _jsonController.clear();
        }
      }

    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("JSON Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}