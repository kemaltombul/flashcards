/// KİŞİSEL CEVAP KAĞIDI (WordTelemetry)
///
/// Kelimenin kendisi (Word modeli) herkesin görebileceği ortak bir "Soru Bankası" kitabıdır.
/// Bu model ise sadece o kullanıcıya ait olan, soru bankasındaki kelimelerin yanına
/// aldığı notlardır (Optik Form).
///
/// Firestore'daki yeri: `users/{uid}/word_stats/{wordId}`
/// Kelime ortak olsa bile, istatistikler ve öğrenme durumu tamamen KİŞİSELDİR (Private).
class WordTelemetry {
  /// Hangi kelimenin istatistiği tutuluyor? (Word document ID)
  final String wordId;

  /// Bu kelime hangi koleksiyonun altındaydı? (İleride "Ahmet YDS koleksiyonunda ne kadar ilerlemiş?"
  /// diye bir yüzde veya "Progress Bar" hesaplamak istersek sorguları hızlandırır.)
  final String collectionId;

  // -- KİŞİSEL ÖĞRENME VERİLERİ --

  /// Kullanıcı bu kelimeyi "Study (Flashcard)" veya "Game" modunda kaç kere gördü?
  final int viewCount;

  /// Kullanıcı bu kelimeyi EN SON ne zaman çalıştı?
  /// (Gelecekte Aralıklı Tekrar - Spaced Repetition / SRS algoritması yazmak istersek hayat kurtarır.)
  final DateTime? lastReviewedAt;

  /// Kullanıcının bu kelimeye verdiği "Zorluk/Kolaylık" puanları (Örn: 1 Çok Zor, 5 Çok Kolay)
  /// Sadece son durumu değil, kullanıcının gelişimini (Array / Liste olarak) izlemek için.
  final List<int> myRatings;

  WordTelemetry({
    required this.wordId,
    required this.collectionId,
    this.viewCount = 0,
    this.lastReviewedAt,
    this.myRatings = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'word_id': wordId,
      'collection_id': collectionId,
      'view_count': viewCount,
      'last_reviewed_at': lastReviewedAt?.millisecondsSinceEpoch,
      'my_ratings': myRatings,
    };
  }

  factory WordTelemetry.fromMap(Map<String, dynamic> map, String docId) {
    return WordTelemetry(
      wordId: docId,
      collectionId: map['collection_id'] ?? '',
      viewCount: map['view_count'] ?? 0,
      lastReviewedAt: map['last_reviewed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_reviewed_at'])
          : null,
      myRatings: List<int>.from(map['my_ratings'] ?? []),
    );
  }
}
