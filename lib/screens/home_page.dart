import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../models/collection.dart';
import 'card_page.dart';
import 'add_word_page.dart';
import 'collection_settings_page.dart';

/// The main screen displaying all collections.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _dbService = DatabaseService();
  
  List<Collection> _collections = [];

  // Colors
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _accentColor = const Color(0xFFBB86FC);

  // Font Style
  final TextStyle _textStyle = const TextStyle(
    fontFamily: 'Roboto', 
    color: Colors.white,
    letterSpacing: 0.5,
  );

  @override
  void initState() {
    super.initState();
    // Load collections on startup
    _refreshCollections();
  }
  
  /// Fetches the latest list of collections from the database.
  void _refreshCollections() async {
    final data = await _dbService.getCollections();
    if (mounted) {
      setState(() {
        _collections = data;
      });
    }
  }

  /// Creates a custom page transition with fade and scale effects.
  Route _createFluidRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;
        var fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: animation, curve: curve));
        var scaleAnimation = Tween(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: animation, curve: curve));
        return FadeTransition(opacity: fadeAnimation, child: ScaleTransition(scale: scaleAnimation, child: child));
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }

  Future<void> _launchGitHub() async {
    final Uri url = Uri.parse('https://github.com/kemaltombul');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw Exception('Could not launch $url');
  }

  Future<void> _launchMail() async {
    final Uri emailLaunchUri = Uri(scheme: 'mailto', path: 'kemaltombull@hotmail.com', query: 'subject=Flashcard App Feedback');
    if (!await launchUrl(emailLaunchUri)) throw Exception('Could not launch email');
  }

  /// Shows a bottom sheet with contact options.
  void _showContactMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Contact Developer", style: _textStyle.copyWith(fontSize: 18, color: _accentColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ListTile(leading: const Icon(Icons.code, color: Colors.white70), title: Text("GitHub", style: _textStyle), onTap: () { Navigator.pop(context); _launchGitHub(); }),
            ListTile(leading: const Icon(Icons.email_outlined, color: Colors.redAccent), title: Text("Send Email", style: _textStyle), onTap: () { Navigator.pop(context); _launchMail(); }),
          ],
        ),
      ),
    );
  }

  /// Displays a dialog to create a new collection.
  void _showAddCollectionDialog() {
    final TextEditingController controller = TextEditingController();
    bool isGameMode = true; 

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("New Collection", style: _textStyle.copyWith(color: _accentColor, fontSize: 20, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Ex: A1 Verbs",
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: Colors.black12,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  SwitchListTile(
                    title: Text("Game Mode", style: _textStyle.copyWith(fontSize: 16)),
                    subtitle: Text(
                      isGameMode ? "Timer ON, Meaning Hidden" : "Timer OFF, Show Meaning",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    value: isGameMode,
                    activeTrackColor: _accentColor,
                    onChanged: (val) {
                      setState(() {
                        isGameMode = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: _textStyle.copyWith(color: Colors.grey.shade400))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () async {
                    if (controller.text.isNotEmpty) {
                      await _dbService.createCollection(controller.text, isGameMode);
                      if (context.mounted) {
                        _refreshCollections();
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text("Create", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  /// Handles importing a collection from a JSON file.
  void _importJson() async {
    String result = await _dbService.importFromJson();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result, style: const TextStyle(color: Colors.black)), backgroundColor: _accentColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
    _refreshCollections();
  }

  @override
  Widget build(BuildContext context) {
    // Check if Mobile or Web
    bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    Widget content = Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("My Library", style: _textStyle.copyWith(fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text("Manage your collections", style: _textStyle.copyWith(fontSize: 14, color: Colors.white54)),
                  ],
                ),
              ),
            ),
            _collections.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.dashboard_customize_outlined, size: 70, color: Colors.white10),
                          const SizedBox(height: 20),
                          Text("No Collections Yet", style: _textStyle.copyWith(fontSize: 18, color: Colors.white38)),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.4, 
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final collection = _collections[index];
                          return _buildDarkCard(collection);
                        },
                        childCount: _collections.length,
                      ),
                    ),
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: FloatingActionButton.small(
              heroTag: "importBtn",
              onPressed: _importJson,
              backgroundColor: _cardColor,
              foregroundColor: Colors.white, 
              elevation: 4,
              tooltip: "Import JSON",
              child: const Icon(Icons.cloud_upload_outlined),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 30, right: 10),
                child: FloatingActionButton(
                  heroTag: "contactBtn",
                  mini: true,
                  backgroundColor: _cardColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white10)),
                  onPressed: _showContactMenu,
                  child: const Icon(Icons.question_answer_outlined),
                ),
              ),
              Expanded(
                flex: 0,
                child: FloatingActionButton.extended(
                  heroTag: "addBtn",
                  onPressed: _showAddCollectionDialog,
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  icon: const Icon(Icons.add),
                  label: const Text("Collection", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isMobile) {
      return content;
    } else {
      return Scaffold(
        backgroundColor: Colors.black, 
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 800), 
            margin: const EdgeInsets.all(20), 
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(34)), 
              child: content
            )
          )
        )
      );
    }
  }

  /// Builds a single collection card with gestures.
  Widget _buildDarkCard(Collection collection) {
    return GestureDetector(
      onTap: () async {
        int count = await _dbService.getWordCount(collection.id!);
        if (count > 0) {
           if (mounted) {
             await Navigator.of(context).push(_createFluidRoute(
               VocabularyCardPage(
                 collectionId: collection.id!, 
                 collectionName: collection.name,
                 isGame: collection.isGame,
               )
             ));
             _refreshCollections();
           }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Empty Collection! Add words first.", style: TextStyle(color: Colors.white)), 
                backgroundColor: Colors.redAccent, 
                behavior: SnackBarBehavior.floating
              )
            );
          }
        }
      },
      onLongPress: () => _showOptionsSheet(collection),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Positioned(right: -10, bottom: -10, child: Icon(Icons.folder, size: 80, color: Colors.white.withValues(alpha: 0.03))),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _accentColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.folder_open, color: _accentColor, size: 18)),
                      InkWell(
                        onTap: () async {
                          await _dbService.toggleFavorite(collection.id!, collection.isFavorite);
                          _refreshCollections();
                        },
                        child: Icon(collection.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded, color: collection.isFavorite ? Colors.amber : Colors.white38, size: 24),
                      )
                    ],
                  ),
                  Text(collection.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _textStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows options (Add Word, Settings, Delete) for a collection.
  void _showOptionsSheet(Collection collection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) => Wrap(children: [
        ListTile(
          leading: const Icon(Icons.add_circle, color: Colors.greenAccent), 
          title: Text("Add New Word", style: _textStyle), 
          onTap: () {Navigator.pop(sheetContext); Navigator.of(context).push(_createFluidRoute(AddWordPage(collectionId: collection.id!)));}
        ),
        ListTile(
          leading: const Icon(Icons.settings, color: Colors.white70), 
          title: Text("Settings / Edit", style: _textStyle), 
          onTap: () async {
            Navigator.pop(sheetContext); 
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => CollectionSettingsPage(collection: collection))
            );
            if (context.mounted) _refreshCollections(); 
          }
        ),
        ListTile(
          leading: Icon(Icons.download, color: Colors.blueAccent.shade100),
          title: Text("Download as JSON", style: _textStyle),
          onTap: () async {
            Navigator.pop(sheetContext);
            String res = await _dbService.exportCollectionAsJson(collection.id!, collection.name);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(res, style: const TextStyle(color: Colors.black)), backgroundColor: _accentColor)
              );
            }
          }
        ),
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.redAccent),
          title: Text("Delete Collection", style: _textStyle),
          onTap: () async {
            Navigator.pop(sheetContext);
            if (!context.mounted) return;
            
            bool? confirm = await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: _cardColor,
                title: Text("Are you sure?", style: _textStyle),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text("Cancel", style: TextStyle(color: Colors.grey.shade400)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
                  )
                ],
              ),
            );
            
            if (confirm == true) {
              await _dbService.deleteCollection(collection.id!);
              if (context.mounted) {
                _refreshCollections();
              }
            }
          },
        ),
      ]),
    );
  }
}