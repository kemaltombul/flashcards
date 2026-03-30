import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────
// Log Level & Category
// ─────────────────────────────────────────────

enum LogLevel { info, warning, error, critical }

enum LogCategory {
  firestore,
  auth,
  ai,
  navigation,
  general;

  @override
  String toString() => name;
}

// ─────────────────────────────────────────────
// Log Entry Model
// ─────────────────────────────────────────────

class AppLogEntry {
  final String id;
  final LogLevel level;
  final LogCategory category;
  final String operation; // e.g. "insertWord", "subscribeByShareCode"
  final String message;
  final String? detail; // stack trace veya ek bağlam
  final String? userId;
  final Map<String, dynamic>? meta; // isteğe bağlı ekstra veri
  final DateTime timestamp;

  AppLogEntry({
    required this.id,
    required this.level,
    required this.category,
    required this.operation,
    required this.message,
    this.detail,
    this.userId,
    this.meta,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'level': level.name,
    'category': category.name,
    'operation': operation,
    'message': message,
    if (detail != null) 'detail': detail,
    if (userId != null) 'user_id': userId,
    if (meta != null) 'meta': meta,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'timestamp_iso': timestamp.toIso8601String(),
  };

  static AppLogEntry fromMap(Map<String, dynamic> map, String id) =>
      AppLogEntry(
        id: id,
        level: LogLevel.values.firstWhere(
          (l) => l.name == map['level'],
          orElse: () => LogLevel.info,
        ),
        category: LogCategory.values.firstWhere(
          (c) => c.name == map['category'],
          orElse: () => LogCategory.general,
        ),
        operation: map['operation'] ?? '',
        message: map['message'] ?? '',
        detail: map['detail'],
        userId: map['user_id'],
        meta: map['meta'] != null
            ? Map<String, dynamic>.from(map['meta'])
            : null,
        timestamp: map['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
            : DateTime.now(),
      );
}

// ─────────────────────────────────────────────
// AppLogger
// ─────────────────────────────────────────────

class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Public log methods ──────────────────────
  // Tüm metodlar void — await beklenmez, uygulama bloklanmaz.

  void info(
    String operation,
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? meta,
  }) => _write(LogLevel.info, category, operation, message, meta: meta);

  void warning(
    String operation,
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? meta,
  }) => _write(LogLevel.warning, category, operation, message, meta: meta);

  void error(
    String operation,
    Object e, {
    LogCategory category = LogCategory.general,
    StackTrace? stackTrace,
    Map<String, dynamic>? meta,
  }) => _write(
    LogLevel.error,
    category,
    operation,
    _extractMessage(e),
    detail: stackTrace != null ? stackTrace.toString() : e.toString(),
    meta: meta,
  );

  void critical(
    String operation,
    Object e, {
    LogCategory category = LogCategory.general,
    StackTrace? stackTrace,
    Map<String, dynamic>? meta,
  }) => _write(
    LogLevel.critical,
    category,
    operation,
    _extractMessage(e),
    detail: stackTrace != null ? stackTrace.toString() : e.toString(),
    meta: meta,
  );

  // ── Query methods (arayüz için) ─────────────

  /// Son [limit] kadar logu döner.
  /// Filtreleme client-side yapılır — composite index gerekmez.
  Stream<List<AppLogEntry>> logsStream({
    LogLevel? level,
    LogCategory? category,
    int limit = 200,
  }) {
    return _db
        .collection('app_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          var entries = snap.docs
              .map((doc) => AppLogEntry.fromMap(doc.data(), doc.id))
              .toList();

          // Client-side filtre — index gerektirmez
          if (level != null) {
            entries = entries.where((e) => e.level == level).toList();
          }
          if (category != null) {
            entries = entries.where((e) => e.category == category).toList();
          }

          return entries;
        });
  }

  /// Belirli bir zaman aralığındaki logları çeker (tek seferlik).
  /// Filtreleme client-side yapılır — composite index gerekmez.
  Future<List<AppLogEntry>> fetchLogs({
    LogLevel? level,
    LogCategory? category,
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    // Sadece timestamp ile sırala — tek alan index zaten var
    final snap = await _db
        .collection('app_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    var entries = snap.docs
        .map((doc) => AppLogEntry.fromMap(doc.data(), doc.id))
        .toList();

    // Client-side filtreler
    if (level != null)
      entries = entries.where((e) => e.level == level).toList();
    if (category != null)
      entries = entries.where((e) => e.category == category).toList();
    if (from != null)
      entries = entries.where((e) => e.timestamp.isAfter(from)).toList();
    if (to != null)
      entries = entries.where((e) => e.timestamp.isBefore(to)).toList();

    return entries;
  }

  /// Tek bir logu siler.
  Future<void> deleteLog(String logId) async {
    await _db.collection('app_logs').doc(logId).delete();
  }

  /// Tüm logları temizler — dikkatli kullan.
  Future<void> clearAllLogs() async {
    final snap = await _db.collection('app_logs').get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Private ─────────────────────────────────

  void _write(
    LogLevel level,
    LogCategory category,
    String operation,
    String message, {
    String? detail,
    Map<String, dynamic>? meta,
  }) {
    // unawaited — Firestore yazma işlemi arka planda çalışır,
    // çağıran taraf hiç beklemez, UI bloklanmaz.
    Future(() async {
      try {
        final entry = AppLogEntry(
          id: '',
          level: level,
          category: category,
          operation: operation,
          message: message,
          detail: detail,
          userId: _uid,
          meta: meta,
          timestamp: DateTime.now(),
        );
        await _db.collection('app_logs').add(entry.toMap());
      } catch (_) {
        // Loglama asla ana akışı bozmamalı
      }
    });
  }

  String _extractMessage(Object e) {
    if (e is FirebaseException) {
      return '[${e.code}] ${e.message ?? e.toString()}';
    }
    return e.toString();
  }
}
