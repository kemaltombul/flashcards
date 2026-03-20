/// BİLGİ PANOSU / KLASÖR (Collection)
/// 
/// Kelimeleri (Word) içinde barındıran salt (pure) bir veri kabıdır.
/// Bu model artık "Ben favori miyim?", "Ben oyun modunda mıyım?" gibi KİŞİSEL
/// tercihleri içinde tutmaz. Sadece ne olduğunu ve kime ait olduğunu bilir.
/// 
/// Firestore'daki yeri: `collections/{id}` (Artık users/uid/collections değil, herkesin görebilmesi için kök dizine de taşınabilir veya mevcut yapıda kalıp isShared ile yönetilebilir).
class Collection {
  /// Veritabanındaki belge (Document) ID'si
  final String? id; 
  
  /// Koleksiyonun adı (Örn: "YDS Kelimeleri", "Günlük İngilizce")
  final String name;
  
  /// Bu koleksiyonu SIFIRDAN YARATAN kişinin (Owner) Firestore User ID'si.
  /// (Eğer başkası bunu klonlarsa, klonlanan yeni kopyanın ownerId'si o kişi olur.)
  final String ownerId; 
  
  /// PAYLAŞIM DURUMU
  /// Eğer `true` ise, bu koleksiyon artık uygulamanın "Keşfet (Community)" sekmesinde 
  /// listelenebilir veya linki olan herkes tarafından "Abone Olunabilir" hale gelmiştir.
  final bool isShared; 
  
  /// URL tabanlı paylaşım (Deep-Link) veya WhatsApp'tan arkadaşa atılacak 
  /// 6 haneli kısa kod (Opsiyonel).
  final String? shareCode; 
  
  /// Editörlerin (Ortakların) kullanıcı ID'lerini (UID) tutar.
  final List<String> editorUids;  
  
  /// AI ÜRETİM MODU (Bağlam Tipi)
  /// Kelime üretilirken AI'ın neye odaklanacağını belirler:
  /// 'Academy', 'Cinema', 'Mnemonic', 'Practical'
  final String contextType;

  final DateTime? createdAt;

  Collection({
    this.id,
    required this.name,
    required this.ownerId,
    this.isShared = false,
    this.shareCode,
    this.editorUids = const [],
    this.contextType = 'Academy',
    this.createdAt,
  });

  /// Converts the Collection object to a Map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'owner_id': ownerId,
      'is_shared': isShared,
      'share_code': shareCode,
      'editor_uids': editorUids,
      'context_type': contextType,
      'created_at': createdAt?.millisecondsSinceEpoch,
    };
  }

  /// Creates a Collection object from a Map.
  factory Collection.fromMap(Map<String, dynamic> map, String docId) {
    return Collection(
      id: docId,
      name: map['name'] ?? '',
      ownerId: map['owner_id'] ?? '',
      isShared: map['is_shared'] ?? false,
      shareCode: map['share_code'],
      editorUids: List<String>.from(map['editor_uids'] ?? []),
      contextType: map['context_type'] ?? 'Academy',
      createdAt: map['created_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at']) 
          : null,
    );
  }
}
