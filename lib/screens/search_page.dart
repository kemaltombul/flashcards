import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import '../services/firestore_service.dart';
import '../models/word.dart';
import '../models/collection.dart';
import '../models/user_profile.dart';
import '../widgets/multi_select_dropdown.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  final FirestoreService _dbService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  List<Word> _searchResults = [];
  List<String> _selectedCollectionIds = []; // Empty means "All accessible collections"
  
  // Kullanıcının erişebildiği tüm koleksiyonlar (editable + subscribed) — ID cache ve filtre için
  List<Collection> _accessibleCollections = [];
  List<String> _accessibleCollectionIds = [];
  
  // Kullanıcının düzenleyebildiği koleksiyon ID'leri (owned + editor) — buton görünürlüğü için
  Set<String> _editableCollectionIds = {};
  
  StreamSubscription<List<Collection>>? _accessibleCollectionsSub;
  StreamSubscription<List<Collection>>? _editableIdsSub;
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _accessibleCollectionsSub?.cancel();
    _editableIdsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _subscribeToAccessibleCollections();
    _subscribeToEditableIds();
  }

  void _subscribeToAccessibleCollections() {
    final userProfileStream = _dbService.getUserProfileStream().asBroadcastStream();

    final Stream<List<Collection>> stream = userProfileStream.switchMap((UserProfile? profile) {
      final editableStream = _dbService.getEditableCollectionsStream();

      if (profile != null && profile.subscribedCollections.isNotEmpty) {
        final subStream = _dbService.getSubscribedCollectionsStream(profile);
        return Rx.combineLatest2(
          editableStream,
          subStream,
          (List<Collection> editable, List<Collection> subs) {
            final combined = <String, Collection>{};
            for (var c in editable) combined[c.id!] = c;
            for (var c in subs) combined[c.id!] = c;
            return combined.values.toList();
          },
        );
      }
      return editableStream;
    });

    _accessibleCollectionsSub = stream.listen((collections) {
      setState(() {
        _accessibleCollections = collections;
        _accessibleCollectionIds = collections.map((c) => c.id!).toList();
      });
      _performSearch();
    });
  }

  void _subscribeToEditableIds() {
    _editableIdsSub = _dbService.getEditableCollectionsStream().listen((collections) {
      if (mounted) {
        setState(() {
          _editableCollectionIds = collections.map((c) => c.id!).toSet();
        });
      }
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
      final idsToSearch = _selectedCollectionIds.isNotEmpty
          ? _selectedCollectionIds
          : _accessibleCollectionIds;
      final results = await _dbService.searchWords(
        _searchController.text,
        collectionIds: idsToSearch,
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
        content: Text(
          "Are you sure you want to delete '${word.word}'?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbService.deleteWord(word.id!);
      _performSearch(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Word deleted"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _editWord(Word word) async {
    final wordCtrl = TextEditingController(text: word.word);
    final defCtrl = TextEditingController(text: word.definition);
    final trCtrl = TextEditingController(text: word.translation);
    final exCtrl = TextEditingController(text: word.contextualInfo);

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
                  translation: trCtrl.text,
                  contextualInfo: exCtrl.text,
                );
                await _dbService.updateWord(updatedWord);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _performSearch();
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: Colors.deepPurpleAccent, size: 20),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 10,
        ),
      ),
    );
  }

  void _showWordDetails(Word word) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      word.word,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_editableCollectionIds.contains(word.collectionId))
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                          onPressed: () {
                            Navigator.pop(context);
                            _editWord(word);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteWord(word);
                          },
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                word.translation,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.deepPurpleAccent,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 20),
              if (word.definition.isNotEmpty) ...[
                _buildDetailRow(Icons.menu_book, "Definition", word.definition),
                const SizedBox(height: 20),
              ],
              if (word.contextualInfo.isNotEmpty) ...[
                _buildDetailRow(
                  Icons.format_quote_rounded,
                  "Example",
                  word.contextualInfo,
                ),
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
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 5),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Search & Browse",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Search Field
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search words...",
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.deepPurpleAccent,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 20,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Her zaman görünür MultiSelectDropdown
              MultiSelectDropdown(
                items: _accessibleCollections.map((c) => c.name).toList(),
                selectedItems: _accessibleCollections
                    .where((c) => _selectedCollectionIds.contains(c.id))
                    .map((c) => c.name)
                    .toList(),
                hint: "Filter by Collection (All)",
                onChanged: (List<String> newSelectedNames) {
                  setState(() {
                    _selectedCollectionIds = _accessibleCollections
                        .where((c) => newSelectedNames.contains(c.name))
                        .map((c) => c.id!)
                        .toList();
                  });
                  _performSearch();
                },
              ),

              const SizedBox(height: 15),

              Expanded(
                child: RefreshIndicator(
                  color: Colors.deepPurpleAccent,
                  backgroundColor: const Color(0xFF1E1E1E),
                  onRefresh: () async {
                    await _performSearch();
                  },
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.deepPurpleAccent,
                          ),
                        )
                      : _searchResults.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(), 
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.2,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 60,
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "No words found.",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          physics: const AlwaysScrollableScrollPhysics(), 
                          itemBuilder: (context, index) {
                            final word = _searchResults[index];
                            return Card(
                              color: const Color(0xFF1E1E1E),
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 5,
                                ),
                                onTap: () => _showWordDetails(word),
                                title: Text(
                                  word.word,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  word.translation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                trailing: _editableCollectionIds.contains(word.collectionId)
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 20,
                                              color: Colors.blueGrey,
                                            ),
                                            onPressed: () => _editWord(word),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 20,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () => _deleteWord(word),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      )
                                    : null,
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