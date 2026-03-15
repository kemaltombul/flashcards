import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../models/collection.dart';
import '../models/word.dart';
import '../models/user_profile.dart';
import '../models/word_telemetry.dart';
import 'dart:math';
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper to get current User ID
  String? get _userId => _auth.currentUser?.uid;

  // =======================================================================
  // Users Profile & Subscriptions
  // =======================================================================

  /// Creates a basic profile for a new user if it doesn't exist.
  Future<void> createUserProfile() async {
    final uid = _userId;
    if (uid == null) return;
    
    final docRef = _db.collection('users').doc(uid);
    final snapshot = await docRef.get();
    
    if (!snapshot.exists) {
      final randomNum = Random().nextInt(90000) + 10000;
      final username = "user$randomNum";
      final profile = UserProfile(uid: uid, username: username);
      await docRef.set(profile.toMap());
    }
  }

  /// Retrieves the current user profile (where favorites and subs live)
  Stream<UserProfile?> getUserProfileStream() {
    final uid = _userId;
    if (uid == null) return Stream.value(null);

    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserProfile.fromMap(snapshot.data()!);
    });
  }

  Future<UserProfile?> getUserProfile() async {
    final uid = _userId;
    if (uid == null) return null;

    final snapshot = await _db.collection('users').doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return UserProfile.fromMap(snapshot.data()!);
  }

  // =======================================================================
  // Global Collections
  // =======================================================================

  /// Creates a new collection in the global 'collections' root.
  Future<String> createCollection(String name, bool isShared) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    // We MUST make sure the user profile exists before creating a collection
    await createUserProfile();

    final docRef = _db.collection('collections').doc();

    // Generate a random 6-character alphanumeric share code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final shareCode = String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));

    final collection = Collection(
      id: docRef.id,
      name: name,
      ownerId: uid,
      isShared: isShared,
      shareCode: shareCode,
      createdAt: DateTime.now(),
    );

    await docRef.set(collection.toMap());
    return docRef.id;
  }

  /// Get ONLY the collections that the user is the explicit owner of
  Stream<List<Collection>> getMyOwnedCollectionsStream() {
    final uid = _userId;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('collections')
        .where('owner_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Collection.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  /// Gets collections where the user is an owner OR has 'editor' role via editor_uids array
  Stream<List<Collection>> getEditableCollectionsStream() {
    final uid = _userId;
    if (uid == null) return Stream.value([]);
    
    return Rx.combineLatest2(
      getMyOwnedCollectionsStream(),
      _db
          .collection('collections')
          .where('editor_uids', arrayContains: uid)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => Collection.fromMap(doc.data(), doc.id)).toList()),
      (List<Collection> owned, List<Collection> editorSubs) {
        // Use a set to remove duplicates if somehow one is both owned and an editor (which shouldn't happen)
        final combinedMap = <String, Collection>{};
        for (var c in owned) { combinedMap[c.id!] = c; }
        for (var c in editorSubs) { combinedMap[c.id!] = c; }
        
        final combined = combinedMap.values.toList();
        combined.sort((a, b) {
          final aTime = a.createdAt ?? DateTime(2000);
          final bTime = b.createdAt ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
        return combined;
      }
    );
  }
  
  /// Add an editor to a collection by their username
  Future<String> addEditorByUsername(String collectionId, String targetUsername) async {
    try {
      final uid = _userId;
      if (uid == null) return "Not logged in";

      // 1. Find user by username
      final userSnap = await _db.collection('users').where('username', isEqualTo: targetUsername).limit(1).get();
      if (userSnap.docs.isEmpty) return "User with username '$targetUsername' not found";

      final targetUid = userSnap.docs.first.id;
      if (targetUid == uid) return "You cannot add yourself";

      // 2. Add to editor_uids array in the collection
      await _db.collection('collections').doc(collectionId).update({
        'editor_uids': FieldValue.arrayUnion([targetUid])
      });
      
      return "Success";
    } catch (e) {
      return "Firebase Error: $e";
    }
  }

  /// Remove an editor from a collection
  Future<void> removeEditorFromCollection(String collectionId, String targetUid) async {
    await _db.collection('collections').doc(collectionId).update({
      'editor_uids': FieldValue.arrayRemove([targetUid])
    });
  }

  /// Gets collections where the user is just a subscriber/reader based on their UserProfile
  Stream<List<Collection>> getSubscribedCollectionsStream(UserProfile profile) {
    if (profile.subscribedCollections.isEmpty) return Stream.value([]);

    // Extract raw IDs from the subscription contracts
    final List<String> subIds = profile.subscribedCollections.map((s) => s.collectionId).toList();

    // Firestore `whereIn` has a limit of 10 items.
    // We chunk this list to support unlimited subscriptions.
    final List<List<String>> chunks = [];
    for (var i = 0; i < subIds.length; i += 10) {
      chunks.add(subIds.sublist(i, i + 10 > subIds.length ? subIds.length : i + 10));
    }

    // Create a stream for each chunk
    final streamList = chunks.map((chunk) {
      return _db
          .collection('collections')
          .where(FieldPath.documentId, whereIn: chunk)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return Collection.fromMap(doc.data(), doc.id);
            });
          });
    }).toList();

    // Use Rx.combineLatestList to merge all chunk streams into one
    return Rx.combineLatestList(streamList).map((listOfLists) {
      return listOfLists.expand((list) => list).toList();
    });
  }

  /// Subscribes the current user to a collection using its share code
  Future<bool> subscribeByShareCode(String shareCode) async {
    final uid = _userId;
    if (uid == null) return false;

    try {
      // 1. Find the PUBLIC collection with this share code.
      //    ÖNEMLİ: Firestore Kuralları "filter = guard" prensipine göre çalışır.
      //    `is_shared == true` filtresi olmadan kural motoru sorguyu REDDEDERdi,
      //    çünkü dönen belgenin is_shared durumunu önceden bilemezdi.
      final snapshot = await _db
          .collection('collections')
          .where('share_code', isEqualTo: shareCode.toUpperCase().trim())
          .where('is_shared', isEqualTo: true) // ← KURALLARI TATMİN ETMEK İÇİN ŞART
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return false; // Kod bulunamadı veya koleksiyon private
      }

      final collectionDoc = snapshot.docs.first;
      final collectionId = collectionDoc.id;
      final data = collectionDoc.data();

      // Kendi koleksiyonuna abone olunamazsın
      if (data['owner_id'] == uid) {
        return false;
      }

      // Zaten abone misin? (tekrar eklemeyi önle)
      final userSnap = await _db.collection('users').doc(uid).get();
      if (userSnap.exists) {
        final existingSubs = userSnap.data()?['subscribed_collections'] as List<dynamic>? ?? [];
        final alreadySubscribed = existingSubs.any(
          (s) => s is Map<String, dynamic> && s['collection_id'] == collectionId,
        );
        if (alreadySubscribed) return true; // Zaten abone, başarılı say
      }

      // 2. Kullanıcının 'subscribed_collections' dizisine ekle
      final newSub = SubscribedCollection(
        collectionId: collectionId,
        role: 'reader',
      );

      await _db.collection('users').doc(uid).update({
        'subscribed_collections': FieldValue.arrayUnion([newSub.toMap()]),
      });

      return true;
    } catch (e) {
      print('[subscribeByShareCode] Error: $e');
      return false;
    }
  }

  Future<void> updateCollectionName(String id, String newName) async {
    await _db.collection('collections').doc(id).update({'name': newName});
  }

  Future<void> updateCollectionVisibility(String id, bool isShared) async {
    await _db.collection('collections').doc(id).update({'is_shared': isShared});
  }

  /// Toggles whether a collection is in the user's FAVORITES array
  Future<void> toggleFavorite(String id, bool isCurrentlyFavorite) async {
    final uid = _userId;
    if (uid == null) return;
    
    final userRef = _db.collection('users').doc(uid);
    
    if (isCurrentlyFavorite) {
      // Remove from favorites
      await userRef.update({
        'favorite_collection_ids': FieldValue.arrayRemove([id])
      });
    } else {
      // Add to favorites
      await userRef.update({
        'favorite_collection_ids': FieldValue.arrayUnion([id])
      });
    }
  }

  /// Removes a collection from the user's subscribed array
  Future<void> unsubscribeFromCollection(String collectionId) async {
    final uid = _userId;
    if (uid == null) return;
    
    final userRef = _db.collection('users').doc(uid);
    final snapshot = await userRef.get();
    
    if (snapshot.exists) {
      final data = snapshot.data();
      if (data != null && data.containsKey('subscribed_collections')) {
        List<dynamic> subs = data['subscribed_collections'];
        
        // Find the map where collection_id matches
        final itemToRemove = subs.firstWhere(
          (sub) => sub is Map<String, dynamic> && sub['collection_id'] == collectionId, 
          orElse: () => null
        );
        
        if (itemToRemove != null) {
          await userRef.update({
            'subscribed_collections': FieldValue.arrayRemove([itemToRemove])
          });
        }
      }
    }
  }

  Future<void> deleteCollection(String id) async {
    // 1. Koleksiyona ait tüm kelimeleri sil (cascade delete)
    //    Firestore batch maksimum 500 işlem destekler → 500'er parçalara bölerek sil
    final wordsSnapshot = await _db
        .collection('words')
        .where('collection_id', isEqualTo: id)
        .get();

    const batchLimit = 500;
    final docs = wordsSnapshot.docs;

    for (int i = 0; i < docs.length; i += batchLimit) {
      final batch = _db.batch();
      final chunk = docs.sublist(i, (i + batchLimit).clamp(0, docs.length));
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // 2. Koleksiyon belgesini sil
    await _db.collection('collections').doc(id).delete();
  }

  // =======================================================================
  // Global Words
  // =======================================================================

  Future<String> insertWord(Word word) async {
    final docRef = _db.collection('words').doc();
    final data = word.toMap();
    await docRef.set(data);
    return docRef.id;
  }

  Future<List<Word>> getWordsByCollection(String collectionId) async {
    final snapshot = await _db
        .collection('words')
        .where('collection_id', isEqualTo: collectionId)
        .get(const GetOptions(source: Source.serverAndCache));

    return snapshot.docs.map((doc) {
      return Word.fromMap(doc.data(), doc.id);
    }).toList();
  }

  Future<int> getWordCount(String collectionId) async {
    final snapshot = await _db
        .collection('words')
        .where('collection_id', isEqualTo: collectionId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<void> deleteWord(String id) async {
    await _db.collection('words').doc(id).delete();
  }

  // =======================================================================
  // Personal Telemetry Data (Answer Sheet)
  // =======================================================================

  Future<void> updateWordStats(String wordId, String collectionId) async {
    final uid = _userId;
    if (uid == null) return;

    final statRef = _db.collection('users').doc(uid).collection('word_stats').doc(wordId);
    
    // We use SetOptions(merge: true) because the document might not exist yet
    await statRef.set({
      'collection_id': collectionId,
      'view_count': FieldValue.increment(1),
      'last_reviewed_at': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  Future<void> addRatingToWord(String wordId, String collectionId, int rating) async {
    final uid = _userId;
    if (uid == null) return;

    final statRef = _db.collection('users').doc(uid).collection('word_stats').doc(wordId);

    // Again, merge in case the user has never viewed this word before but is rating it
    await statRef.set({
      'collection_id': collectionId,
      'my_ratings': FieldValue.arrayUnion([rating]),
    }, SetOptions(merge: true));
  }

  // =======================================================================
  // Search & Existence Checks
  // =======================================================================

  Future<bool> wordExists(String word) async {
    final uid = _userId;
    if (uid == null) return false;

    // This query might be expensive if not indexed properly for generic search,
    // but for exact match it's fine.
    // Note: Firestore is case-sensitive. We might need a 'word_lower' field for case-insensitive search.
    // For now, assume exact match or handle client side (inefficient).
    // Let's rely on exact match for existing logic or adding a normalized field later.
    final snapshot = await _db
        .collection('words')
        .where('word', isEqualTo: word)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<bool> wordAndMeaningExists(String word, String definition) async {
    final snapshot = await _db
        .collection('words')
        .where('word', isEqualTo: word)
        .where('definition', isEqualTo: definition)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // =======================================================================
  // Missing Methods for UI Compatibility

  Future<void> updateWord(Word word) async {
    if (word.id == null) return;

    // Convert to map and remove ID (it's the doc key)
    final data = word.toMap();

    await _db
        .collection('words')
        .doc(word.id)
        .update(data);
  }

  /// Kelime araması — her zaman caller'dan gelen collectionIds ile çalışır.
  /// search_page.dart bu ID'leri stream üzerinden önbelleğe alır (0 ekstra Firestore isteği).
  /// collectionIds boşsa hiç sorgu atılmaz.
  Future<List<Word>> searchWords(
    String query, {
    required List<String> collectionIds,
  }) async {
    if (collectionIds.isEmpty) return [];

    // ─── Kelimeleri çek (whereIn max 30 — 30'ar parçalara böl) ─────────────
    List<Word> allWords = [];
    const chunkSize = 30;

    for (int i = 0; i < collectionIds.length; i += chunkSize) {
      final chunk = collectionIds.sublist(
        i,
        (i + chunkSize).clamp(0, collectionIds.length),
      );
      final snap = await _db
          .collection('words')
          .where('collection_id', whereIn: chunk)
          .get();
      allWords.addAll(
        snap.docs.map((doc) => Word.fromMap(doc.data() as Map<String, dynamic>, doc.id)),
      );
    }

    // ─── Client-side text filtresi ──────────────────────────────────────────
    if (query.isEmpty) return allWords;

    final lowerQ = query.toLowerCase();
    return allWords.where((w) {
      return w.word.toLowerCase().contains(lowerQ) ||
          w.definition.toLowerCase().contains(lowerQ) ||
          w.translation.toLowerCase().contains(lowerQ);
    }).toList();
  }


  // =======================================================================
  // Streaks
  // =======================================================================

  Future<void> updateUserStreak() async {
    final uid = _userId;
    if (uid == null) return;

    final userRef = _db.collection('users').doc(uid);
    final now = DateTime.now();
    // Normalize to midnight to easily compare days
    final today = DateTime(now.year, now.month, now.day); 

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        transaction.set(userRef, {
          'streak': 1,
          'last_study_date': today.millisecondsSinceEpoch,
        });
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      int currentStreak = data['streak'] ?? 0;
      int? lastStudyTimestamp = data['last_study_date'];

      if (lastStudyTimestamp == null) {
        transaction.update(userRef, {
          'streak': 1,
          'last_study_date': today.millisecondsSinceEpoch,
        });
        return;
      }

      final lastStudyDate = DateTime.fromMillisecondsSinceEpoch(lastStudyTimestamp);
      final normalizedLastStudy = DateTime(lastStudyDate.year, lastStudyDate.month, lastStudyDate.day);

      final difference = today.difference(normalizedLastStudy).inDays;

      if (difference == 1) {
        // Studied yesterday, increment streak
        transaction.update(userRef, {
          'streak': currentStreak + 1,
          'last_study_date': today.millisecondsSinceEpoch,
        });
      } else if (difference > 1) {
        // Streak broken
        transaction.update(userRef, {
          'streak': 1,
          'last_study_date': today.millisecondsSinceEpoch,
        });
      }
      // If difference == 0, already studied today, do nothing.
    });
  }

  Stream<int> getUserStreakStream() {
    final uid = _userId;
    if (uid == null) return Stream.value(0);

    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return 0;
      
      final data = snapshot.data()!;
      int streak = data['streak'] ?? 0;
      int? lastStudyTimestamp = data['last_study_date'];
      
      if (lastStudyTimestamp != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final lastStudyDate = DateTime.fromMillisecondsSinceEpoch(lastStudyTimestamp);
        final normalizedLastStudy = DateTime(lastStudyDate.year, lastStudyDate.month, lastStudyDate.day);
        
        // If they missed yesterday and today, their streak in UI should show as reset
        if (today.difference(normalizedLastStudy).inDays > 1) {
          return 0;
        }
      }
      
      return streak;
    });
  }
}
