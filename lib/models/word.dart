/// SÖZLÜK ÖĞESİ / İÇERİK (Word)
/// 
/// Sadece "Kelimenin ne olduğu" ve "Anlamının ne olduğu" bilgisini tutar.
/// Başlık (Collection) altındaki sayfalardır. Herkesin okuyabileceği "Ortak Soru Bankası" 
/// mantığıyla çalıştığı için, içinde KİŞİSEL öğrenme verileri (telemetri) KESİNLİKLE BULUNMAZ.
/// 
/// Bir kullanıcının bu kelimeyi kaç kere gördüğü veya zorlanıp zorlanmadığı
/// `WordTelemetry` modelinde ve `users/{uid}/word_stats` altında tutulur.
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

  Word({
    this.id,
    required this.collectionId,
    required this.word,
    required this.definition,
    required this.translation,
    required this.contextualInfo,
  });

  /// Converts the Word object to a Map for database storage.
  Map<String, dynamic> toMap() {
    return {
      'collection_id': collectionId,
      'word': word,
      'definition': definition,
      'translation': translation,
      'contextual_info': contextualInfo,
    };
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
  }) {
    return Word(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      word: word ?? this.word,
      definition: definition ?? this.definition,
      translation: translation ?? this.translation,
      contextualInfo: contextualInfo ?? this.contextualInfo,
    );
  }
}
