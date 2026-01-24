/// Represents a vocabulary word with its definition, Turkish meaning, and example.
class Word {
  final int? id;
  final int collectionId;
  final String word;
  final String definition;
  final String meaningTr;
  final String example;
  final int viewCount;
  final int? lastReviewedAt; // Milliseconds timestamp

  Word({
    this.id,
    required this.collectionId,
    required this.word,
    required this.definition,
    required this.meaningTr,
    required this.example,
    this.viewCount = 0,
    this.lastReviewedAt,
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
    };
  }

  /// Creates a Word object from a Map (e.g., from database query).
  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      collectionId: map['collection_id'],
      word: map['word'],
      definition: map['definition'],
      meaningTr: map['meaning_tr'] ?? '',
      example: map['example'] ?? '',
      viewCount: map['view_count'] ?? 0,
      lastReviewedAt: map['last_reviewed_at'],
    );
  }

  /// Creates a copy of this Word but with the given fields replaced with the new values.
  Word copyWith({
    int? id,
    int? collectionId,
    String? word,
    String? definition,
    String? meaningTr,
    String? example,
    int? viewCount,
    int? lastReviewedAt,
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
    );
  }
}