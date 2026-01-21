import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart'; // for rootBundle
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/word.dart';
import '../models/collection.dart';

/// Service class to handle all SQLite database operations.
/// Implements Singleton pattern to ensure only one instance exists.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  /// Returns the existing database instance or initializes a new one.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the database, creates tables, and loads initial data.
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'flashcards_final_v3.db');
    
    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // 1. Collections Table
        await db.execute('''
          CREATE TABLE collections(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            is_favorite INTEGER DEFAULT 0,
            is_game INTEGER DEFAULT 0 -- 0: Study Mode, 1: Game Mode
          )
        ''');

        // 2. Words Table
        await db.execute('''
          CREATE TABLE words(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            collection_id INTEGER,
            word TEXT,
            definition TEXT,
            meaning_tr TEXT, 
            example TEXT,
            FOREIGN KEY(collection_id) REFERENCES collections(id) ON DELETE CASCADE
          )
        ''');

        // Load initial data
        await _loadInitialDataFromName(db, 'initial_data.json');
      },
    );
  }

  /// Helper to import collections and words from a list of data.
  /// Used by both initial load and JSON import.
  Future<void> _importCollectionsFromData(List<dynamic> data, {DatabaseExecutor? executor}) async {
    final db = executor ?? await database;

    for (var collectionData in data) {
      int colId = await db.insert('collections', {
        'name': collectionData['name'],
        'is_favorite': 0,
        'is_game': (collectionData['is_game'] ?? false) == true ? 1 : 0
      });

      if (collectionData['words'] != null) {
        for (var wordData in collectionData['words']) {
          await db.insert('words', {
            'collection_id': colId,
            'word': wordData['word'],
            'definition': wordData['definition'],
            'meaning_tr': wordData['meaning_tr'] ?? '',
            'example': wordData['example'] ?? '',
          });
        }
      }
    }
  }

  /// Loads initial vocabulary data from a JSON file in assets.
  Future<void> _loadInitialDataFromName(Database db, String fileName) async {
    try {
      String jsonString = await rootBundle.loadString('assets/$fileName');
      List<dynamic> data = jsonDecode(jsonString);
      await _importCollectionsFromData(data, executor: db);
    } catch (e) {
      debugPrint("JSON Load Error: $e");
    }
  }

  // =======================================================================
  // Collection Operations
  // =======================================================================

  /// Creates a new collection in the database.
  Future<int> createCollection(String name, bool isGame) async {
    final db = await database;
    return await db.insert('collections', {
      'name': name, 
      'is_favorite': 0,
      'is_game': isGame ? 1 : 0
    });
  }

  /// Retrieves all collections, ordered by favorites then ID.
  Future<List<Collection>> getCollections() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('collections', orderBy: "is_favorite DESC, id DESC");
    return List.generate(maps.length, (i) => Collection.fromMap(maps[i]));
  }

  /// Helper to update a collection's properties.
  Future<void> _updateCollection(int id, Map<String, Object?> values) async {
    final db = await database;
    await db.update(
      'collections',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Toggles the favorite status of a collection.
  Future<void> toggleFavorite(int id, bool currentStatus) async {
    await _updateCollection(id, {'is_favorite': currentStatus ? 0 : 1});
  }

  /// Deletes a collection and its associated words (cascade delete).
  Future<void> deleteCollection(int id) async {
    final db = await database;
    await db.delete('collections', where: 'id = ?', whereArgs: [id]);
  }

  // Settings Update Method
  /// Updates the game mode status of a collection.
  Future<void> updateCollectionMode(int id, bool isGame) async {
    await _updateCollection(id, {'is_game': isGame ? 1 : 0});
  }

  /// Updates the name of a collection.
  Future<void> updateCollectionName(int id, String newName) async {
    await _updateCollection(id, {'name': newName});
  }

  // =======================================================================
  // Word Operations
  // =======================================================================

  /// Inserts a new word into the database.
  Future<int> insertWord(Word word) async {
    final db = await database;
    return await db.insert('words', word.toMap());
  }

  /// Retrieves all words for a specific collection, randomized order.
  Future<List<Word>> getWordsByCollection(int collectionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('words', where: 'collection_id = ?', whereArgs: [collectionId], orderBy: "RANDOM()");
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  /// Returns the total number of words in a collection.
  Future<int> getWordCount(int collectionId) async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM words WHERE collection_id = ?', [collectionId])) ?? 0;
  }

  // Update and Delete Word
  Future<void> deleteWord(int id) async {
    final db = await database;
    await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }


  
  /// Searches for words matching the query string.
  /// Searches for words matching the query string.
  /// If [collectionIds] is provided, filters by those collections.
  /// If [query] is empty, returns all words (filtered by collection if provided).
  Future<List<Word>> searchWords(String query, {List<int>? collectionIds}) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> args = [];

    // Filter by Collections
    if (collectionIds != null && collectionIds.isNotEmpty) {
      String placeHolders = List.filled(collectionIds.length, '?').join(',');
      whereClause = 'collection_id IN ($placeHolders)';
      args.addAll(collectionIds);
    }

    // Filter by Query
    if (query.trim().isNotEmpty) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      // Wrap ORs in parenthesis when combined with AND
      whereClause += '(word LIKE ? OR definition LIKE ? OR meaning_tr LIKE ?)';
      args.addAll(['%$query%', '%$query%', '%$query%']);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'word ASC', // Optional: Sort alphabetically
    );
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  /// Checks if a word exists in the database regardless of collection.
  /// Returns true if found, false otherwise.
  Future<bool> wordExists(String word) async {
    final db = await database;
    var result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE LOWER(word) = ?',
      [word.toLowerCase()]
    );
    int count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  /// Checks if a word with a specific meaning exists.
  /// Useful for words with multiple meanings (polysemy).
  Future<bool> wordAndMeaningExists(String word, String meaningTr) async {
    final db = await database;
    // We check if the existing meaning contains the new meaning or vice versa to catch partial matches.
    // e.g. "Kuş" vs "Kuş türü"
    var result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE LOWER(word) = ? AND LOWER(meaning_tr) LIKE ?',
      [word.toLowerCase(), '%${meaningTr.toLowerCase()}%']
    );
    int count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  /// Inserts a word from a map object.
  Future<int> insertWordMap(Map<String, dynamic> wordMap) async {
    final db = await database;
    return await db.insert('words', wordMap);
  }

  Future<void> updateWord(Word word) async {
    final db = await database;
    await db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  // =======================================================================
  // JSON Operations
  // =======================================================================
/// Imports collections and words from a selected JSON file.
/// Imports collections and words from a selected JSON file.
  Future<String> importFromJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      
      if (result != null) {
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();
        dynamic decodedData = jsonDecode(jsonString);
        
        List<dynamic> data = [];
        if (decodedData is List) {
          data = decodedData;
        } else if (decodedData is Map) {
          data = [decodedData];
        } else {
          return "Invalid JSON format: Expected List or Object.";
        }

        await _importCollectionsFromData(data);
        
        return "Import Successful!";
      } else {
        return "No file selected.";
      }
    } catch (e) {
      return "Error: $e";
    }
  }
  
  /// Imports words from a list of JSON objects with deduplication.
  /// Checks against the specific collection for existing (word + meaning_tr).
  Future<Map<String, int>> importWordsWithDeduplication(int collectionId, List<dynamic> words) async {
    final db = await database;
    int insertedCount = 0;
    int skippedCount = 0;

    for (var wordData in words) {
      String word = wordData['word'] ?? '';
      String meaningTr = wordData['meaning_tr'] ?? '';
      String definition = wordData['definition'] ?? '';
      String example = wordData['example'] ?? '';

      if (word.isEmpty || meaningTr.isEmpty) {
        continue; 
      }

      // Check for duplicates in THIS collection
      // We check if BOTH 'word' and 'meaning_tr' match an existing entry.
      var result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM words WHERE collection_id = ? AND word = ? AND meaning_tr = ?',
        [collectionId, word, meaningTr]
      );
      
      int count = Sqflite.firstIntValue(result) ?? 0;

      if (count == 0) {
        await insertWord(Word(
          collectionId: collectionId,
          word: word,
          definition: definition,
          meaningTr: meaningTr,
          example: example,
        ));
        insertedCount++;
      } else {
        skippedCount++;
      }
    }

    return {'inserted': insertedCount, 'skipped': skippedCount};
  }

  /// Exports a collection and its words to a JSON file.
  Future<String> exportCollectionAsJson(int collectionId, String collectionName) async {
    try {
      List<Word> words = await getWordsByCollection(collectionId);
      Map<String, dynamic> collectionData = {
        "name": collectionName,
        "words": words.map((w) => {
          "word": w.word,
          "definition": w.definition,
          "meaning_tr": w.meaningTr,
          "example": w.example
        }).toList()
      };

      List<Map<String, dynamic>> finalJsonList = [collectionData];
      String jsonString = const JsonEncoder.withIndent('  ').convert(finalJsonList);
      String safeFileName = collectionName.replaceAll(' ', '_').toLowerCase();

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$safeFileName.json');
        await file.writeAsString(jsonString);
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(file.path)], text: '$collectionName Collection');
        return "Share screen opened.";
      } else {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Collection',
          fileName: '$safeFileName.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (outputFile != null) {
          File file = File(outputFile);
          await file.writeAsString(jsonString);
          return "File saved:\n$outputFile";
        } else {
          return "Save canceled.";
        }
      }
    } catch (e) {
      return "Error: $e";
    }
  }
}