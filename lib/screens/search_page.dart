import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/word.dart';
import '../models/collection.dart';
import '../widgets/multi_select_dropdown.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<Word> _searchResults = [];
  List<Collection> _collections = [];
  List<int> _selectedCollectionIds = []; // Empty means "All Collections"
  bool _isLoading = false;
  bool _isSearchExpanded = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCollections();
    _performSearch(); // Load all words by default
  }

  Future<void> _loadCollections() async {
    final cols = await _dbService.getCollections();
    setState(() {
      _collections = cols;
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }



  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _dbService.searchWords(
        _searchController.text, 
        collectionIds: _selectedCollectionIds
      );
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteWord(Word word) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Delete Word", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete '${word.word}'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbService.deleteWord(word.id!);
      _performSearch(); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Word deleted"), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _editWord(Word word) async {
    final wordCtrl = TextEditingController(text: word.word);
    final defCtrl = TextEditingController(text: word.definition);
    final trCtrl = TextEditingController(text: word.meaningTr);
    final exCtrl = TextEditingController(text: word.example);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Edit Word", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEditField(wordCtrl, "Word", Icons.title),
              const SizedBox(height: 10),
              _buildEditField(defCtrl, "Definition", Icons.menu_book),
              const SizedBox(height: 10),
              _buildEditField(trCtrl, "Meaning (TR)", Icons.language),
              const SizedBox(height: 10),
              _buildEditField(exCtrl, "Example", Icons.format_quote),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () async {
              if (wordCtrl.text.isNotEmpty && trCtrl.text.isNotEmpty) {
                 Word updatedWord = Word(
                   id: word.id,
                   collectionId: word.collectionId,
                   word: wordCtrl.text,
                   definition: defCtrl.text,
                   meaningTr: trCtrl.text,
                   example: exCtrl.text
                 );
                 await _dbService.updateWord(updatedWord);
                 Navigator.pop(ctx);
                 _performSearch();
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(TextEditingController ctrl, String label, IconData icon) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: Colors.deepPurpleAccent, size: 20),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      ),
    );
  }

  void _showWordDetails(Word word) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50, height: 5,
                  decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(word.word, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent), onPressed: () { Navigator.pop(context); _editWord(word); }),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () { Navigator.pop(context); _deleteWord(word); }),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 5),
              Text(word.meaningTr, style: const TextStyle(fontSize: 22, color: Colors.deepPurpleAccent, fontStyle: FontStyle.italic)),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 20),
              if (word.definition.isNotEmpty) ...[
                _buildDetailRow(Icons.menu_book, "Definition", word.definition),
                const SizedBox(height: 20),
              ],
              if (word.example.isNotEmpty) ...[
                _buildDetailRow(Icons.format_quote_rounded, "Example", word.example),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 5), Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600))]),
        const SizedBox(height: 6),
        Text(content, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Search & Browse", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = !_isSearchExpanded;
                      });
                    },
                    icon: Icon(
                      _isSearchExpanded ? Icons.close : Icons.search,
                      color: Colors.white,
                      size: 24,
                    ),
                    tooltip: _isSearchExpanded ? "Close Search" : "Open Search",
                  ),
                ],
              ),
              
              const SizedBox(height: 10),

              // Filter Dropdown (Multi-Select)
              Builder(
                builder: (context) {
                  List<String> collectionNames = _collections.map((c) => c.name).toList();
                  List<String> selectedNames = _collections
                      .where((c) => _selectedCollectionIds.contains(c.id))
                      .map((c) => c.name)
                      .toList();

                  return MultiSelectDropdown(
                    items: collectionNames,
                    selectedItems: selectedNames,
                    hint: "Filter by Collection (All)",
                    onChanged: (List<String> newSelectedNames) {
                      setState(() {
                        _selectedCollectionIds = _collections
                            .where((c) => newSelectedNames.contains(c.name))
                            .map((c) => c.id!)
                            .toList();
                      });
                      _performSearch();
                    },
                  );
                }
              ),

              const SizedBox(height: 10),

              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity), // Hidden state
                secondChild: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search words...",
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        prefixIcon: const Icon(Icons.search, color: Colors.deepPurpleAccent),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
                crossFadeState: _isSearchExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              
              Expanded(
                child: RefreshIndicator(
                  color: Colors.deepPurpleAccent,
                  backgroundColor: const Color(0xFF1E1E1E),
                  onRefresh: () async {
                    await _loadCollections();
                    await _performSearch();
                  },
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
                    : _searchResults.isEmpty 
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(), // Ensure refresh works even if empty
                          children: [
                             SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                             Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 60, color: Colors.white.withValues(alpha: 0.1)),
                                const SizedBox(height: 10),
                                Text(
                                  "No words found.",
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                              ],
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          physics: const AlwaysScrollableScrollPhysics(), // Ensure refresh works
                          itemBuilder: (context, index) {
                            final word = _searchResults[index];
                            return Card(
                              color: const Color(0xFF1E1E1E),
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                onTap: () => _showWordDetails(word),
                                title: Text(word.word, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Text(word.meaningTr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey),
                                      onPressed: () => _editWord(word),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                     IconButton(
                                      icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                                      onPressed: () => _deleteWord(word),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
