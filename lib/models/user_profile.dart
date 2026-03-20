/// KULLANICININ CÜZDANI (UserProfile)
///
/// Bu model, uygulamanın güvenlik (Authorization) ve kişiselleştirme (Personalization) beynidir.
/// Sistemdeki hiçbir "Koleksiyon" veya "Kelime", "Acaba ben kimin favorisiyim?" demez.
/// Tüm bu aidiyet ve yetki kontrolleri (Role-Based Access Control) merkezi olarak burada tutulur.
///
/// Firestore'daki yeri: `users/{uid}`
class UserProfile {
  /// Firebase Authentication servisinden gelen eşsiz Kime Ait (Unique ID) numarası.
  final String uid;

  /// Kullanıcı adı. Ortaklık davetlerinde kullanılır (Örn: player1234).
  final String? username;

  /// 1. FAVORİLERİM (My Favorites)
  /// Kullanıcının UI'da ⭐ ikonuna bastığı koleksiyonların sadece ID'lerini tutar.
  final List<String> favoriteCollectionIds;

  /// 2. ABONE OLUNAN / PAYLAŞILAN SÖZLEŞMELER (Subscribed Collections Contracts)
  /// Başka bir kullanıcının `isShared == true` yaptığı koleksiyonuna abone olunduğunda eklenir.
  final List<SubscribedCollection> subscribedCollections;

  /// 3. TOPLAM ÇALIŞMA SÜRESİ (Total Study Time)
  /// Milisaniye cinsinden toplam çalışma süresi.
  final int totalStudyTimeMs;

  /// 6. TOPLAM KART GÖRÜNTÜLEME (Total Cards Reviewed)
  ///
  /// Her kart geçişinde +1 artar. Kelime silinse dahi bu sayaç
  /// UserProfile üzerinde tutulduğu için veri kaybı olmaz.
  final int totalCardsReviewed;

  /// 4. STREAK (Günlük Çalışma Serisi)
  ///
  /// Kaç gün üst üste çalışıldığını tutar.
  /// - Her gün en az bir kez flashcard açılırsa streak artar.
  /// - Bir gün atlanırsa streak sıfırlanır (1'e döner).
  /// - Aynı gün birden fazla çalışma yapılırsa streak değişmez.
  final int streak;

  /// 5. SON ÇALIŞMA TARİHİ (Last Study Date)
  ///
  /// Streak hesaplaması için referans noktası.
  /// Saat/dakika bilgisi yok sayılır, sadece YIL-AY-GÜN karşılaştırması yapılır.
  /// Null ise kullanıcı hiç çalışmamış demektir.
  final DateTime? lastStudyDate;

  UserProfile({
    required this.uid,
    this.username,
    this.favoriteCollectionIds = const [],
    this.subscribedCollections = const [],
    this.totalStudyTimeMs = 0,
    this.totalCardsReviewed = 0,
    this.streak = 0,
    this.lastStudyDate,
  });

  /// Streak hesaplama mantığı modelin içinde — dışarıya saf veri çıkar.
  ///
  /// Bugün veya dün çalışıldıysa streak geçerlidir.
  /// 2+ gün ara varsa streak kopmuştur → 0 döner.
  int get currentStreak {
    if (lastStudyDate == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(
      lastStudyDate!.year,
      lastStudyDate!.month,
      lastStudyDate!.day,
    );
    final diff = today.difference(last).inDays;

    if (diff <= 1) return streak;
    return 0;
  }

  /// Bugün zaten çalışıldı mı? UI'da rozet göstermek için kullanılabilir.
  bool get studiedToday {
    if (lastStudyDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(
      lastStudyDate!.year,
      lastStudyDate!.month,
      lastStudyDate!.day,
    );
    return today.difference(last).inDays == 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'favorite_collection_ids': favoriteCollectionIds,
      'subscribed_collections':
          subscribedCollections.map((s) => s.toMap()).toList(),
      'total_study_time_ms': totalStudyTimeMs,
      'total_cards_reviewed': totalCardsReviewed,
      'streak': streak,
      'last_study_date': lastStudyDate?.millisecondsSinceEpoch,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final lastStudyTimestamp = map['last_study_date'];
    return UserProfile(
      uid: map['uid'] ?? '',
      username: map['username'],
      favoriteCollectionIds:
          List<String>.from(map['favorite_collection_ids'] ?? []),
      subscribedCollections:
          (map['subscribed_collections'] as List<dynamic>?)
                  ?.map((e) =>
                      SubscribedCollection.fromMap(e as Map<String, dynamic>))
                  .toList() ??
              [],
      totalStudyTimeMs: map['total_study_time_ms'] ?? 0,
      totalCardsReviewed: map['total_cards_reviewed'] ?? 0,
      streak: map['streak'] ?? 0,
      lastStudyDate: lastStudyTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(lastStudyTimestamp as int)
          : null,
    );
  }

  UserProfile copyWith({
    String? uid,
    String? username,
    List<String>? favoriteCollectionIds,
    List<SubscribedCollection>? subscribedCollections,
    int? totalStudyTimeMs,
    int? totalCardsReviewed,
    int? streak,
    DateTime? lastStudyDate,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      favoriteCollectionIds:
          favoriteCollectionIds ?? this.favoriteCollectionIds,
      subscribedCollections:
          subscribedCollections ?? this.subscribedCollections,
      totalStudyTimeMs: totalStudyTimeMs ?? this.totalStudyTimeMs,
      totalCardsReviewed: totalCardsReviewed ?? this.totalCardsReviewed,
      streak: streak ?? this.streak,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
    );
  }
}

/// ABONELİK SÖZLEŞMESİ / ÜYELİK KARTI (SubscribedCollection)
///
/// Bir "Koleksiyon ID'sini" ve senin o koleksiyona girerken takacağın "Şapkayı (Rolü)" tutar.
class SubscribedCollection {
  /// Hangi koleksiyon için sözleşme imzalandı?
  final String collectionId;

  /// Rol Yetkileri:
  /// - `reader` (Varsayılan): Kelimelere bakabilir, quiz çözebilir ama kelime ekleyemez/silemez.
  /// - `editor`: Koleksiyon sahibi yetki verdiyse kelime ekleyebilir.
  final String role;

  SubscribedCollection({
    required this.collectionId,
    this.role = 'reader',
  });

  Map<String, dynamic> toMap() {
    return {
      'collection_id': collectionId,
      'role': role,
    };
  }

  factory SubscribedCollection.fromMap(Map<String, dynamic> map) {
    return SubscribedCollection(
      collectionId: map['collection_id'] ?? '',
      role: map['role'] ?? 'reader',
    );
  }
}