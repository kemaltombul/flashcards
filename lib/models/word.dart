/// Represents a vocabulary word with its definition, Turkish meaning, and example.
class Word {
  final int? id;
  final int collectionId;
  final String word;
  final String definition;
  final String meaningTr;
  final String example;

  Word({
    this.id,
    required this.collectionId,
    required this.word,
    required this.definition,
    required this.meaningTr,
    required this.example,
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
    );
  }
}