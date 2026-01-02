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

  /// Loads initial vocabulary data from a JSON file in assets.
  Future<void> _loadInitialDataFromName(Database db, String fileName) async {
    try {
      String jsonString = await rootBundle.loadString('assets/$fileName');
      List<dynamic> data = jsonDecode(jsonString);

      for (var collectionData in data) {
        int colId = await db.insert('collections', {
          'name': collectionData['name'],
          'is_favorite': 0,
          'is_game': 0 // Game mode off by default
        });

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

  /// Toggles the favorite status of a collection.
  Future<void> toggleFavorite(int id, bool currentStatus) async {
    final db = await database;
    await db.update('collections', {'is_favorite': currentStatus ? 0 : 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes a collection and its associated words (cascade delete).
  Future<void> deleteCollection(int id) async {
    final db = await database;
    await db.delete('collections', where: 'id = ?', whereArgs: [id]);
  }

  // Settings Update Method
  /// Updates the game mode status of a collection.
  Future<void> updateCollectionMode(int id, bool isGame) async {
    final db = await database;
    await db.update(
      'collections',
      {'is_game': isGame ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Updates the name of a collection.
  Future<void> updateCollectionName(int id, String newName) async {
    final db = await database;
    await db.update(
      'collections',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
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

        for (var collectionData in data) {
          // Read "is_game" from JSON (default false)
          bool isGame = collectionData['is_game'] ?? false;
          
          int colId = await createCollection(collectionData['name'], isGame);
          
          if (collectionData['words'] != null) {
             for (var wordData in collectionData['words']) {
              await insertWord(Word(
                collectionId: colId,
                word: wordData['word'],
                definition: wordData['definition'],
                meaningTr: wordData['meaning_tr'] ?? '',
                example: wordData['example'] ?? ''
              ));
            }
          }
        }
        return "Import Successful!";
      } else {
        return "No file selected.";
      }
    } catch (e) {
      return "Error: $e";
    }
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