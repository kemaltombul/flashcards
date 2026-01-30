/// Represents a vocabulary word with its definition, Turkish meaning, and example.
class Word {
  final String? id;
  final String collectionId;
  final String word;
  final String definition;
  final String meaningTr;
  final String example;
  final int viewCount;
  final int? lastReviewedAt; // Milliseconds timestamp
  final List<Map<String, dynamic>> userRatings; // List of {rating, log_id, timestamp}

  Word({
    this.id,
    required this.collectionId,
    required this.word,
    required this.definition,
    required this.meaningTr,
    required this.example,
    this.viewCount = 0,
    this.lastReviewedAt,
    this.userRatings = const [],
  });

  /// Converts the Word object to a Map for database storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collection_id': collectionId,
      'word': word,
      'definition': definition,
      'meaning_tr': meaningTr,
      'example': example,
      'view_count': viewCount,
      'last_reviewed_at': lastReviewedAt,
      'user_ratings': userRatings,
    };
  }

  /// Creates a Word object from a Map (e.g., from database query).
  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id']?.toString(), // Ensure String
      collectionId: map['collection_id']?.toString() ?? '', // Ensure String
      word: map['word'],
      definition: map['definition'],
      meaningTr: map['meaning_tr'] ?? '',
      example: map['example'] ?? '',
      viewCount: map['view_count'] ?? 0,
      lastReviewedAt: map['last_reviewed_at'],
      userRatings: List<Map<String, dynamic>>.from(map['user_ratings'] ?? []),
    );
  }

  /// Creates a copy of this Word but with the given fields replaced with the new values.
  Word copyWith({
    String? id,
    String? collectionId,
    String? word,
    String? definition,
    String? meaningTr,
    String? example,
    int? viewCount,
    int? lastReviewedAt,
    List<Map<String, dynamic>>? userRatings,
  }) {
    return Word(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      word: word ?? this.word,
      definition: definition ?? this.definition,
      meaningTr: meaningTr ?? this.meaningTr,
      example: example ?? this.example,
      viewCount: viewCount ?? this.viewCount,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      userRatings: userRatings ?? this.userRatings,
    );
  }
}