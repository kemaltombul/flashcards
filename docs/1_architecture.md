# 1. Genel Mimari ve Yapı (Architecture)

## 1.1. Temel Yaklaşım
Bu proje, modern ve temiz bir UI (Glassmorphism) ile desteklenmiş, doğrudan **Firebase (Firestore & Auth)** servisleriyle konuşan, sunucusuz (serverless) bir Flutter uygulamasıdır. 
Geliştirme sürecinde karmaşık state yönetim kütüphaneleri (Provider, Riverpod, BLoC vb.) **kullanılmamıştır**. Bunun yerine Flutter'ın yerleşik asenkron yetenekleri ve basit state mekanizmaları tercih edilmiştir.

## 1.2. State Management (Durum Yönetimi)
Projede asenkron veri akışı ve state yönetimi şu şekilde sağlanmaktadır:
- **`StatefulWidget` ve `setState`**: Sayfa içi anlık durum değişiklikleri (örn. form girdileri, UI geçişleri, animasyon tetikleyicileri) için.
- **`StreamBuilder` ve `FutureBuilder`**: Firestore'dan gelen asenkron okumalar ve anlık veri güncellemeleri (real-time listeners) için sayfaların temelini oluşturur.
- **`rxdart` (`CombineLatestStream`)**: Birden fazla Firestore stream'ini (örn. farklı koleksiyonları, paylaşılanları ve özel istatistikleri) tek bir stream'de senkronize edip UI'a sunmak için kullanılmıştır (Özellikle ana akışta / MainPage seviyesinde).

## 1.3. Firebase Entegrasyonu
- **Authentication**: `AuthService` üzerinden **Google Sign-In** altyapısı aktiftir.
- **Cloud Firestore**: Uygulamanın ana veri kaynağıdır. Servis katmanı (`FirestoreService`) üzerinden tüm CRUD işlemleri yürütülür. Veritabanı yapısında `users`, `collections`, `words`, `telemetry`, `user_telemetry` ve `logs` gibi global koleksiyonlar kullanılmaktadır. Sahiplik (ownership), paylaşımlı koleksiyon yapısı ve editör (editor_uids) mantığı global koleksiyonlar içindeki field'lar üzerinden yönetilmektedir.

## 1.4. Kod Hiyerarşisi (Klasör Yapısı)
Projenin ana dizin yapısı (`lib/`) sorumluluklara göre ayrılmıştır:

- **`constants/`**: Uygulamanın genel tema ayarları, renk paleti, tipografi, ölçüler ve radius gibi statik değerleri (`app_theme.dart`). Tasarım sisteminin (Design System) temelidir.
- **`dialogs/`**: Kullanıcı etkileşimi gerektiren pop-up bileşenleri (`add_collection_dialog.dart`, `manage_editors_dialog.dart`, `scan_dialog.dart` vb.).
- **`models/`**: Firestore dokümanlarını Dart nesnelerine eşleyen veri sınıfları (`Word`, `Collection`, `UserProfile`, `TelemetryData`, `WordTelemetry` vb.). `fromJson` ve `toJson` metodlarını içerir.
- **`screens/`**: Tam ekran kullanıcı arayüzleri (`LoginPage`, `MainPage`, `FlashcardPage` vb.). Bu sayfalar servis katmanını tüketir ve UI state'ini tutar.
- **`services/`**: Dış kaynaklarla etkileşimi tek noktada toplayan iş katmanı:
  - `AuthService`: Giriş/çıkış operasyonları.
  - `FirestoreService`: Veritabanı sorguları ve doküman manipülasyonları.
  - `AIService`: OpenAI entegrasyonu, resimden metin çıkartma (Vision) ve bağlama uygun kelime oluşturma.
  - `AppLogger`: Sistem loglarının Firebase'e ve konsola yazılması.
  - `ScoringService`: Kelime bilinme durumuna göre kalite skorunun hesaplanması (SuperMemo esintili algoritma).
- **`utils/`**: Genel amaçlı yardımcı fonksiyonlar (Örn: `SnackbarHelper` ile tutarlı bildirimler).
- **`widgets/`**: Projeye özgü, birden fazla ekranda tekrar tekrar kullanılan, tasarımı standartlaştırılmış UI bileşenleridir (`GlassCard`, `ZenInputField`, `CollectionSelector`, `MultiSelectDropdown` vb.).
