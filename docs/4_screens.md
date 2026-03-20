# 4. Ekranlar (Screens & Dialogs)

Kullanıcının etkileşime girdiği UI sayfaları `lib/screens/` altında, pop-up pencereler (modal) ise `lib/dialogs/` altındadır. Çoğu sayfa kendi yerel state'ini yönetmek için `StatefulWidget` olarak tasarlanmıştır.

## 4.1. Ekranlar (Screens)

### `LoginPage` (`login_page.dart`)
- **Amacı**: Uygulamanın giriş/karşılama ekranı. Google hesaplarıyla oturum açmayı sağlar.
- **State Değişkenleri**: `_isLoading` (Giriş işlemi sürerken spinner göstermek için).
- **Çağırdığı Servisler**: `AuthService.signInWithGoogle()`.

### `MainPage` (`main_page.dart`)
- **Amacı**: Navigasyon menüsünü (BottomNavigationBar) barındıran temel iskelet sayfa. Alt sayfaları (Collections, Search, Profile) bir `PageView` içinde gösterir.
- **State Değişkenleri**: `_currentIndex` (Hangi tab'in açık olduğu), `_pageController`.
- **Özellik**: `AutomaticKeepAliveClientMixin` sayfaları sarmaladığı için sekmeler arası geçişte alt sayfaların iç state'i ve kaydırma (scroll) pozisyonu korunur.

### `CollectionsPage` (`collections_page.dart`)
- **Amacı**: Kullanıcının kendi koleksiyonlarını, editör olduğu paylaşımlı paketleri ve genel (public) hazır koleksiyonları farklı sekmelerde listeler.
- **State Değişkenleri**: `_tabController` (My Collections / Discover sekmeleri arasında geçiş için).
- **Çağırdığı Servisler**: 
  - `FirestoreService.getEditableCollectionsStream()`
  - `FirestoreService.getPublicCollectionsStream()` (veya eşleniği public listeleme fonksiyonu)
  - `FirestoreService.deleteCollection()`, `unsubscribeFromCollection()`
- **Kullandığı Dialoglar**: `AddCollectionDialog`, `RenameCollectionDialog`, `ManageEditorsDialog`.

### `FlashcardPage` (`flashcard_page.dart`)
- **Amacı**: Bir koleksiyon içindeki kelimeleri öğrenmek veya pratik yapmak için kart tabanlı (swipe/tap-to-reveal) pratik arayüzü.
- **State Değişkenleri**: `_currentIndex` (Hangi kelimede olduğu), `_isRevealed` (Kartın arkası / çevirisi gösterildi mi?), `_pageController`.
- **Veri Akışı**: 
  - `FirestoreService.wordsStream(collectionId)` üzerinden tüm kelimeler çekilir.
  - Kart cevaplandığında `FirestoreService.updateWordTelemetry(...)` çağrılır.
  - Test oturumu sonunda `FirestoreService.updateStreak(...)` güncellenir.
  - Puanlama için `ScoringService` kullanılır.

### `SearchPage` (`search_page.dart`)
- **Amacı**: Geniş çaplı kelime/cümle araması ve yönetimi.
- **State Değişkenleri**: `_searchController`, `_searchQuery`, `_selectedCollectionIds` (Sadece belirli paketlerde arama yapmak için filtre).
- **Kullanımı**: Girilen metne göre Firestore'dan gelen yerel memory içinde veya doğrudan Firestore sorgularıyla sonuçları süzer, GlassCard widget'ları halinde çizer.

### `ProfilePage` (`profile_page.dart`)
- **Amacı**: Kullanıcı avatarını, adını, günlük çalışma serisini (streak) ve hedeflerini gösteren profil ekranı.
- **Çağırdığı Servisler**: `AuthService.signOut()` oturumu kapatmak için. UI verisi genellikle `StreamBuilder` üzerinden beslenir.

### `AddWordPage` (`add_word_page.dart`)
- **Amacı**: Sisteme yeni kelime/cümle ekleme arayüzü. İki ana işlemi vardır: Manuel veri girişi veya Yapay Zeka desteğiyle "Akıllı" ekleme.
- **State Değişkenleri**: TextEditingController'lar (`word`, `translation` vb.), `_isLoading`, `_isAiGenerating`, `_selectedCollectionId`, `_contextType`.
- **Çağırdığı Servisler**: `AIService.generateSmartWord()`, `FirestoreService.insertWord()`.
- **Kullandığı Dialoglar**: `ScanDialog` (Manuel giriş yerine fotoğraftan okumak için).

### `LogsPage` (`logs_page.dart`)
- **Amacı**: (Admin) Sistem loglarını görüntüleme ve filtreleme amaçlı arayüz.
- **Özellik**: `FirestoreService` üzerinden log koleksiyonunu okuyarak developer debug arayüzü sunar.

---

## 4.2. Pop-up Pencereler (Dialogs)

- **`AddCollectionDialog`**: Yeni bir koleksiyon adı ve çalışma modu (Academy, Cinema vb.) isteyerek `FirestoreService.createCollection()` fonksiyonunu tetikler.
- **`RenameCollectionDialog`**: Mevcut koleksiyonun ID'sini alarak ismini günceller (`updateCollectionName`).
- **`ManageEditorsDialog`**: Sahibi olduğunuz koleksiyona başka bir kullanıcıyı "Editör" (Ekle/Değiştir/Sil yetkili) olarak eklemek veya silmek için kullanılır. `FirestoreService.addEditorByUsername()` çağırır.
- **`ScanDialog`**: Galeriden veya kameradan çekilen görseli (XFile) okur. `AIService.extractWordsFromImage()` kullanarak metindeki kelimeleri UI üzerine döker. Kullanıcının seçtiklerini iteratif olarak `generateSmartWord` üzerinden zenginleştirip `insertWord()` ile veritabanına kaydeder.
