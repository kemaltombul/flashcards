# 3. Veri Modelleri (Models)

Firestore dokümanlarını temsil eden ve JSON (Map) dönüşümlerini otomatik yapan Dart yapılarıdır. Proje genelinde nesne yönelimli erişim bu modeller vasıtasıyla sağlanır.

## 3.1. `Word` (`word.dart`)
Bir kelime/cümle veya ifade kartını (Flashcard) temsil eder.
- `id` (String?): Firestore doküman ID'si (Firestore'dan okununca atanır).
- `collectionId` (String): Bağlı bulunduğu koleksiyon ID.
- `word` (String): Kelimenin, kalıbın veya cümlenin kendisi.
- `definition` (String?): İngilizce veya genel detayı/tanımı.
- `translation` (String?): Türkçe veya hedeflenen ana dildeki karşılığı.
- `contextualInfo` (String?): Cümle içinde kullanımı, örnek bir diyalog veya gramer detayı. AI tarafından doldurulması hedeflenir.
- `createdAt` (DateTime?): Sisteme eklenme/oluşturulma zamanı.

## 3.2. `Collection` (`collection.dart`)
Kelimeleri gruplamak için kullanılan "koleksiyon" veya "paket" sınıflandırması. Rol/Yetki yönetimi bu sınıfın içerdiği bilgiler üzerinden yapılır.
- `id` (String?): Doküman ID'si.
- `name` (String): Koleksiyonun görünen adı.
- `ownerUid` (String): Koleksiyonu oluşturan kullanıcının Firebase UID'si (Sahiplik yetkisi).
- `isPublic` (bool): Diğer kullanıcılar tarafından "Search" ile bulunup abone olunabilir mi?
- `editorUids` (List<String>): Owner dışında, koleksiyona kelime ekleme, isim değiştirme, kelime silme yetkisi tanımlanmış kullanıcıların UID'leri.
- `category` (String?): AI kelime türetirken baz alacağı alan (Örn: "Academy", "Cinema", "Practical"). Context Type diye de geçer.
- `createdAt` (DateTime?): Oluşturulma tarihi.

## 3.3. `UserProfile` (`user_profile.dart`)
Kullanıcının sisteme ait kişisel bilgilerini ve genel başarı/hedef parametrelerini barındırır.
- `uid` (String): Firebase Auth benzersiz ID'si.
- `email` (String?): Google hesabından gelen e-posta adresi.
- `displayName` (String?): Profil adı (username).
- `photoUrl` (String?): Profil resmi bağlantısı.
- `dailyGoal` (int): Günlük öğrenilmesi/tekrar edilmesi hedeflenen kelime sayısı.
- `streakCount` (int): Kullanıcının aralıksız kaç gündür hedefi tutturduğu veya uygulamayı kullandığı (Seri / Streak).
- `lastStudyDate` (DateTime?): Streak hesaplamasını yönetmek için son çalışma zamanı.
- `isPremium` (bool): Pro/Abonelik özellikleri açıksa True döner.
- `createdAt` (DateTime?): Hesabın/profilin oluşturulma tarihi.

## 3.4. `WordTelemetry` (`word_telemetry.dart`)
Bir kullanıcının spesifik bir kelimeyle (Flashcard) olan bireysel öğrenme (Anki/SuperMemo) ilişkisini izler. Öğrencinin gelişimini ölçmek için esastır. `Word` objesi ayrı, `WordTelemetry` ayrı tutulur (İzinler ve paylaşım sebebiyle - herkesin öğrenme hızı farklı).
- `id` (String?): Dokümanın kendi ID'si.
- `uid` (String): Öğrenen kullanıcının UID'si.
- `wordId` (String): Hangi kelime öğreniliyor.
- `score` (int): Mevcut kalite/öğrenim skoru. Her başarılı/zayıf cevapta `ScoringService` bu puanı günceller.
- `viewCount` (int): Kullanıcının bu kelimeyle kaç kere karşılaştığı.
- `lastReviewed` (DateTime?): Kartın en son test edildiği/gösterildiği an.

## 3.5. `TelemetryData` (`telemetry_data.dart`)
Uygulamanın genel / global büyüme analizini yapmak veya metrik panoları oluşturmak için.
- `totalWordsAdded` (int)
- `totalStudySessions` (int)
- `totalAiGenerations` (int)
gibi alanlar barındırarak istatistik sağlar.
