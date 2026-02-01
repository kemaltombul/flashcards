

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/collection.dart';
import '../dialogs/add_collection_dialog.dart';
import '../dialogs/rename_collection_dialog.dart';
import 'flashcard_page.dart';
import 'search_page.dart';



/// The main screen displaying all collections.
class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> with AutomaticKeepAliveClientMixin {
  final FirestoreService _dbService = FirestoreService();
  
  // Colors
  // Zen Colors
  final Color _backgroundColor = Colors.transparent; // Handled by Main Scaffold
  final Color _cardColor = const Color(0xFF252525).withOpacity(0.9); 
  final Color _accentColor = const Color(0xFFD0BCFF); // Soft Lavender

  // Font Style
  final TextStyle _textStyle = const TextStyle(
    fontFamily: 'Roboto', 
    color: Colors.white,
    letterSpacing: 0.5,
  );

  @override
  bool get wantKeepAlive => true; // Keep page alive

  @override
  void initState() {
    super.initState();
  }
  
  /// Creates a custom page transition with fade and scale effects.

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
    showDialog(
      context: context,
      builder: (context) => const AddCollectionDialog(),
    );
  }

  /// Displays a dialog to rename a collection.
  void _showRenameDialog(Collection collection) {
    showDialog(
      context: context,
      builder: (context) => RenameCollectionDialog(collection: collection),
    );
  }



  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    // Check if Mobile or Web

    Widget content = Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: StreamBuilder<List<Collection>>(
          stream: _dbService.getCollectionsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final collections = snapshot.data ?? [];

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  expandedHeight: 120,
                  floating: false,
                  pinned: false,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 24, bottom: 20),
                    title: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Good Evening,", 
                          style: _textStyle.copyWith(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.normal)
                        ),
                        Text("Kemal", 
                          style: _textStyle.copyWith(fontSize: 28, fontWeight: FontWeight.w300)
                        ),
                      ],
                    ),
                    centerTitle: false, 
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 15, top: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search_rounded, color: Colors.white70, size: 24),
                        tooltip: 'Search Words',
                        onPressed: () {
                           Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage()));
                        },
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 20, top: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
                        onPressed: () => AuthService().signOut(),
                      ),
                    ),
                  ],
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                collections.isEmpty
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
                              final collection = collections[index];
                              return _buildDarkCard(collection);
                            },
                            childCount: collections.length,
                          ),
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          }
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [

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

    return content;
  }

  /// Builds a single collection card with gestures.
  Widget _buildDarkCard(Collection collection) {
    // Styling based on mode
    final bool isGame = collection.isGame;
    // Zen Card Styling
    final Color iconColor = isGame ? const Color(0xFFFFB74D) : const Color(0xFF64B5F6); // Softer Orange / Blue

    return GestureDetector(
      onTap: () {
         if (mounted) {
           Navigator.of(context).push(_createFluidRoute(
             FlashcardPage(
               collectionId: collection.id!, 
               collectionName: collection.name,
               isGame: collection.isGame,
             )
           ));
         }
      },
      onLongPress: () => _showOptionsSheet(collection),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(28), // Softer corners
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2), 
              blurRadius: 15, 
              offset: const Offset(0, 8)
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Subtle background gradient/icon
              Positioned(
                right: -15, 
                bottom: -15, 
                child: Icon(
                  isGame ? Icons.gamepad_rounded : Icons.menu_book_rounded, 
                  size: 100, 
                  color: iconColor.withOpacity(0.05)
                )
              ),
              
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Pill-shaped mode indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(isGame ? Icons.gamepad : Icons.book, color: iconColor, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                isGame ? "Game" : "Study",
                                style: TextStyle(color: iconColor, fontSize: 10, fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            await _dbService.toggleFavorite(collection.id!, collection.isFavorite);
                          },
                          child: Icon(
                            collection.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded, 
                            color: collection.isFavorite ? const Color(0xFFFFD54F) : Colors.white24, 
                            size: 22
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      collection.name, 
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis, 
                      style: _textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w500, height: 1.2)
                    ),
                    const SizedBox(height: 5),
                     Text(
                      "Tap to study",
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows options (Add Word, Settings, Delete) for a collection.
  void _showOptionsSheet(Collection collection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) => Wrap(children: [

        ListTile(
          leading: const Icon(Icons.edit, color: Colors.white70), 
          title: Text("Rename Collection", style: _textStyle), 
          onTap: () {
            Navigator.pop(sheetContext);
            _showRenameDialog(collection);
          }
        ),
        ListTile(
          leading: Icon(Icons.download, color: Colors.blueAccent.shade100),
          title: Text("Download as JSON", style: _textStyle),
          onTap: () async {
            Navigator.pop(sheetContext);
            // String res = await _dbService.exportCollectionAsJson(collection.id!, collection.name);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Export disabled for Cloud migration", style: const TextStyle(color: Colors.black)), backgroundColor: _accentColor)
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
              }
            }
          },
        ),
      ]),
    );
  }
}