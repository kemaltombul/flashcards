import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/collection.dart';
import '../models/word.dart';
import '../models/telemetry_data.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper to get current User ID
  String? get _userId => _auth.currentUser?.uid;

  // =======================================================================
  // Collections
  // =======================================================================

  /// Creates a new collection under users/{uid}/collections
  Future<String> createCollection(String name, bool isGame) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    final docRef = _db.collection('users').doc(uid).collection('collections').doc();
    
    final collection = Collection(
      id: docRef.id,
      name: name,
      isGame: isGame,
      isFavorite: false,
    );

    // Add 'created_at' for sorting if needed
    final data = collection.toMap();
    data['created_at'] = FieldValue.serverTimestamp();

    await docRef.set(data);
    return docRef.id;
  }

  /// Get all collections for the current user
  Stream<List<Collection>> getCollectionsStream() {
    final uid = _userId;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('collections')
        .orderBy('is_favorite', descending: true)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Ensure ID is set
        return Collection.fromMap(data);
      }).toList();
    });
  }

  /// Get collections as Future (one-time fetch)
  Future<List<Collection>> getCollections() async {
    final uid = _userId;
    if (uid == null) return [];

    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('collections')
        .orderBy('is_favorite', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Collection.fromMap(data);
    }).toList();
  }

  Future<void> updateCollectionName(String id, String newName) async {
    final uid = _userId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('collections').doc(id).update({'name': newName});
  }

  Future<void> updateCollectionMode(String id, bool isGame) async {
    final uid = _userId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('collections').doc(id).update({'is_game': isGame ? 1 : 0});
  }

  Future<void> toggleFavorite(String id, bool currentStatus) async {
    final uid = _userId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('collections').doc(id).update({'is_favorite': currentStatus ? 0 : 1});
  }

  Future<void> deleteCollection(String id) async {
    final uid = _userId;
    if (uid == null) return;

    // 1. Delete the collection document
    await _db.collection('users').doc(uid).collection('collections').doc(id).delete();

    // 2. Delete all words associated with this collection
    // Note: This is a client-side batched delete. 
    // For large collections, cloud functions are better, but this is fine for now.
    final wordsQuery = await _db
        .collection('users')
        .doc(uid)
        .collection('words')
        .where('collection_id', isEqualTo: id)
        .get();

    final batch = _db.batch();
    for (var doc in wordsQuery.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // =======================================================================
  // Words
  // =======================================================================

  Future<String> insertWord(Word word) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    final docRef = _db.collection('users').doc(uid).collection('words').doc();
    
    // Create map and ensuring ID is null so we don't write it yet, 
    // or better, write it if we want redundancy.
    final data = word.toMap();
    data.remove('id'); // ID is the document ID
    data['created_at'] = FieldValue.serverTimestamp();

    await docRef.set(data);
    return docRef.id;
  }

  Future<List<Word>> getWordsByCollection(String collectionId) async {
    final uid = _userId;
    if (uid == null) return [];


    try {
      // Try fetching from server first to get latest
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('words')
          .where('collection_id', isEqualTo: collectionId)
          .get(const GetOptions(source: Source.serverAndCache));

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Word.fromMap(data);
      }).toList();
    } catch (e) {
      // If server fails (offline), fall back to cache explicitly if needed, 
      // though serverAndCache handles this mostly.
      // But purely for robustness:
      if (e is FirebaseException && e.code == 'unavailable') {
         final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('words')
          .where('collection_id', isEqualTo: collectionId)
          .get(const GetOptions(source: Source.cache));
          
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return Word.fromMap(data);
          }).toList();
      }
      rethrow;
    }
  }


  Future<int> getWordCount(String collectionId) async {
    final uid = _userId;
    if (uid == null) return 0;

    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('words')
        .where('collection_id', isEqualTo: collectionId)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  Future<void> deleteWord(String id) async {
    final uid = _userId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('words').doc(id).delete();
  }

  Future<void> updateWordStats(String wordId) async {
    final uid = _userId;
    if (uid == null) return;

    await _db.collection('users').doc(uid).collection('words').doc(wordId).update({
      'view_count': FieldValue.increment(1),
      'last_reviewed_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> addRatingToWord(String wordId, int rating, String logId) async {
    final uid = _userId;
    if (uid == null) return;

    final ratingData = {
      'rating': rating,
      'log_id': logId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await _db.collection('users').doc(uid).collection('words').doc(wordId).update({
      'user_ratings': FieldValue.arrayUnion([ratingData]),
    });
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
        .collection('users')
        .doc(uid)
        .collection('words')
        .where('word', isEqualTo: word)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<bool> wordAndMeaningExists(String word, String meaningTr) async {
    final uid = _userId;
    if (uid == null) return false;

    // Basic check for exact match on both
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('words')
        .where('word', isEqualTo: word)
        .where('meaning_tr', isEqualTo: meaningTr)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // =======================================================================
  // Missing Methods for UI Compatibility
  // =======================================================================

  Future<void> updateWord(Word word) async {
    final uid = _userId;
    if (uid == null || word.id == null) return;

    // Convert to map and remove ID (it's the doc key)
    final data = word.toMap();
    data.remove('id');
    
    await _db.collection('users').doc(uid).collection('words').doc(word.id).update(data);
  }

  /// Basic client-side search because Firestore doesn't support substring search natively.
  /// For production, use Algolia/Typesense. For this scale, fetch all or collection-based fetch is okay.
  Future<List<Word>> searchWords(String query, {List<String>? collectionIds}) async {
    final uid = _userId;
    if (uid == null) return [];

    Query queryRef = _db.collection('users').doc(uid).collection('words');

    // If specific collections selected, strictly we can use 'whereIn' if list < 10
    if (collectionIds != null && collectionIds.isNotEmpty) {
      if (collectionIds.length <= 10) {
        queryRef = queryRef.where('collection_id', whereIn: collectionIds);
      } else {
        // Fallback: fetch all and filter client side if list is huge (unlikely here)
        // For now, let's just not filter by collection in query if list is large
      }
    }

    final snapshot = await queryRef.get();
    
    final allWords = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return Word.fromMap(data);
    }).toList();

    if (query.isEmpty) return allWords;

    final lowerQ = query.toLowerCase();
    return allWords.where((w) {
      // Manual Filter for large collection lists if whereIn wasn't used
      if (collectionIds != null && collectionIds.isNotEmpty && collectionIds.length > 10) {
        if (!collectionIds.contains(w.collectionId)) return false;
      }
      
      return w.word.toLowerCase().contains(lowerQ) || 
             w.meaningTr.toLowerCase().contains(lowerQ) ||
             w.definition.toLowerCase().contains(lowerQ);
    }).toList();
  }

  Future<Map<String, int>> importWordsWithDeduplication(String collectionId, List<dynamic> jsonList) async {
    final uid = _userId;
    if (uid == null) return {'inserted': 0, 'skipped': 0};

    int inserted = 0;
    int skipped = 0;
    
    final batch = _db.batch();
    // Firestore allows max 500 writes per batch. For now assume list is small or we strictly commit every 500.
    // For simplicity, do one by one or small batches.
    
    for (var item in jsonList) {
      if (item is! Map<String, dynamic>) continue;
      
      String wordText = item['word'] ?? '';
      if (wordText.isEmpty) continue;

      // Check existence (inefficient loop but safe)
      bool exists = await wordExists(wordText);
      if (exists) {
        skipped++;
        continue;
      }

      final docRef = _db.collection('users').doc(uid).collection('words').doc();
      final word = Word(
        collectionId: collectionId,
        word: wordText,
        definition: item['definition'] ?? '',
        meaningTr: item['meaning_tr'] ?? '',
        example: item['example'] ?? '',
        id: null // docRef.id
      );
      
      final data = word.toMap();
      data.remove('id');
      data['created_at'] = FieldValue.serverTimestamp();

      batch.set(docRef, data);
      inserted++;
    }

    if (inserted > 0) {
      await batch.commit();
    }

    return {'inserted': inserted, 'skipped': skipped};
  }

  Future<String?> logTelemetry(TelemetryData log) async {
    final uid = _userId;
    if (uid == null) return null;
    
    // Logs are write-only usually, but let's store them
    final docRef = await _db
        .collection('users')
        .doc(uid)
        .collection('logs')
        .add(log.toMap());
        
    return docRef.id;
  }
}
