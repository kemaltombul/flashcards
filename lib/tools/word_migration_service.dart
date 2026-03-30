import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/word.dart';
import '../services/ai_service.dart';

/// Veritabanındaki tüm kelimeleri yeni lemmatization kurallarına uyacak
/// şekilde AI üzerinden yeniden işleyen migration servisi.
///
/// Kullanım:
///   final migrator = WordMigrationService();
///   await migrator.run(onProgress: (done, total, log) { ... });
class WordMigrationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AIService? _ai;

  AIService get _aiService {
    _ai ??= AIService();
    return _ai!;
  }

  /// Migration'ı çalıştırır.
  ///
  /// [dryRun]     : true ise Firestore'a yazma yapmaz, sadece loglar.
  /// [delayMs]    : Her AI isteği arasındaki bekleme (ms). Rate limit için.
  /// [onProgress] : (tamamlanan, toplam, log mesajı) callback'i.
  ///
  /// Döndürür: [MigrationReport]
  Future<MigrationReport> run({
    bool dryRun = false,
    int delayMs = 1200,
    void Function(int done, int total, String log)? onProgress,
  }) async {
    final report = MigrationReport(dryRun: dryRun);

    // 1. Tüm kelimeleri çek
    onProgress?.call(0, 0, '📦 Kelimeler Firestore\'dan çekiliyor...');
    final snapshot = await _db.collection('words').get();
    final docs = snapshot.docs;
    final total = docs.length;

    if (total == 0) {
      onProgress?.call(0, 0, '⚠️ Veritabanında hiç kelime bulunamadı.');
      return report;
    }

    onProgress?.call(0, total, '🔢 Toplam $total kelime bulundu. Başlıyor...');

    // 2. Koleksiyon bilgilerini (contextType) çek — cache'le
    final collectionCache = <String, String>{};

    // 3. Her kelime için işle
    for (int i = 0; i < docs.length; i++) {
      final doc = docs[i];
      final data = doc.data();
      final word = Word.fromMap(data, doc.id);

      if (word.word.isEmpty) {
        report.skipped++;
        onProgress?.call(
          i + 1,
          total,
          '⏭️ [${i + 1}/$total] Boş kelime atlandı (id: ${doc.id})',
        );
        continue;
      }

      // Koleksiyonun contextType'ını bul
      final contextType = await _getContextType(
        word.collectionId,
        collectionCache,
      );

      try {
        onProgress?.call(
          i + 1,
          total,
          '🤖 [${i + 1}/$total] İşleniyor: "${word.word}" ($contextType)',
        );

        final updated = await _aiService.generateSmartWord(
          word.word,
          word.contextualInfo.isNotEmpty ? word.contextualInfo : null,
          word.collectionId,
          contextType: contextType,
          providedPartOfSpeech: word.partOfSpeech.apiValue,
        );

        if (!dryRun) {
          // Mevcut id'yi koru, diğer alanları güncelle
          final updatedWord = updated.copyWith(id: word.id);
          await _db.collection('words').doc(word.id).update(updatedWord.toMap());
        }

        final changed = _describeChanges(word, updated);
        report.success++;
        report.logs.add(
          '✅ [${i + 1}/$total] "${word.word}" → "${updated.word}"'
          '${changed.isNotEmpty ? " ($changed)" : ""}',
        );
        onProgress?.call(
          i + 1,
          total,
          '✅ "${word.word}" → "${updated.word}"'
          '${changed.isNotEmpty ? " | $changed" : ""}',
        );
      } catch (e) {
        report.failed++;
        report.errors.add('❌ "${word.word}" (id: ${word.id}) — $e');
        onProgress?.call(
          i + 1,
          total,
          '❌ [${i + 1}/$total] HATA: "${word.word}" — $e',
        );
      }

      // Rate limiting
      if (i < docs.length - 1) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    onProgress?.call(
      total,
      total,
      '\n🏁 Migration tamamlandı!\n'
      '   ✅ Başarılı : ${report.success}\n'
      '   ⏭️ Atlandı  : ${report.skipped}\n'
      '   ❌ Hatalı   : ${report.failed}\n'
      '${dryRun ? "   ⚠️  DRY-RUN moduydu, hiçbir şey kaydedilmedi." : ""}',
    );

    return report;
  }

  Future<String> _getContextType(
    String collectionId,
    Map<String, String> cache,
  ) async {
    if (cache.containsKey(collectionId)) return cache[collectionId]!;
    try {
      final doc =
          await _db.collection('collections').doc(collectionId).get();
      final type =
          (doc.data()?['context_type'] as String?) ?? 'Academy';
      cache[collectionId] = type;
      return type;
    } catch (_) {
      cache[collectionId] = 'Academy';
      return 'Academy';
    }
  }

  String _describeChanges(Word original, Word updated) {
    final parts = <String>[];
    if (original.word != updated.word) {
      parts.add('word: "${original.word}"→"${updated.word}"');
    }
    if (original.partOfSpeech != updated.partOfSpeech) {
      parts.add(
        'pos: ${original.partOfSpeech.apiValue}→${updated.partOfSpeech.apiValue}',
      );
    }
    return parts.join(', ');
  }
}

class MigrationReport {
  final bool dryRun;
  int success = 0;
  int skipped = 0;
  int failed = 0;
  final List<String> logs = [];
  final List<String> errors = [];

  MigrationReport({required this.dryRun});
}
