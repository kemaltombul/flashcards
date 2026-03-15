import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/collection.dart';
import '../models/user_profile.dart';
import '../dialogs/add_collection_dialog.dart';
import '../dialogs/rename_collection_dialog.dart';
import '../dialogs/manage_editors_dialog.dart';
import 'flashcard_page.dart';
import 'search_page.dart';
import 'profile_page.dart';
import '../dialogs/scan_dialog.dart';
import '../services/ai_service.dart';
import 'package:rxdart/rxdart.dart';



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

  late Stream<UserProfile?> _userProfileStream;
  late Stream<List<Collection>> _collectionsStream;
  late Stream<int> _streakStream;

  @override
  bool get wantKeepAlive => true; // Keep page alive

  @override
  void initState() {
    super.initState();
    _streakStream = _dbService.getUserStreakStream();
    
    // 1. Get a broadcast stream of the user profile so multiple listeners can use it
    _userProfileStream = _dbService.getUserProfileStream().asBroadcastStream();

    // 2. Create a reactive stream that merges owned and subscribed collections
    _collectionsStream = _userProfileStream.switchMap((profile) {
      // Always get owned and editable collections
      final ownedStream = _dbService.getEditableCollectionsStream();

      // If profile exists and has subscriptions, get those too
      if (profile != null && profile.subscribedCollections.isNotEmpty) {
        final subStream = _dbService.getSubscribedCollectionsStream(profile);
        
        // Merge them together and sort by created_at
        return Rx.combineLatest2(
          ownedStream, 
          subStream, 
          (List<Collection> owned, List<Collection> subs) {
            final combined = [...owned, ...subs];
            // Sort by createdAt descending (handling potential nulls gracefully)
            combined.sort((a, b) {
              final aTime = a.createdAt ?? DateTime(2000);
              final bTime = b.createdAt ?? DateTime(2000);
              return bTime.compareTo(aTime);
            });
            return combined;
          }
        );
      } else {
        // No subscriptions, just return owned
        return ownedStream;
      }
    });
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



  /// Displays a dialog to create a new collection.
  void _showAddCollectionDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddCollectionDialog(),
    );
  }

  void _showSubscribeDialog() {
    TextEditingController codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("Subscribe to Collection", style: _textStyle.copyWith(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: codeController,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 5),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: "XXXXXX",
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            filled: true,
            fillColor: Colors.black12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBB86FC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.length != 6) return;
              
              Navigator.pop(ctx);
              bool success = await _dbService.subscribeByShareCode(code);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? "Successfully subscribed!" : "Invalid Code or Collection is Private.", 
                      style: const TextStyle(color: Colors.black)
                    ), 
                    backgroundColor: success ? Colors.greenAccent : Colors.redAccent,
                  )
                );
              }
            },
            child: const Text("Subscribe", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  /// Displays a dialog to rename a collection.
  void _showRenameDialog(Collection collection) {
    showDialog(
      context: context,
      builder: (context) => RenameCollectionDialog(collection: collection),
    );
  }

  /// Displays the dialog for managing editors (collaborators).
  void _showManageEditorsDialog(Collection collection) {
    showDialog(
      context: context,
      builder: (context) => ManageEditorsDialog(collection: collection),
    );
  }



  /// Calculates the appropriate greeting based on the current hour.
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) {
      return "Good Night,";
    } else if (hour < 12) {
      return "Good Morning,";
    } else if (hour < 17) {
      return "Good Afternoon,";
    } else {
      return "Good Evening,";
    }
  }

  /// Gets the user's display name or a fallback
  String _getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "Guest";
    
    // Check displayName first, fallback to email prefix if null
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      // Return first name if possible
      return user.displayName!.split(" ").first; 
    }
    
    if (user.email != null) {
      return user.email!.split("@").first;
    }
    
    return "User";
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    // Check if Mobile or Web

    Widget content = Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: StreamBuilder<UserProfile?>(
          stream: _userProfileStream,
          builder: (context, profileSnapshot) {
            final userProfile = profileSnapshot.data;

            return StreamBuilder<List<Collection>>(
              stream: _collectionsStream,
              builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final collections = snapshot.data ?? [];

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  expandedHeight: 220,
                  toolbarHeight: 70,
                  floating: false,
                  pinned: false,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                    title: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getGreeting(), 
                          style: _textStyle.copyWith(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.normal)
                        ),
                        Text(_getUserName(), 
                          style: _textStyle.copyWith(fontSize: 28, fontWeight: FontWeight.w300)
                        ),
                        const SizedBox(height: 8),
                        // Streak Badge (Dynamic)
                        StreamBuilder<int>(
                          stream: _streakStream,
                          builder: (context, streakSnapshot) {
                            final streak = streakSnapshot.data ?? 0;
                            
                            final bool hasStreak = streak > 0;
                            final Color badgeColor = hasStreak ? Colors.orange : Colors.grey.withOpacity(0.5);

                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C1E10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: badgeColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasStreak ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined, 
                                    color: badgeColor, 
                                    size: 14
                                  ),
                                  const SizedBox(width: 4),
                                  Text("$streak Day Streak", style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                ],
                              ),
                            );
                          }
                        ),
                      ],
                    ),
                    centerTitle: false, 
                  ),
                  actions: [

                    Container(
                      margin: const EdgeInsets.only(right: 15, top: 20),
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
                      margin: const EdgeInsets.only(right: 15, top: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white70, size: 24),
                        color: _cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(color: Colors.white10),
                        ),
                        onSelected: (value) {
                          if (value == 'add') {
                            _showAddCollectionDialog();
                          } else if (value == 'subscribe') {
                            _showSubscribeDialog();
                          } else if (value == 'profile') {
                             Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'add',
                            child: Row(
                              children: [
                                Icon(Icons.create_new_folder_outlined, color: _accentColor, size: 20),
                                const SizedBox(width: 12),
                                const Text('New Collection', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'subscribe',
                            child: Row(
                              children: [
                                Icon(Icons.group_add_outlined, color: Colors.greenAccent, size: 20),
                                const SizedBox(width: 12),
                                const Text('Subscribe via Code', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),

                           PopupMenuItem(
                            value: 'profile',
                            child: Row(
                              children: [
                                Icon(Icons.person_outline_rounded, color: _accentColor, size: 20),
                                const SizedBox(width: 12),
                                const Text('Profile', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
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
                              final isFavorite = userProfile?.favoriteCollectionIds.contains(collection.id) ?? false;
                              return _buildDarkCard(collection, isFavorite);
                            },
                            childCount: collections.length,
                          ),
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          }
        );
          }
        ),
      ),
    );

    return content;
  }

  /// Builds a single collection card with gestures.
  Widget _buildDarkCard(Collection collection, bool isFavorite) {
    // We removed isGame from Collection, so we'll just style them uniformly or let the user choose inside.
    // For now, let's pretend they are all "Study" or neutral.
    final bool isShared = collection.isShared;
    final bool isOwner = collection.ownerId == FirebaseAuth.instance.currentUser?.uid;
    final String label = isOwner ? (isShared ? "Shared" : "Private") : "Subscribed";
    final IconData labelIcon = isOwner ? (isShared ? Icons.public : Icons.lock_outline) : Icons.group_add_outlined;
    final Color iconColor = isOwner 
        ? (isShared ? const Color(0xFF66BB6A) : const Color(0xFF64B5F6)) 
        : Colors.orangeAccent;

    return GestureDetector(
      onTap: () {
         if (mounted) {
           // Provide a default isGame=false for now. Later we can add a dialog to pick mode.
           Navigator.of(context).push(_createFluidRoute(
             FlashcardPage(
               collectionId: collection.id!, 
               collectionName: collection.name,
               isGame: false,
             )
           ));
         }
      },
      onLongPress: () => _showOptionsSheet(collection),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
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
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Subtle background gradient/icon
                  Positioned(
                  right: -15, 
                  bottom: -15, 
                  child: Icon(
                    labelIcon, 
                    size: 100, 
                    color: iconColor.withOpacity(0.05)
                  )
                ),
                
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(labelIcon, color: iconColor, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                label,
                                style: TextStyle(color: iconColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            await _dbService.toggleFavorite(collection.id!, isFavorite);
                          },
                          child: Icon(
                            isFavorite ? Icons.star_rounded : Icons.star_outline_rounded, 
                            color: isFavorite ? const Color(0xFFFFD54F) : Colors.white24, 
                            size: 20
                          ),
                        )
                      ],
                    ),
                    const Spacer(),
                    Text(
                      collection.name, 
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis, 
                      style: _textStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500, height: 1.2)
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Tap to study",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
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

        // Owner only actions
        if (collection.ownerId == FirebaseAuth.instance.currentUser?.uid) ...[
          ListTile(
            leading: Icon(
              collection.isShared ? Icons.lock : Icons.public, 
              color: collection.isShared ? Colors.orangeAccent : Colors.greenAccent
            ),
            title: Text(collection.isShared ? "Make Private" : "Make Public", style: _textStyle),
            onTap: () async {
              Navigator.pop(sheetContext);
              
              final newStatus = !collection.isShared;
              final actionText = newStatus ? "Public" : "Private";
              
              bool? confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: _cardColor,
                  title: Text("Make $actionText", style: _textStyle),
                  content: Text(
                    newStatus 
                      ? "Making this collection public will allow anyone with the code to subscribe. Are you sure?" 
                      : "Making this collection private will prevent new subscribers from joining. Are you sure?",
                    style: const TextStyle(color: Colors.white70)
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text("Cancel", style: TextStyle(color: Colors.grey.shade400)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(actionText, style: TextStyle(color: newStatus ? Colors.greenAccent : Colors.orangeAccent)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _dbService.updateCollectionVisibility(collection.id!, newStatus);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        newStatus ? "Collection is now Public!" : "Collection is now Private", 
                        style: const TextStyle(color: Colors.black)
                      ), 
                      backgroundColor: _accentColor
                    )
                  );
                }
              }
            }
          ),
          ListTile(
            leading: const Icon(Icons.group_add, color: Colors.orangeAccent),
            title: Text("Manage Editors", style: _textStyle),
            onTap: () {
              Navigator.pop(sheetContext);
              _showManageEditorsDialog(collection);
            }
          ),
        ],

        // Owner VE editörler: koleksiyon public ise kodu kopyalayabilir
        if (collection.isShared && collection.shareCode != null)
          ListTile(
            leading: const Icon(Icons.share, color: Colors.white70),
            title: Text("Copy Share Code", style: _textStyle),
            onTap: () async {
              Navigator.pop(sheetContext);
              await Clipboard.setData(ClipboardData(text: collection.shareCode!));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text("Share Code copied!", style: TextStyle(color: Colors.black)), backgroundColor: _accentColor)
                );
              }
            }
          ),
        if (collection.ownerId == FirebaseAuth.instance.currentUser?.uid)
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
        
        // Subscriber action
        if (collection.ownerId != FirebaseAuth.instance.currentUser?.uid)
          ListTile(
            leading: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
            title: Text("Unsubscribe", style: _textStyle),
            onTap: () async {
              Navigator.pop(sheetContext);
              
              bool? confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: _cardColor,
                  title: Text("Unsubscribe", style: _textStyle),
                  content: Text("Are you sure you want to unsubscribe from '${collection.name}'?", style: const TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text("Cancel", style: TextStyle(color: Colors.grey.shade400)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("Unsubscribe", style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _dbService.unsubscribeFromCollection(collection.id!);
              }
            }
          ),
      ]),
    );
  }
}