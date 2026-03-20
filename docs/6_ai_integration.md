# 6. Yapay Zeka Entegrasyonu (AI Integration)

Uygulama, hem kelime içeriklerini eğitici düzeyde otomatik zenginleştirmek, hem de OCR tarzı görüntü işleme işlemleri gerçekleştirmek üzere **OpenAI GPT** altyapısını kullanır. İşlemlerin tümü `lib/services/ai_service.dart` üzerinden yürütülür.

## 6.1. Temel Altyapı ve Yapılandırma
- **Kullanılan Paket**: `dart_openai` plugin'i.
- **Kullanılan Model**: `gpt-4o-mini` modeli tercih edilmiştir. (Hızlı yanıt verir, text ve vision (fotoğraf okuma) desteği vardır, maliyeti düşüktür).
- **Yetkilendirme**: Uygulamanın root alanındaki `.env` dosyası içinde `OPENAI_API_KEY` değişkeninde ortam anahtarı bulunur. Başlangıçta sistem bunu okur.

## 6.2. Akıllı Kelime Oluşturma (`generateSmartWord`)
Kullanıcılar uygulamaya yeni bir kelime eklerken (örneğin sadece "ambiguous" kelimesini girerek), anlamı veya çevirisi için uğraşmak yerine API'yi çağırır.

**İşleyiş:**
- Fonksiyon; hedeflenen `word`, kullanıcının verdiği bir cümle varsa `contextText`, paketin genel bağlamı (`contextType` - Academy, Cinema vs.) ve `wordType` parametrelerini kabul eder.
- AI'a özel bir `systemRole` bildirilir ("Sen profesyonel bir İngilizce eğitmenisin...").
- Prompt string'i hazırlanarak OpenAI Chat API çağrılır.
- **Yapısal Dönüşüm**: API ayarlarında `response_format: {"type": "json_object"}` zorlanır. Sistem prompt'unda da _"Çıktıyı 'word', 'definition', 'translation' objelerini içeren basit bir JSON olarak dön"_ talimatı vardır. Böylece dönen string, Flutter tarafında doğrudan `jsonDecode` fonksiyonuna sokulabilir ve modele çevrilir.

## 6.3. Görüntüden Kelime Okuma (`extractWordsFromImage`)
Kullanıcı kitap okurken bilmediği kelimelerin altını çizip fotoğrafını uygulamaya atar. Sistem bu altı çizili kelimeleri ayıklar. `ScanDialog` içinde çağrılır.

**İşlem Akışı:**
1. Kullanıcı `image_picker` ile bir resim (XFile) seçer.
2. Servis içindeki `extractWordsFromImage` fonksiyonunda bu resim byte array ve nihayetinde `base64` string'e dönüştürülür.
3. GPT-4o-mini'nin "Vision" (görsel destekli) modeli mesaja konulan base64 imaj objesi ile tetiklenir.
4. Prompt'ta özellikle "Resimdeki metne bak, sadece altı çizilmiş veya fosforluyla boyanmış (highlighted) kelimeleri ve etrafındaki bağlam cümlesini bul" emri verilir.
5. JSON Array halinde `[{ word: "...", context: "..." }]` çıktı döner.
6. Bu sözcükler `ScanDialog` içerisindeki arayüze checkbox listesi olarak dökülür; onaylananlar daha sonra otomatik olarak `generateSmartWord` üzerinden teker teker veritabanına push edilir.

## 6.4. Hata Yönetimi (Error Handling)
AI servislerinde oluşabilecek arızalar (OpenAI kredi limitinin bitmesi, kota aşımı (Rate Limit), Token sınırına takılma, Timeout veya modelin JSON dışında bir şey dönmesi) için şu yapı kuruludur:
1. İlgili fonksiyonlarda `try-catch` blokları bulunur.
2. Gelen spesifik hata, `AppLogger.error()` mekanizmasına detaylarıyla paslanır ki Firebase üzerinde sonradan incelenebilsin.
3. Hata sarmalanarak ekrana Flutter UI seviyesinde ulaşılabilecek temiz bir `Exception` (örn. "Yapay Zeka hizmetine geçici olarak ulaşılamıyor, lütfen tekrar deneyin.") olarak iletilir ve `Snackbar` ile kullanıcıya sunulur.
