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
import 'logs_page.dart';                      // ← YENİ
import '../dialogs/scan_dialog.dart';
import '../services/ai_service.dart';
import 'package:rxdart/rxdart.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage>
    with AutomaticKeepAliveClientMixin {
  final FirestoreService _dbService = FirestoreService();

  final Color _backgroundColor = Colors.transparent;
  final Color _cardColor = const Color(0xFF252525).withOpacity(0.9);
  final Color _accentColor = const Color(0xFFD0BCFF);

  final TextStyle _textStyle = const TextStyle(
    fontFamily: 'Roboto',
    color: Colors.white,
    letterSpacing: 0.5,
  );

  late Stream<UserProfile?> _userProfileStream;
  late Stream<List<Collection>> _collectionsStream;
  late Stream<int> _streakStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _streakStream = _dbService.getUserStreakStream();
    _userProfileStream = _dbService.getUserProfileStream().asBroadcastStream();
    _collectionsStream = _userProfileStream.switchMap((profile) {
      final ownedStream = _dbService.getEditableCollectionsStream();
      if (profile != null && profile.subscribedCollections.isNotEmpty) {
        final subStream = _dbService.getSubscribedCollectionsStream(profile);
        return Rx.combineLatest2(
          ownedStream,
          subStream,
          (List<Collection> owned, List<Collection> subs) {
            final combined = [...owned, ...subs];
            combined.sort((a, b) {
              final aTime = a.createdAt ?? DateTime(2000);
              final bTime = b.createdAt ?? DateTime(2000);
              return bTime.compareTo(aTime);
            });
            return combined;
          },
        );
      } else {
        return ownedStream;
      }
    });
  }

  Route _createFluidRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;
        var fadeAnimation = Tween(begin: 0.0, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: curve));
        var scaleAnimation = Tween(begin: 0.95, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: curve));
        return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child));
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }

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
        title: Text('Subscribe to Collection',
            style: _textStyle.copyWith(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: codeController,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
              color: Colors.white, fontSize: 24, letterSpacing: 5),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'XXXXXX',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            filled: true,
            fillColor: Colors.black12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBB86FC),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.length != 6) return;
              Navigator.pop(ctx);
              bool success = await _dbService.subscribeByShareCode(code);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    success
                        ? 'Successfully subscribed!'
                        : 'Invalid Code or Collection is Private.',
                    style: const TextStyle(color: Colors.black),
                  ),
                  backgroundColor:
                      success ? Colors.greenAccent : Colors.redAccent,
                ));
              }
            },
            child: const Text('Subscribe',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(Collection collection) {
    showDialog(
      context: context,
      builder: (context) => RenameCollectionDialog(collection: collection),
    );
  }

  void _showManageEditorsDialog(Collection collection) {
    showDialog(
      context: context,
      builder: (context) => ManageEditorsDialog(collection: collection),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good Night,';
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String _getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Guest';
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!.split(' ').first;
    }
    if (user.email != null) return user.email!.split('@').first;
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
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
                                style: _textStyle.copyWith(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.normal)),
                            Text(_getUserName(),
                                style: _textStyle.copyWith(
                                    fontSize: 28, fontWeight: FontWeight.w300)),
                            const SizedBox(height: 8),
                            StreamBuilder<int>(
                              stream: _streakStream,
                              builder: (context, streakSnapshot) {
                                final streak = streakSnapshot.data ?? 0;
                                final bool hasStreak = streak > 0;
                                final Color badgeColor = hasStreak
                                    ? Colors.orange
                                    : Colors.grey.withOpacity(0.5);
                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C1E10),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: badgeColor.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        hasStreak
                                            ? Icons.local_fire_department_rounded
                                            : Icons
                                                .local_fire_department_outlined,
                                        color: badgeColor,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text('$streak Day Streak',
                                          style: TextStyle(
                                              color: badgeColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11)),
                                    ],
                                  ),
                                );
                              },
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
                            icon: const Icon(Icons.search_rounded,
                                color: Colors.white70, size: 24),
                            tooltip: 'Search Words',
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const SearchPage()));
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
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white70, size: 24),
                            color: _cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: const BorderSide(color: Colors.white10),
                            ),
                            onSelected: (value) {
                              switch (value) {
                                case 'add':
                                  _showAddCollectionDialog();
                                case 'subscribe':
                                  _showSubscribeDialog();
                                case 'profile':
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const ProfilePage()));
                                case 'logs':                          // ← YENİ
                                  Navigator.push(
                                      context,
                                      _createFluidRoute(const LogsPage()));
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'profile',
                                child: Row(children: [
                                  Icon(Icons.person_outline_rounded,
                                      color: _accentColor, size: 20),
                                  const SizedBox(width: 12),
                                  const Text('Profile',
                                      style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'add',
                                child: Row(children: [
                                  Icon(Icons.create_new_folder_outlined,
                                      color: _accentColor, size: 20),
                                  const SizedBox(width: 12),
                                  const Text('New Collection',
                                      style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'subscribe',
                                child: Row(children: [
                                  const Icon(Icons.group_add_outlined,
                                      color: Colors.greenAccent, size: 20),
                                  const SizedBox(width: 12),
                                  const Text('Subscribe via Code',
                                      style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                              // ── Logs girişi — sadece admin ─────────
                              if (FirebaseAuth.instance.currentUser?.uid ==
                                  'CQk9Sf8MK4VwyBkQNjYK3ZdlzL13')
                                PopupMenuItem(
                                  value: 'logs',
                                  child: Row(children: [
                                    const Icon(Icons.terminal_rounded,
                                        color: Colors.white38, size: 20),
                                    const SizedBox(width: 12),
                                    const Text('App Logs',
                                        style: TextStyle(color: Colors.white54)),
                                  ]),
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
                                  const Icon(
                                      Icons.dashboard_customize_outlined,
                                      size: 70,
                                      color: Colors.white10),
                                  const SizedBox(height: 20),
                                  Text('No Collections Yet',
                                      style: _textStyle.copyWith(
                                          fontSize: 18,
                                          color: Colors.white38)),
                                ],
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.4,
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final collection = collections[index];
                                  final isFavorite = userProfile
                                          ?.favoriteCollectionIds
                                          .contains(collection.id) ??
                                      false;
                                  return _buildDarkCard(collection, isFavorite);
                                },
                                childCount: collections.length,
                              ),
                            ),
                          ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDarkCard(Collection collection, bool isFavorite) {
    final bool isShared = collection.isShared;
    final bool isOwner =
        collection.ownerId == FirebaseAuth.instance.currentUser?.uid;
    final String label =
        isOwner ? (isShared ? 'Shared' : 'Private') : 'Subscribed';
    final IconData labelIcon = isOwner
        ? (isShared ? Icons.public : Icons.lock_outline)
        : Icons.group_add_outlined;
    final Color iconColor = isOwner
        ? (isShared ? const Color(0xFF66BB6A) : const Color(0xFF64B5F6))
        : Colors.orangeAccent;

    return GestureDetector(
      onTap: () {
        if (mounted) {
          Navigator.of(context).push(_createFluidRoute(FlashcardPage(
            collectionId: collection.id!,
            collectionName: collection.name,
                      )));
        }
      },
      onLongPress: () => _showOptionsSheet(collection),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border:
              Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8))
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
                  Positioned(
                    right: -15,
                    bottom: -15,
                    child: Icon(labelIcon,
                        size: 100, color: iconColor.withOpacity(0.05)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(labelIcon, color: iconColor, size: 14),
                                  const SizedBox(width: 5),
                                  Text(label,
                                      style: TextStyle(
                                          color: iconColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                await _dbService.toggleFavorite(
                                    collection.id!, isFavorite);
                              },
                              child: Icon(
                                isFavorite
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: isFavorite
                                    ? const Color(0xFFFFD54F)
                                    : Colors.white24,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(collection.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _textStyle.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.2)),
                        const SizedBox(height: 5),
                        const Text('Tap to study',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 11)),
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

  void _showOptionsSheet(Collection collection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.white70),
            title: Text('Rename Collection', style: _textStyle),
            onTap: () {
              Navigator.pop(sheetContext);
              _showRenameDialog(collection);
            },
          ),

          if (collection.ownerId == FirebaseAuth.instance.currentUser?.uid) ...[
            ListTile(
              leading: Icon(
                collection.isShared ? Icons.lock : Icons.public,
                color: collection.isShared
                    ? Colors.orangeAccent
                    : Colors.greenAccent,
              ),
              title: Text(
                  collection.isShared ? 'Make Private' : 'Make Public',
                  style: _textStyle),
              onTap: () async {
                Navigator.pop(sheetContext);
                final newStatus = !collection.isShared;
                final actionText = newStatus ? 'Public' : 'Private';
                bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _cardColor,
                    title: Text('Make $actionText', style: _textStyle),
                    content: Text(
                      newStatus
                          ? 'Making this collection public will allow anyone with the code to subscribe. Are you sure?'
                          : 'Making this collection private will prevent new subscribers from joining. Are you sure?',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel',
                              style:
                                  TextStyle(color: Colors.grey.shade400))),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(actionText,
                              style: TextStyle(
                                  color: newStatus
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _dbService.updateCollectionVisibility(
                      collection.id!, newStatus);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        newStatus
                            ? 'Collection is now Public!'
                            : 'Collection is now Private',
                        style: const TextStyle(color: Colors.black),
                      ),
                      backgroundColor: _accentColor,
                    ));
                  }
                }
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.group_add, color: Colors.orangeAccent),
              title: Text('Manage Editors', style: _textStyle),
              onTap: () {
                Navigator.pop(sheetContext);
                _showManageEditorsDialog(collection);
              },
            ),
          ],

          if (collection.isShared && collection.shareCode != null)
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white70),
              title: Text('Copy Share Code', style: _textStyle),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Clipboard.setData(
                    ClipboardData(text: collection.shareCode!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Share Code copied!',
                        style: TextStyle(color: Colors.black)),
                    backgroundColor: _accentColor,
                  ));
                }
              },
            ),

          if (collection.ownerId == FirebaseAuth.instance.currentUser?.uid)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: Text('Delete Collection', style: _textStyle),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (!context.mounted) return;
                bool? confirm = await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _cardColor,
                    title: Text('Are you sure?', style: _textStyle),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel',
                              style:
                                  TextStyle(color: Colors.grey.shade400))),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _dbService.deleteCollection(collection.id!);
                }
              },
            ),

          if (collection.ownerId != FirebaseAuth.instance.currentUser?.uid)
            ListTile(
              leading: const Icon(Icons.remove_circle_outline,
                  color: Colors.redAccent),
              title: Text('Unsubscribe', style: _textStyle),
              onTap: () async {
                Navigator.pop(sheetContext);
                bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _cardColor,
                    title: Text('Unsubscribe', style: _textStyle),
                    content: Text(
                        "Are you sure you want to unsubscribe from '${collection.name}'?",
                        style: const TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel',
                              style:
                                  TextStyle(color: Colors.grey.shade400))),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Unsubscribe',
                              style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _dbService.unsubscribeFromCollection(collection.id!);
                }
              },
            ),
        ],
      ),
    );
  }
}