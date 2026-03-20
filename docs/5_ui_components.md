# 5. UI Bileşenleri ve Tema (UI Components)

Uygulamanın görsel dili **Glassmorphism** (buzlu cam / yarı saydam efektler) ve **Koyu Tema (Dark Mode)** prensipleri üzerine inşa edilmiştir. Tüm evrensel tema değişkenleri (renkler, font boyutları, boşluklar) merkezi bir dosyadan yönetilir.

## 5.1. Renk ve Sistem Sabitleri (`constants/app_theme.dart`)
Uygulamada standart Flutter/Material renkleri yerine sistem üzerinden HEX bazlı okunan özel renk kodları ve `Spacing`/`Radius` sabitleri bulunur.

- **Arkaplan Katmanları**: `primaryBackground` (`0xFF0F0F0F` - Koyu Siyah) ve pencereler için `secondaryBackground` (`0xFF1E1E1E` - Koyu Gri).
- **Cam (Glass) Katmanı**: `glassColor` (`0x14FFFFFF` - %8 opaklıkta beyaz renk).
- **Vurgu (Accent)**: `accentColor` (`0xFFD0BCFF` - Açık lavanta / mor tonu). Ana butonlarda, ikon durumlarında ve seçili sekmelerde vurgu olarak kullanılır.
- **Radius & Spacing**: Tasarım tutarlılığı için UI sayfalarında padding ve margin değerleri doğrudan rakam verilmek yerine (örn. `16.0`) `AppTheme.spacingM`, `AppTheme.radiusXl` vb. sabitleri kullanılarak verilir.
- **Durum Renkleri**: `successColor`, `errorColor`, `warningColor`, `infoColor`.

## 5.2. Tekrar Kullanılan Ortak Bileşenler (`widgets/`)

### `GlassCard` (`glass_card.dart`)
Sistemdeki tüm liste elemanlarının, Flashcard'ların arka yüzünün ve kutucukların yapısını oluşturan ana kapsayıcıdır.
- İçerisinde Dart/UI SDK'dan `ClipRRect` ve `BackdropFilter` `(ImageFilter.blur)` widget'ını kullanarak arka planda kalan UI elementlerinin veya resimlerin bulanık (blur) gözükmesini sağlar.
- Etrafına `app_theme.dart`'tan aldığı `glassDecoration` objesi aracılığıyla `%20` opaklıkta ince bir ışık çizgisi (border) çizer.

### `ZenInputField` (`zen_input_field.dart`)
Standart Material TextField elementinin Glassmorphism konseptine yedirilip kapsüllenmiş sürümüdür.
- Şeffaf arka plan, iç taraftaki blur efekti ve modern icon yerleşimi destekler.
- Focus durumlarında border efekti sağlar. `maxLines` destekler. Veri giriş kutuları genelde bu bileşenden miras alır.

### `CollectionSelector` (`collection_selector.dart`)
- Form sayfaları içinde (`AddWordPage` veya `ScanDialog` gibi) kullanıcının kelimeyi hangi koleksiyona kaydedeceğini seçmesini (Dropdown mantığında) sağlar.
- Standart `DropdownButton` yerine `CompositedTransformFollower` ve `OverlayEntry` ile ekranda diğer elementlerin hiyerarşik olarak *üstünde* çizilerek kendi özel açılır menüsünü yaratır.

### `MultiSelectDropdown` (`multi_select_dropdown.dart`)
- Birden çok değer seçimine izin veren ListBox / SelectBox varyantıdır. Liste içerisinde `CheckboxListTile` elemanları barındırır.
- Aramalarda birden fazla koleksiyonu veya etiketi filtrelemek için idealdir.

### `ExpandableSection` (`expandable_section.dart`)
- Sayfada akordeon menü mantığında, başlığına tıklandığında altındaki UI child elemanlarını `AnimatedSize` ile sarsıntısız bir şekilde genişleterek açıp kapatan yardımcı bileşendir. Sayfa içi karmaşayı azaltır.

## 5.3. Yardımcı Sınıflar (`utils/`)

### `SnackbarHelper` (`snackbar_helper.dart`)
- Hata, Başarı veya Bilgilendirme mesajlarının tüm uygulamada aynı font ve renk kalibresinde çıkmasını sağlar.
- Bütün sınıfların `ScaffoldMessenger.of(context).showSnackBar()` satırını uzun uzun yazması engellenmiştir.
- **Statik Metodları**: `showSuccess()`, `showError()`, `showWarning()`, `showInfo()`.
