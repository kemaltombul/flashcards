import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/collection.dart';
import '../models/word.dart';

/// Page for managing a specific collection (Edit Words, Toggle Game Mode).
class CollectionSettingsPage extends StatefulWidget {
  final Collection collection;

  const CollectionSettingsPage({super.key, required this.collection});

  @override
  State<CollectionSettingsPage> createState() => _CollectionSettingsPageState();
}

class _CollectionSettingsPageState extends State<CollectionSettingsPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Word> _words = [];
  late bool _isGameMode; 

  @override
  void initState() {
    super.initState();
    _isGameMode = widget.collection.isGame; 
    _loadWords();
  }

  /// Loads words for the current collection.
  void _loadWords() async {
    final data = await _dbService.getWordsByCollection(widget.collection.id!);
    setState(() {
      _words = data;
    });
  }

  // Edit Word Dialog
  /// Shows a dialog to edit an existing word.
  void _showEditWordDialog(Word word) {
    final wordCtrl = TextEditingController(text: word.word);
    final defCtrl = TextEditingController(text: word.definition);
    final trCtrl = TextEditingController(text: word.meaningTr);
    final exCtrl = TextEditingController(text: word.example);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Edit Word", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildInput(wordCtrl, "Word"),
              const SizedBox(height: 10),
              _buildInput(defCtrl, "Definition"),
              const SizedBox(height: 10),
              _buildInput(trCtrl, "Meaning (TR)"),
              const SizedBox(height: 10),
              _buildInput(exCtrl, "Example"),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () async {
              await _dbService.updateWord(Word(
                id: word.id, 
                collectionId: word.collectionId,
                word: wordCtrl.text,
                definition: defCtrl.text,
                meaningTr: trCtrl.text,
                example: exCtrl.text,
              ));
              _loadWords();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Builds a text input field for the dialog.
  Widget _buildInput(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black12,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.collection.name, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Settings (Game Mode)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(15),
            ),
            child: SwitchListTile(
              title: const Text("Game Mode", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(
                _isGameMode ? "Status: Timer ON, Hidden" : "Status: Study Mode (Visible)",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              value: _isGameMode,
              activeTrackColor: const Color(0xFFBB86FC),
              onChanged: (val) async {
                setState(() {
                  _isGameMode = val;
                });
                await _dbService.updateCollectionMode(widget.collection.id!, val);
              },
            ),
          ),

          const Divider(color: Colors.white24),

          // Word List
          Expanded(
            child: _words.isEmpty
                ? const Center(child: Text("No words yet.", style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: _words.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final word = _words[index];
                      return Card(
                        color: const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(word.word, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(word.meaningTr, style: const TextStyle(color: Colors.white70)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                onPressed: () => _showEditWordDialog(word),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () async {
                                  await _dbService.deleteWord(word.id!);
                                  _loadWords();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}