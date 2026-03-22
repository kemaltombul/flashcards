import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../models/collection.dart';
import '../models/word.dart';
import '../models/user_profile.dart';
import '../models/word_telemetry.dart';
import 'app_logger.dart';
import 'dart:math';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppLogger _log = AppLogger.instance;

  String? get _userId => _auth.currentUser?.uid;

  // ── Hata loglama yardımcıları ────────────────

  Never _fail(
    String operation,
    Object e,
    StackTrace st, {
    LogCategory category = LogCategory.firestore,
    Map<String, dynamic>? meta,
  }) {
    _logException(operation, e, st, category: category, meta: meta);
    throw e;
  }

  void _logStreamError(String operation, Object e, StackTrace? st) {
    _logException(operation, e, st, category: LogCategory.firestore);
  }

  void _logException(
    String operation,
    Object e,
    StackTrace? st, {
    LogCategory category = LogCategory.firestore,
    Map<String, dynamic>? meta,
  }) {
    final isPermissionDenied =
        e is FirebaseException && e.code == 'permission-denied';

    final enrichedMeta = <String, dynamic>{
      if (meta != null) ...meta,
      if (isPermissionDenied) 'firebase_code': 'permission-denied',
    };

    if (isPermissionDenied) {
      _log.critical(operation, e,
          category: category, stackTrace: st, meta: enrichedMeta);
    } else {
      _log.error(operation, e,
          category: category, stackTrace: st, meta: enrichedMeta);
    }
  }

  // =======================================================================
  // Users Profile & Subscriptions
  // =======================================================================

  Future<void> createUserProfile() async {
    const op = 'createUserProfile';
    final uid = _userId;
    if (uid == null) {
      _log.warning(op, 'Çağrıldı ama oturum açık değil.',
          category: LogCategory.auth);
      return;
    }

    try {
      final docRef = _db.collection('users').doc(uid);
      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        final randomNum = Random().nextInt(90000000) + 10000000;
        final profile = UserProfile(uid: uid, username: randomNum.toString());
        await docRef.set(profile.toMap());
      }
    } catch (e, st) {
      _fail(op, e, st, category: LogCategory.auth, meta: {'uid': uid});
    }
  }

  Stream<UserProfile?> getUserProfileStream() {
    final uid = _userId;
    if (uid == null) return Stream.value(null);

    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserProfile.fromMap(snapshot.data()!);
    }).handleError((e, st) {
      _logStreamError('getUserProfileStream', e, st as StackTrace?);
    });
  }

  Future<UserProfile?> getUserProfile() async {
    const op = 'getUserProfile';
    final uid = _userId;
    if (uid == null) return null;

    try {
      final snapshot = await _db.collection('users').doc(uid).get();
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserProfile.fromMap(snapshot.data()!);
    } catch (e, st) {
      _fail(op, e, st, meta: {'uid': uid});
    }
  }

  // =======================================================================
  // Global Collections
  // =======================================================================

  Future<String> createCollection(String name, bool isShared,
      {String contextType = 'Academy'}) async {
    const op = 'createCollection';
    final uid = _userId;
    if (uid == null) {
      _log.error(op, 'Oturum açık değil.', category: LogCategory.auth);
      throw Exception('User not logged in');
    }

    try {
      await createUserProfile();

      final docRef = _db.collection('collections').doc();
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
        contextType: contextType,
        createdAt: DateTime.now(),
      );

      await docRef.set(collection.toMap());
      return docRef.id;
    } catch (e, st) {
      _fail(op, e, st, meta: {'name': name, 'uid': uid});
    }
  }

  Stream<List<Collection>> getMyOwnedCollectionsStream() {
    final uid = _userId;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('collections')
        .where('owner_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Collection.fromMap(doc.data(), doc.id))
            .toList())
        .handleError((e, st) {
      _logStreamError('getMyOwnedCollectionsStream', e, st as StackTrace?);
    });
  }

  Stream<List<Collection>> getEditableCollectionsStream() {
    final uid = _userId;
    if (uid == null) return Stream.value([]);

    return Rx.combineLatest2(
      getMyOwnedCollectionsStream(),
      _db
          .collection('collections')
          .where('editor_uids', arrayContains: uid)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Collection.fromMap(doc.data(), doc.id))
              .toList()),
      (List<Collection> owned, List<Collection> editorSubs) {
        final combinedMap = <String, Collection>{};
        for (var c in owned) {
          combinedMap[c.id!] = c;
        }
        for (var c in editorSubs) {
          combinedMap[c.id!] = c;
        }
        final combined = combinedMap.values.toList();
        combined.sort((a, b) {
          final aTime = a.createdAt ?? DateTime(2000);
          final bTime = b.createdAt ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
        return combined;
      },
    ).handleError((e, st) {
      _logStreamError('getEditableCollectionsStream', e, st as StackTrace?);
    });
  }

  Future<String> addEditorByUsername(
      String collectionId, String targetUsername) async {
    const op = 'addEditorByUsername';
    final uid = _userId;
    if (uid == null) return 'Not logged in';

    try {
      final userSnap = await _db
          .collection('users')
          .where('username', isEqualTo: targetUsername)
          .limit(1)
          .get();

      if (userSnap.docs.isEmpty) {
        _log.warning(op, '"$targetUsername" kullanıcısı bulunamadı.',
            meta: {'collection_id': collectionId});
        return "User with username '$targetUsername' not found";
      }

      final targetUid = userSnap.docs.first.id;
      if (targetUid == uid) return 'You cannot add yourself';

      await _db.collection('collections').doc(collectionId).update({
        'editor_uids': FieldValue.arrayUnion([targetUid]),
      });

      return 'Success';
    } catch (e, st) {
      _log.error(op, e,
          stackTrace: st,
          meta: {
            'collection_id': collectionId,
            'target_username': targetUsername
          });
      return 'Firebase Error: $e';
    }
  }

  Future<void> removeEditorFromCollection(
      String collectionId, String targetUid) async {
    const op = 'removeEditorFromCollection';
    try {
      await _db.collection('collections').doc(collectionId).update({
        'editor_uids': FieldValue.arrayRemove([targetUid]),
      });
    } catch (e, st) {
      _fail(op, e, st,
          meta: {'collection_id': collectionId, 'target_uid': targetUid});
    }
  }

  Stream<List<Collection>> getSubscribedCollectionsStream(UserProfile profile) {
    if (profile.subscribedCollections.isEmpty) return Stream.value([]);

    final subIds =
        profile.subscribedCollections.map((s) => s.collectionId).toList();
    final chunks = <List<String>>[];
    for (var i = 0; i < subIds.length; i += 10) {
      chunks.add(subIds.sublist(
          i, i + 10 > subIds.length ? subIds.length : i + 10));
    }

    final streamList = chunks.map((chunk) {
      return _db
          .collection('collections')
          .where(FieldPath.documentId, whereIn: chunk)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => Collection.fromMap(doc.data(), doc.id)));
    }).toList();

    return Rx.combineLatestList(streamList)
        .map((listOfLists) => listOfLists.expand((list) => list).toList())
        .handleError((e, st) {
      _logStreamError('getSubscribedCollectionsStream', e, st as StackTrace?);
    });
  }

  Future<bool> subscribeByShareCode(String shareCode) async {
    const op = 'subscribeByShareCode';
    final uid = _userId;
    if (uid == null) return false;

    try {
      final snapshot = await _db
          .collection('collections')
          .where('share_code', isEqualTo: shareCode.toUpperCase().trim())
          .where('is_shared', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _log.warning(op, 'Geçersiz veya private share kodu.',
            meta: {'share_code': shareCode});
        return false;
      }

      final collectionDoc = snapshot.docs.first;
      final collectionId = collectionDoc.id;
      final data = collectionDoc.data();

      if (data['owner_id'] == uid) {
        _log.warning(op, 'Kullanıcı kendi koleksiyonuna abone olmaya çalıştı.',
            meta: {'collection_id': collectionId});
        return false;
      }

      final userSnap = await _db.collection('users').doc(uid).get();
      if (userSnap.exists) {
        final existingSubs =
            userSnap.data()?['subscribed_collections'] as List<dynamic>? ?? [];
        final alreadySubscribed = existingSubs.any(
          (s) =>
              s is Map<String, dynamic> && s['collection_id'] == collectionId,
        );
        if (alreadySubscribed) return true;
      }

      final newSub =
          SubscribedCollection(collectionId: collectionId, role: 'reader');
      await _db.collection('users').doc(uid).update({
        'subscribed_collections':
            FieldValue.arrayUnion([newSub.toMap()]),
      });

      return true;
    } catch (e, st) {
      _log.error(op, e, stackTrace: st, meta: {'share_code': shareCode});
      return false;
    }
  }

  Future<void> updateCollectionName(String id, String newName) async {
    const op = 'updateCollectionName';
    try {
      await _db.collection('collections').doc(id).update({'name': newName});
    } catch (e, st) {
      _fail(op, e, st, meta: {'collection_id': id, 'new_name': newName});
    }
  }

  Future<void> updateCollectionVisibility(String id, bool isShared) async {
    const op = 'updateCollectionVisibility';
    try {
      await _db
          .collection('collections')
          .doc(id)
          .update({'is_shared': isShared});
    } catch (e, st) {
      _fail(op, e, st, meta: {'collection_id': id, 'is_shared': isShared});
    }
  }

  Future<void> toggleFavorite(String id, bool isCurrentlyFavorite) async {
    const op = 'toggleFavorite';
    final uid = _userId;
    if (uid == null) return;

    try {
      final userRef = _db.collection('users').doc(uid);
      if (isCurrentlyFavorite) {
        await userRef
            .update({'favorite_collection_ids': FieldValue.arrayRemove([id])});
      } else {
        await userRef
            .update({'favorite_collection_ids': FieldValue.arrayUnion([id])});
      }
    } catch (e, st) {
      _fail(op, e, st,
          meta: {'collection_id': id, 'was_favorite': isCurrentlyFavorite});
    }
  }

  Future<void> unsubscribeFromCollection(String collectionId) async {
    const op = 'unsubscribeFromCollection';
    final uid = _userId;
    if (uid == null) return;

    try {
      final userRef = _db.collection('users').doc(uid);
      final snapshot = await userRef.get();

      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data.containsKey('subscribed_collections')) {
          final subs = data['subscribed_collections'] as List<dynamic>;
          final itemToRemove = subs.firstWhere(
            (sub) =>
                sub is Map<String, dynamic> &&
                sub['collection_id'] == collectionId,
            orElse: () => null,
          );
          if (itemToRemove != null) {
            await userRef.update({
              'subscribed_collections':
                  FieldValue.arrayRemove([itemToRemove]),
            });
          }
        }
      }
    } catch (e, st) {
      _fail(op, e, st, meta: {'collection_id': collectionId});
    }
  }

  Future<void> deleteCollection(String id) async {
    const op = 'deleteCollection';
    try {
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

      await _db.collection('collections').doc(id).delete();
    } catch (e, st) {
      _fail(op, e, st, meta: {'collection_id': id});
    }
  }

  // =======================================================================
  // Global Words
  // =======================================================================

  Future<String> insertWord(Word word) async {
    const op = 'insertWord';
    try {
      final docRef = _db.collection('words').doc();
      await docRef.set(word.toMap());
      return docRef.id;
    } catch (e, st) {
      _fail(op, e, st,
          meta: {'word': word.word, 'collection_id': word.collectionId});
    }
  }

  Future<List<Word>> getWordsByCollection(String collectionId) async {
    const op = 'getWordsByCollection';
    try {
      final snapshot = await _db
          .collection('words')
          .where('collection_id', isEqualTo: collectionId)
          .get(const GetOptions(source: Source.serverAndCache));

      return snapshot.docs
          .map((doc) => Word.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e, st) {
      _fail(op, e, st, meta: {'collection_id': collectionId});
    }
  }

  Future<int> getWordCount(String collectionId) async {
    const op = 'getWordCount';
    try {
      final snapshot = await _db
          .collection('words')
          .where('collection_id', isEqualTo: collectionId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e, st) {
      _fail(op, e, st, meta: {'collection_id': collectionId});
    }
  }

  Future<void> deleteWord(String id) async {
    const op = 'deleteWord';
    try {
      await _db.collection('words').doc(id).delete();
    } catch (e, st) {
      _fail(op, e, st, meta: {'word_id': id});
    }
  }

  Future<void> updateWord(Word word) async {
    const op = 'updateWord';
    if (word.id == null) return;
    try {
      await _db.collection('words').doc(word.id).update(word.toMap());
    } catch (e, st) {
      _fail(op, e, st, meta: {'word_id': word.id, 'word': word.word});
    }
  }

  // =======================================================================
  // Personal Telemetry
  // =======================================================================

  Future<void> updateWordStats(String wordId, String collectionId,
      {int durationMs = 0}) async {
    const op = 'updateWordStats';
    final uid = _userId;
    if (uid == null) return;

    try {
      final userRef = _db.collection('users').doc(uid);
      final statRef = userRef.collection('word_stats').doc(wordId);

      // Kart görüntüleme kaydı (word_stats subcollection)
      await statRef.set({
        'collection_id': collectionId,
        'view_count': FieldValue.increment(1),
        'last_reviewed_at': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

      // UserProfile üzerinde toplam sayaçları güncelle
      // total_cards_reviewed: kelime silinse bile kaybolmaz
      final Map<String, dynamic> profileUpdate = {
        'total_cards_reviewed': FieldValue.increment(1),
      };
      if (durationMs > 0) {
        profileUpdate['total_study_time_ms'] = FieldValue.increment(durationMs);
      }
      await userRef.update(profileUpdate);
    } catch (e, st) {
      _fail(op, e, st,
          meta: {'word_id': wordId, 'collection_id': collectionId});
    }
  }

  Future<void> addRatingToWord(
      String wordId, String collectionId, int rating) async {
    const op = 'addRatingToWord';
    final uid = _userId;
    if (uid == null) return;

    try {
      final statRef = _db
          .collection('users')
          .doc(uid)
          .collection('word_stats')
          .doc(wordId);
      await statRef.set({
        'collection_id': collectionId,
        'my_ratings': FieldValue.arrayUnion([rating]),
      }, SetOptions(merge: true));
    } catch (e, st) {
      _fail(op, e, st,
          meta: {
            'word_id': wordId,
            'collection_id': collectionId,
            'rating': rating
          });
    }
  }

  Future<int> getStudiedWordsCount() async {
    const op = 'getStudiedWordsCount';
    final uid = _userId;
    if (uid == null) return 0;

    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('word_stats')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e, st) {
      _fail(op, e, st, meta: {'uid': uid});
    }
  }

  /// Kullanıcının toplam kaç kart görüntülediğini döndürür.
  /// Her kart geçişinde view_count artırıldığı için bu değer
  /// toplam flashcard görüntüleme sayısını verir.
  Future<int> getTotalCardsReviewed() async {
    const op = 'getTotalCardsReviewed';
    final uid = _userId;
    if (uid == null) return 0;

    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('word_stats')
          .get();

      int total = 0;
      for (final doc in snapshot.docs) {
        total += (doc.data()['view_count'] as int? ?? 0);
      }
      return total;
    } catch (e, st) {
      _fail(op, e, st, meta: {'uid': uid});
    }
  }

  // =======================================================================
  // Search & Existence Checks
  // =======================================================================

  Future<bool> wordExists(String word) async {
    const op = 'wordExists';
    final uid = _userId;
    if (uid == null) return false;

    try {
      final snapshot = await _db
          .collection('words')
          .where('word', isEqualTo: word)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e, st) {
      _fail(op, e, st, meta: {'word': word});
    }
  }

  Future<bool> wordAndMeaningExists(String word, String definition) async {
    const op = 'wordAndMeaningExists';
    try {
      final snapshot = await _db
          .collection('words')
          .where('word', isEqualTo: word)
          .where('definition', isEqualTo: definition)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e, st) {
      _fail(op, e, st, meta: {'word': word});
    }
  }

  Future<List<Word>> searchWords(String query,
      {required List<String> collectionIds}) async {
    const op = 'searchWords';
    if (collectionIds.isEmpty) return [];

    try {
      List<Word> allWords = [];
      const chunkSize = 30;

      for (int i = 0; i < collectionIds.length; i += chunkSize) {
        final chunk = collectionIds.sublist(
            i, (i + chunkSize).clamp(0, collectionIds.length));
        final snap = await _db
            .collection('words')
            .where('collection_id', whereIn: chunk)
            .get();
        allWords
            .addAll(snap.docs.map((doc) => Word.fromMap(doc.data(), doc.id)));
      }

      if (query.isEmpty) return allWords;
      final lowerQ = query.toLowerCase();
      return allWords.where((w) {
        return w.word.toLowerCase().contains(lowerQ) ||
            w.definition.toLowerCase().contains(lowerQ) ||
            w.translation.toLowerCase().contains(lowerQ);
      }).toList();
    } catch (e, st) {
      _fail(op, e, st,
          meta: {'query': query, 'collection_count': collectionIds.length});
    }
  }

  // =======================================================================
  // Streaks
  // =======================================================================

  /// Flashcard sayfası açıldığında çağrılır.
  ///
  /// - Bugün zaten çalışıldıysa → hiçbir şey yapma (idempotent)
  /// - Dün çalışıldıysa        → streak + 1
  /// - 2+ gün ara verdiyse     → streak = 1 (yeniden başla)
  /// - Hiç çalışmadıysa        → streak = 1
  Future<void> updateUserStreak() async {
    const op = 'updateUserStreak';
    final uid = _userId;
    if (uid == null) return;

    try {
      final userRef = _db.collection('users').doc(uid);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        // Kullanıcı dokümanı yoksa sıfırdan başlat
        if (!snapshot.exists || snapshot.data() == null) {
          transaction.set(
              userRef,
              {
                'streak': 1,
                'last_study_date': today.millisecondsSinceEpoch,
              },
              SetOptions(merge: true));
          return;
        }

        final data = snapshot.data()!;
        final int currentStreak = data['streak'] ?? 0;
        final int? lastTimestamp = data['last_study_date'];

        // Eski kullanıcı: streak alanı hiç oluşturulmamış
        // veya hiç çalışmamış → streak = 1 ile başlat
        if (lastTimestamp == null) {
          transaction.update(userRef, {
            'streak': 1,
            'last_study_date': today.millisecondsSinceEpoch,
          });
          return;
        }

        final lastDate = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
        final normalizedLast =
            DateTime(lastDate.year, lastDate.month, lastDate.day);
        final diff = today.difference(normalizedLast).inDays;

        if (diff == 0) {
          // Bugün zaten çalışıldı → dokunma
          return;
        } else if (diff == 1) {
          // Dün çalışıldı → streak devam ediyor
          transaction.update(userRef, {
            'streak': currentStreak + 1,
            'last_study_date': today.millisecondsSinceEpoch,
          });
        } else {
          // 2+ gün ara → streak koptu, yeniden başla
          transaction.update(userRef, {
            'streak': 1,
            'last_study_date': today.millisecondsSinceEpoch,
          });
        }
      });
    } catch (e, st) {
      _fail(op, e, st, meta: {'uid': uid});
    }
  }

  /// Streak'i reaktif olarak dinler.
  ///
  /// UserProfile.currentStreak getter'ı kopukluk kontrolünü zaten yapar.
  Stream<int> getUserStreakStream() {
    final uid = _userId;
    if (uid == null) return Stream.value(0);

    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return 0;
      final profile = UserProfile.fromMap(snapshot.data()!);
      return profile.currentStreak;
    }).handleError((e, st) {
      _logStreamError('getUserStreakStream', e, st as StackTrace?);
    });
  }
}