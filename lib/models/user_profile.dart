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
  /// Kullanıcının UI'da ⭐ (Yıldız / Kalp) ikonuna bastığı koleksiyonların sadece ID'lerini tutar.
  /// Bu ID'ler `myOwnedCollectionIds` içinden kendi listesi de olabilir, 
  /// `subscribedCollections` içinden başkasının listesi de olabilir.
  /// 
  /// Mimari Karar: Koleksiyon modellerine `isFavorite` koymak yerine buraya ayrı bir liste koyduk.
  /// Böylece Ahmet "YDS" listesini favorilerse, bu liste sadece Ahmet'in kendi cüzdanında yıldıza
  /// boyanır. Gerçek YDS listesinin veritabanı belgesi (Document) güncellenmez!
  final List<String> favoriteCollectionIds;

  /// 2. ABONE OLUNAN / PAYLAŞILAN SÖZLEŞMELER (Subscribed Collections Contracts)
  /// Başka bir kullanıcının `isShared == true` (Sokağa astığı) yaptığı koleksiyonuna tıkladığında
  /// "Abone Ol" dediğin anda kullanıcının cüzdanına bu "Sözleşme / Üyelik Kartı" objesi eklenir.
  /// 
  /// Veritabanından koleksiyonlar çekilirken sistem buraya bakar ve "Ha, bu kullanıcı şu ID'li 
  /// koleksiyona ERİŞEBİLİR, peki hangi YETKİYLE (Role) erişebilir?" sorusunu cevaplar.
  final List<SubscribedCollection> subscribedCollections;

  UserProfile({
    required this.uid,
    this.username,
    this.favoriteCollectionIds = const [],
    this.subscribedCollections = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'favorite_collection_ids': favoriteCollectionIds,
      'subscribed_collections': subscribedCollections.map((s) => s.toMap()).toList(),
    };
  }

  //???

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      username: map['username'],
      favoriteCollectionIds: List<String>.from(map['favorite_collection_ids'] ?? []),
      subscribedCollections: (map['subscribed_collections'] as List<dynamic>?)
              ?.map((e) => SubscribedCollection.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// ABONELİK SÖZLEŞMESİ / ÜYELİK KARTI (SubscribedCollection)
/// 
/// Bir "Koleksiyon ID'sini" ve senin o koleksiyona girerken takacağın "Şapkayı (Rolü)" tutar.
/// Google Drive veya Spotify'daki "Sen bu listeyi sadece dinleyebilirsin (reader) 
/// veya sen de şarkı ekleyebilirsin (editor)" mantığının (ACL - Access Control List) Dart halidir.
class SubscribedCollection {
  /// Hangi koleksiyon için sözleşme imzalandı?
  final String collectionId;
  
  /// Rol Yetkileri:
  /// - `reader` (Varsayılan): Kelimelere bakabilir, quiz çözebilir (telemetri üretebilir) ama YENİ kelime ekleyemez veya silemez.
  /// - `editor` (İleriki aşama): Koleksiyonun orijinal sahibi sana yetki verdiyse, sen de listeye yeni kelimeler GİREBİLİRSİN.
  final String role; // e.g., 'reader', 'editor'

  SubscribedCollection({
    required this.collectionId,
    this.role = 'reader', // Default role prevents accidental modifications
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
