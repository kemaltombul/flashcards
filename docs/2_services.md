# 2. Servisler (Services)

Uygulama genelinde firebase altyapısı ve dış API entegrasyonu (iş mantığı) `lib/services/` klasöründeki sınıflara dağıtılmıştır. 

## 2.1. `FirestoreService` (`firestore_service.dart`)
Tüm veritabanı CRUD işlemlerini yönetir. State management tarafında kullanılan `Stream`'lerin ana kaynağıdır.

**Kullanılan Temel Koleksiyonlar:**
- `users`: Kullanıcı profilleri, hedefler, premium durumları.
- `collections`: Tüm kullanıcıların oluşturduğu kelime koleksiyonları (`owner_uid`, `editor_uids`, `is_public` objeleri ile yetkilendirme).
- `words`: Koleksiyonlara bağlı kelimeler.
- `telemetry`: Uygulamanın genel kullanım istatistikleri.
- `user_telemetry`: Kullanıcıların sistemle etkileşim sayıları.
- `word_telemetries`: Kullanıcının bir kelimeyi ne kadar iyi öğrendiğini tutan spesifik istatistikler. Sub-collection yerine doğrudan bağımsız tasarlanmıştır.
- `logs`: `AppLogger` tarafından yollanan hata ve işlem kayıtları.

**Önemli Metodlar:**
- `initUserProfile(User user)`: Giriş yapıldığında kullanıcının veritabanında kaydı yoksa oluşturur.
- `getEditableCollectionsStream()`: Kullanıcının sahibi olduğu VEYA `editor_uids` listesinde bulunduğu koleksiyonları getirir.
- `insertWord(...)`, `updateWord(...)`: Kelime işlemleri.
- `updateWordTelemetry(...)`: Kullanıcının karta verdiği cevaba göre `word_telemetries` kaydını bulur/yaratır ve skoru (`ScoringService` üzerinden) günceller.
- `updateStreak(...)`: Son çalışma tarihine göre kullanıcının "streak" (seri) bilgisini günceller.

## 2.2. `AuthService` (`auth_service.dart`)
Kullanıcı kimlik doğrulama işlemlerini yönetir. Şu anda sadece **Google Sign-In** altyapısı aktiftir.

**Önemli Metodlar:**
- `signInWithGoogle()`: Google SDK üzerinden auth başlatır, başarılı olursa Firestore'da kullanıcı kaydı yaratır/günceller.
- `signOut()`: Çıkış yapar.
- `getCurrentUser()`: Aktif `firebase_auth` kullanıcısını döner.

## 2.3. `AIService` (`ai_service.dart`)
OpenAI GPT API entegrasyonu bölümüdür (`dart_openai` paketi ile). `OPENAI_API_KEY`'i `.env` dosyasından veya çalışma zamanından alır. Verilen girdilere göre "yapılandırılmış JSON" (`response_format: {"type": "json_object"}`) talep eder.

**Önemli Metodlar:**
- `generateSmartWord(word, contextText, collectionId, contextType, wordType)`: Sistemin prompt mimarisini kullanarak bir kelimenin tipini, açıklamasını ve bağlam cümlesini oluşturur.
- `extractWordsFromImage(XFile imageFile)`: Verileri `base64` encode edip Vision API ile okur ve görüntüdeki "altı çizili" veya "vurgulanmış" kelimeleri cümle bağlamıyla beraber bulup çıkartır.

## 2.4. `ScoringService` (`scoring_service.dart`)
Flashcard uygulamasının öğrenme mantığını barındırır. Kullanıcının bir kelimeyi öğrenme seviyesi bu algoritma ile hesaplanır.

**Metodlar:**
- `calculateNewScore(int currentScore, int rating)`: `rating` parametresi 1(Çok Zor) ile 4(Çok Kolay) arasındadır. Önceki skora bakarak yeni bir kalite skoru atar.

## 2.5. `AppLogger` (`app_logger.dart`)
Hem konsola basan hem de Firestore'un `logs` koleksiyonuna yazan sistem loglama servisi.

**Metodlar:**
- `info()`, `warning()`, `error()`: Log statüsüne göre çıktı verir. Kategori (`AUTH`, `DB`, `AI` vb.) belirterek loglama yapar. `LogsPage` ekranında bu loglar UI üzerinden filtrelenebilir.
