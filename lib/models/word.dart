/// SÖZLÜK ÖĞESİ / İÇERİK (Word)
///
/// Sadece "Kelimenin ne olduğu" ve "Anlamının ne olduğu" bilgisini tutar.
/// Başlık (Collection) altındaki sayfalardır. Herkesin okuyabileceği "Ortak Soru Bankası"
/// mantığıyla çalıştığı için, içinde KİŞİSEL öğrenme verileri (telemetri) KESİNLİKLE BULUNMAZ.
///
/// Bir kullanıcının bu kelimeyi kaç kere gördüğü veya zorlanıp zorlanmadığı
/// `WordTelemetry` modelinde ve `users/{uid}/word_stats` altında tutulur.

enum PartOfSpeech {
  noun,
  verb,
  adjective,
  adverb,
  pronoun,
  preposition,
  conjunction,
  interjection,
  phrasalVerb,
  idiom,
  collocation,
  proverb,
  unknown;

  static PartOfSpeech fromString(String? value) =>
      switch (value?.toLowerCase()) {
        'noun' => PartOfSpeech.noun,
        'verb' => PartOfSpeech.verb,
        'adjective' => PartOfSpeech.adjective,
        'adverb' => PartOfSpeech.adverb,
        'pronoun' => PartOfSpeech.pronoun,
        'preposition' => PartOfSpeech.preposition,
        'conjunction' => PartOfSpeech.conjunction,
        'interjection' => PartOfSpeech.interjection,
        'phrasal_verb' => PartOfSpeech.phrasalVerb,
        'idiom' => PartOfSpeech.idiom,
        'collocation' => PartOfSpeech.collocation,
        'proverb' => PartOfSpeech.proverb,
        _ => PartOfSpeech.unknown,
      };

  String get apiValue => switch (this) {
    PartOfSpeech.noun => 'noun',
    PartOfSpeech.verb => 'verb',
    PartOfSpeech.adjective => 'adjective',
    PartOfSpeech.adverb => 'adverb',
    PartOfSpeech.pronoun => 'pronoun',
    PartOfSpeech.preposition => 'preposition',
    PartOfSpeech.conjunction => 'conjunction',
    PartOfSpeech.interjection => 'interjection',
    PartOfSpeech.phrasalVerb => 'phrasal_verb',
    PartOfSpeech.idiom => 'idiom',
    PartOfSpeech.collocation => 'collocation',
    PartOfSpeech.proverb => 'proverb',
    PartOfSpeech.unknown => 'unknown',
  };

  String get label => switch (this) {
    PartOfSpeech.noun => 'Noun',
    PartOfSpeech.verb => 'Verb',
    PartOfSpeech.adjective => 'Adjective',
    PartOfSpeech.adverb => 'Adverb',
    PartOfSpeech.pronoun => 'Pronoun',
    PartOfSpeech.preposition => 'Preposition',
    PartOfSpeech.conjunction => 'Conjunction',
    PartOfSpeech.interjection => 'Interjection',
    PartOfSpeech.phrasalVerb => 'Phrasal Verb',
    PartOfSpeech.idiom => 'Idiom',
    PartOfSpeech.collocation => 'Collocation',
    PartOfSpeech.proverb => 'Proverb',
    PartOfSpeech.unknown => 'Unknown',
  };

  bool get isMultiWord =>
      this == PartOfSpeech.phrasalVerb ||
      this == PartOfSpeech.idiom ||
      this == PartOfSpeech.collocation ||
      this == PartOfSpeech.proverb;

  String get description => switch (this) {
    PartOfSpeech.noun => 'noun (e.g. "apple", "freedom")',
    PartOfSpeech.verb => 'verb (e.g. "run", "think")',
    PartOfSpeech.adjective => 'adjective (e.g. "quick", "beautiful")',
    PartOfSpeech.adverb => 'adverb (e.g. "quickly", "very")',
    PartOfSpeech.pronoun => 'pronoun (e.g. "he", "they")',
    PartOfSpeech.preposition => 'preposition (e.g. "in", "after")',
    PartOfSpeech.conjunction => 'conjunction (e.g. "and", "because")',
    PartOfSpeech.interjection => 'interjection (e.g. "wow", "ouch")',
    PartOfSpeech.phrasalVerb => 'phrasal verb (e.g. "give up", "break up")',
    PartOfSpeech.idiom => 'idiom (e.g. "once in a blue moon")',
    PartOfSpeech.collocation => 'collocation (e.g. "make a decision")',
    PartOfSpeech.proverb => 'proverb (e.g. "a stitch in time saves nine")',
    PartOfSpeech.unknown => 'unknown part of speech',
  };
}

class Word {
  /// Firestore doküman ID'si
  final String? id;

  /// Hangi Bilgi Panosunun (Collection) altında duruyor?
  final String collectionId;

  /// Flashcard'ın Ön Yüzü (İngilizce Kelime)
  final String word;

  /// Flashcard'ın Arka Yüzü: İngilizce Açıklama
  final String definition;

  /// Flashcard'ın Arka Yüzü: Hedef Dildeki Çevirisi (Örn: Türkçe Anlamı)
  /// Not: İleride farklı dillere genişleyebilmek için 'meaningTr' yerine 'translation' kullanıldı.
  final String translation;

  /// Flashcard'ın Arka Yüzü: Kullanıcının Seçimine Göre Değişen Ekstra Bilgi
  /// İleride bu alan örnek cümle (Example), eş anlamlı kelimeler (Synonyms)
  /// veya başka bir metinsel içerik olarak özelleştirilebilecek.
  final String contextualInfo;

  final PartOfSpeech partOfSpeech;

  Word({
    this.id,
    required this.collectionId,
    required this.word,
    required this.definition,
    required this.translation,
    required this.contextualInfo,
    this.partOfSpeech = PartOfSpeech.unknown,
  });

  /// Converts the Word object to a Map for database storage.
  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'collection_id': collectionId,
      'word': word,
      'definition': definition,
      'translation': translation,
      'contextual_info': contextualInfo,
    };
    if (partOfSpeech != PartOfSpeech.unknown) {
      data['part_of_speech'] = partOfSpeech.apiValue;
    }
    return data;
  }

  /// Creates a Word object from a Map (e.g., from database query).
  factory Word.fromMap(Map<String, dynamic> map, String docId) {
    return Word(
      id: docId,
      collectionId: map['collection_id']?.toString() ?? '', // Ensure String
      word: map['word'] ?? '',
      definition: map['definition'] ?? '',
      translation: map['translation'] ?? '',
      contextualInfo: map['contextual_info'] ?? '',
      partOfSpeech: PartOfSpeech.fromString(map['part_of_speech']?.toString()),
    );
  }

  /// Creates a copy of this Word but with the given fields replaced with the new values.
  Word copyWith({
    String? id,
    String? collectionId,
    String? word,
    String? definition,
    String? translation,
    String? contextualInfo,
    PartOfSpeech? partOfSpeech,
  }) {
    return Word(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      word: word ?? this.word,
      definition: definition ?? this.definition,
      translation: translation ?? this.translation,
      contextualInfo: contextualInfo ?? this.contextualInfo,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
    );
  }
}
