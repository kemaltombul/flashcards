import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/collection.dart';
import '../models/word.dart';

/// Page for managing a specific collection (Edit Words, Toggle Game Mode, Rename).
class CollectionSettingsPage extends StatefulWidget {
  final Collection collection;

  const CollectionSettingsPage({super.key, required this.collection});

  @override
  State<CollectionSettingsPage> createState() => _CollectionSettingsPageState();
}

class _CollectionSettingsPageState extends State<CollectionSettingsPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Word> _allWords = [];
  List<Word> _filteredWords = [];
  late bool _isGameMode; 
  
  // Sorting & Searching
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  Timer? _debounce;
  bool _isNameDirty = false; // Track if name has changed

  @override
  void initState() {
    super.initState();
    _isGameMode = widget.collection.isGame;
    _nameController.text = widget.collection.name;
    _loadWords();
    
    _searchController.addListener(_onSearchChanged);
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Debounce search logic.
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _filterWords(_searchController.text);
    });
  }

  /// Checks if name has changed from original.
  void _onNameChanged() {
    setState(() {
      _isNameDirty = _nameController.text != widget.collection.name;
    });
  }

  void _filterWords(String query) {
    if (query.isEmpty) {
      if (mounted) setState(() => _filteredWords = _allWords);
      return;
    }
    
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredWords = _allWords.where((word) {
        return word.word.toLowerCase().contains(lowerQuery) ||
               word.meaningTr.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  /// Loads words for the current collection.
  void _loadWords() async {
    final data = await _dbService.getWordsByCollection(widget.collection.id!);
    if (mounted) {
      setState(() {
        _allWords = data;
        _filteredWords = data;
      });
      // Re-apply filter if search is active
      if (_searchController.text.isNotEmpty) {
        _filterWords(_searchController.text);
      }
    }
  }

  /// Renames the collection.
  Future<void> _updateCollectionName() async {
    if (_nameController.text.isNotEmpty && _isNameDirty) {
      await _dbService.updateCollectionName(widget.collection.id!, _nameController.text);
      if (mounted) {
        setState(() {
          _isNameDirty = false;
        });
        FocusManager.instance.primaryFocus?.unfocus(); // Close keyboard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Name saved successfully!"), backgroundColor: Colors.green)
        );
      }
    }
  }

  // Edit Word Dialog (Same as before)
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
        title: const Text("Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Rename Collection
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: _isNameDirty ? "Unsaved Changes" : "Collection Name",
                      labelStyle: TextStyle(
                        color: _isNameDirty ? Colors.orangeAccent : Colors.deepPurpleAccent,
                        fontWeight: _isNameDirty ? FontWeight.bold : FontWeight.normal,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15), 
                        borderSide: _isNameDirty ? const BorderSide(color: Colors.orangeAccent, width: 2) : BorderSide.none
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: _isNameDirty ? const BorderSide(color: Colors.orangeAccent, width: 2) : BorderSide.none
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: _isNameDirty ? const BorderSide(color: Colors.orangeAccent, width: 2) : const BorderSide(color: Colors.deepPurpleAccent, width: 2)
                      ),
                      suffixIcon: _isNameDirty 
                        ? IconButton(
                            icon: const Icon(Icons.save, color: Colors.orangeAccent, size: 30),
                            onPressed: _updateCollectionName,
                            tooltip: "Save Name",
                          )
                        : const Icon(Icons.edit, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Game Mode Switch (Now scrolls)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: SwitchListTile(
                      title: const Text("Game Mode", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        _isGameMode ? "Meanings hidden" : "Meanings visible",
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
                  const SizedBox(height: 24),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search words...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          
          // Words List
          _filteredWords.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(_allWords.isEmpty ? "No words yet." : "No matches found.", style: const TextStyle(color: Colors.white54))),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final word = _filteredWords[index];
                        return Card(
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      childCount: _filteredWords.length,
                    ),
                  ),
                ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}