import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'firestore_service.dart';

// ─────────────────────────────────────────────
// Custom Exceptions
// ─────────────────────────────────────────────

sealed class AIException implements Exception {
  final String message;
  const AIException(this.message);

  @override
  String toString() => message;
}

class AINetworkException extends AIException {
  const AINetworkException() : super('İnternet bağlantısı yok.');
}

class AIAuthException extends AIException {
  const AIAuthException() : super('API anahtarı geçersiz.');
}

class AIRateLimitException extends AIException {
  const AIRateLimitException() : super('Çok fazla istek. Lütfen bekleyin.');
}

class AIEmptyResponseException extends AIException {
  const AIEmptyResponseException() : super('AI boş yanıt döndürdü.');
}

class AIParseException extends AIException {
  const AIParseException(String detail) : super('Yanıt ayrıştırılamadı: $detail');
}

class AIGenerationException extends AIException {
  const AIGenerationException(String detail) : super('Kelime üretilemedi: $detail');
}

// ─────────────────────────────────────────────
// Validation Result
// ─────────────────────────────────────────────

class ValidationResult {
  final bool valid;
  final List<String> issues;
  final Map<String, dynamic> fixed;

  const ValidationResult({
    required this.valid,
    required this.issues,
    required this.fixed,
  });

  @override
  String toString() =>
      'ValidationResult(valid: $valid, issues: $issues)';
}

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

enum WordType {
  word,
  phrasalVerb,
  idiom,
  collocation;

  static WordType fromString(String value) => switch (value) {
        'phrasal_verb' => WordType.phrasalVerb,
        'idiom'        => WordType.idiom,
        'collocation'  => WordType.collocation,
        _              => WordType.word,
      };

  String get apiValue => switch (this) {
        WordType.phrasalVerb => 'phrasal_verb',
        WordType.idiom       => 'idiom',
        WordType.collocation => 'collocation',
        WordType.word        => 'word',
      };

  bool get isMultiWord => this != WordType.word;

  String get description => switch (this) {
        WordType.phrasalVerb => 'phrasal verb (e.g. "give up", "break up")',
        WordType.idiom       => 'idiom (e.g. "once in a blue moon")',
        WordType.collocation => 'collocation (e.g. "make a decision")',
        WordType.word        => 'single vocabulary word',
      };
}

enum ContextMode { academy, cinema, practical }

extension ContextModeX on ContextMode {
  String get label => switch (this) {
        ContextMode.academy   => 'Academy',
        ContextMode.cinema    => 'Cinema',
        ContextMode.practical => 'Practical',
      };

  static ContextMode fromString(String value) => switch (value) {
        'Cinema'    => ContextMode.cinema,
        'Practical' => ContextMode.practical,
        _           => ContextMode.academy,
      };
}

// ─────────────────────────────────────────────
// Prompt Builder
// ─────────────────────────────────────────────

class _PromptBuilder {
  static String wordDefinitionSystem({
    required String word,
    required ContextMode mode,
    required WordType wordType,
    required String? existingDefinition,
    required String? existingTranslation,
    required String? existingContextualInfo,
    required String? context,
    required bool inputIsSentence,
  }) {
    final buffer = StringBuffer();

    // --- Role ---
    buffer.writeln('''
Role: Expert dictionary assistant for CEFR A1 (Beginner) English learners.
Task: Generate structured vocabulary data for the word/phrase below.
Output: STRICTLY valid JSON — no markdown, no backticks, no extra text.
Schema: {"word": "...", "definition": "...", "translation": "...", "contextual_info": "..."}
''');

    // --- Word type handling ---
    if (wordType.isMultiWord) {
      buffer.writeln('''
PHRASE TYPE: "$word" is a ${wordType.description}.
- Treat the entire phrase as ONE vocabulary unit. Never split it.
- Definition must explain the phrase holistically.
  ✅ "fed up" → "very tired of something and annoyed by it"
  ✅ "break up" → "to end a romantic relationship"
''');
    }

    // --- Sentence extraction ---
    if (inputIsSentence && !wordType.isMultiWord) {
      buffer.writeln('''
SENTENCE INPUT DETECTED:
The input appears to be a full sentence.
1. Identify the most advanced or key vocabulary word in the sentence.
2. Set that extracted word as the "word" value.
3. Define it based on its usage in the sentence.
''');
    }

    // --- Context hint ---
    if (context != null && context.trim().isNotEmpty) {
      buffer.writeln('''
CONTEXT PROVIDED BY USER: "$context"
Use this to determine which specific meaning of "$word" is intended.
Definition and translation MUST reflect this context.
''');
    }

    // --- Existing user data ---
    final hasExisting = existingTranslation != null ||
        existingDefinition != null ||
        existingContextualInfo != null;

    if (hasExisting) {
      buffer.writeln('EXISTING USER DATA (verify and reuse if accurate):');
      if (existingTranslation != null) {
        buffer.writeln('  - translation: "$existingTranslation" → keep if correct, fix if wrong.');
      }
      if (existingDefinition != null) {
        buffer.writeln('  - definition: "$existingDefinition" → simplify to A1 level if needed.');
      }
      if (existingContextualInfo != null) {
        buffer.writeln('  - contextual_info: "$existingContextualInfo"');
      }
      buffer.writeln('Fill ONLY missing fields. Do not overwrite accurate data.\n');
    }

    // --- Field rules ---
    buffer.writeln('''
FIELD RULES:

1. word
   - Return the phrase as-is for phrasal verbs and idioms.
   - Return the extracted word if input was a sentence.

2. definition
   - CEFR A1 vocabulary only. Max 12 words.
   - Clear, simple, no jargon.

3. translation (Turkish)
   - 1–4 words ONLY. Just the word or a short phrase.
   - NO sentences. NO explanations. NO suffixes that turn it into a sentence.
   ✅ "yorulmak", "bıkmak", "ayrılmak"
   ❌ "bir şeyden çok yorulmak ve bundan rahatsız olmak"

4. contextual_info
   - MUST be a plain text string. NO JSON, NO nested objects, NO arrays.
   ${_contextualInfoRule(mode, word)}
''');

    return buffer.toString();
  }

  static String _contextualInfoRule(ContextMode mode, String word) {
    return switch (mode) {
      ContextMode.cinema => '''
Mode: Cinema
   - Provide ONE real, well-known quote from a movie, TV show, or song that uses "$word".
   - Format: [Title (Year)]: "exact quote"
   - The quote MUST contain "$word" or its inflected form.
   - If no famous quote exists, write a realistic fictional one and mark it [Fictional Example].
   - Max 20 words for the quote.
   - Example: [The Dark Knight (2008)]: "Why so serious?"''',

      ContextMode.practical => '''
Mode: Practical
   - Provide ONE real-life example sentence for "$word".
   - Choose the most natural setting: workplace, casual talk, text/social media, shopping/travel.
   - Format: [Setting]: "example sentence"
   - Must sound like something a real person would say. Max 15 words.
   - Example: [Workplace]: "I'm fed up with meetings that could've been emails."''',

      ContextMode.academy => '''
Mode: Academy
   - Format:
       Synonyms: word1, word2, word3
       Antonyms: word1, word2

   SYNONYMS RULE — CRITICAL, NEVER LEAVE EMPTY:
   You MUST always provide at least 2 synonyms. No exceptions.
   - Start with exact synonyms that share this specific meaning.
   - If exact synonyms are scarce, expand to near-synonyms or words with overlapping meaning.
   - If the word is highly specific (e.g. a rare adjective), use broader related words or descriptive equivalents.
   - For phrasal verbs/idioms → use single-word equivalents (e.g. "give up" → "quit, abandon, surrender").
   - The "Synonyms:" line is REQUIRED in every response. Never omit it.

   ANTONYMS RULE:
   - Provide antonyms when they exist and are clear.
   - Omit "Antonyms:" line ONLY if truly no antonym exists (e.g. proper nouns, very specific technical terms).
   - Do NOT write "none" or leave the value empty.

   STYLE:
   - Do NOT add explanations or parenthetical notes after words.
   - Comma-separated, no extra punctuation.''',
    };
  }

  /// Validator system prompt — judges and optionally fixes a generated word card.
  /// [context] is passed through so the validator can check contextual accuracy,
  /// not just structural correctness.
  static String validationSystem({
    required String word,
    required ContextMode mode,
    required WordType wordType,
    String? context,
  }) {
    final contextBlock = (context != null && context.trim().isNotEmpty)
        ? '''

CONTEXT: "$context"
The definition and translation MUST match this specific context and meaning of "$word".
Flag as invalid if they describe a different sense of the word.'''
        : '';

    return '''
Role: Quality-control reviewer for an English vocabulary app (A1 learners).
You will receive a generated word card. Evaluate each field and fix any issues.

WORD: "$word"
TYPE: ${wordType.description}
MODE: ${mode.label}$contextBlock

─── VALIDATION RULES ───────────────────────────────────────

1. WORD INTEGRITY
   - If type is phrasal_verb or idiom, the "word" field must be the full phrase intact.
   - A single particle ("up", "out") or split form is WRONG.
   ✅ "give up"  ❌ "give" or "up"

2. DEFINITION — CEFR A1
   - Max 12 words. Uses only basic, everyday English.
   - No academic jargon, no complex grammar terms.
   - Must describe the meaning of "$word" specifically, not a related concept.
   ${contextBlock.isNotEmpty ? '- Must reflect the provided CONTEXT above.' : ''}

3. TRANSLATION — Turkish, 1–4 words
   - Must be a Turkish word or very short phrase. NO full sentences.
   - Must match the specific meaning of "$word" in context.
   ✅ "yorulmak"   ❌ "bir şeyden çok yorulmak"
   ${contextBlock.isNotEmpty ? '- Must reflect the provided CONTEXT above.' : ''}

4. CONTEXTUAL_INFO — depends on mode:
   ${_contextualInfoValidationRule(mode)}

─── OUTPUT ─────────────────────────────────────────────────

Return STRICTLY valid JSON, no markdown:
{
  "valid": true | false,
  "issues": ["short description of each problem found, or empty list if valid"],
  "fixed": {
    "word": "...",
    "definition": "...",
    "translation": "...",
    "contextual_info": "..."
  }
}

- "valid": true only if ALL fields pass. false if ANY field has a problem.
- "issues": list every problem briefly. Empty list [] if valid.
- "fixed": ALWAYS return the full corrected card — even if valid is true (return as-is).
''';
  }

  static String _contextualInfoValidationRule(ContextMode mode) =>
      switch (mode) {
        ContextMode.cinema => '''
CINEMA MODE: Must be plain text in format [Title (Year)]: "quote"
   - Quote must contain the word or its inflected form.
   - Must NOT be a JSON object or nested structure.
   - If fabricated, must be marked [Fictional Example].''',
        ContextMode.practical => '''
PRACTICAL MODE: Must be plain text in format [Setting]: "example sentence"
   - Must NOT be a JSON object or nested structure.
   - Must sound natural. Max 15 words for the sentence.''',
        ContextMode.academy => '''
ACADEMY MODE: Must be plain text in this format:
   Synonyms: word1, word2, word3
   Antonyms: word1, word2  (omit only if truly none)
   - At least 2 synonyms required.
   - No explanations or parenthetical notes after words.
   - Must NOT be a JSON object or nested structure.''',
      };

  static String imageExtractionSystem() => '''
You are an expert English vocabulary extractor for language learners.

TASK: Find ALL visually marked vocabulary items in the image.

WHAT COUNTS AS MARKED:
- Underlined (line beneath the word)
- Highlighted (colored background)
- Circled or boxed (shape drawn around)
- Starred or annotated with a symbol (*, !, →, etc.)

MULTI-WORD EXPRESSIONS — CRITICAL:
Extract phrasal verbs and idioms as a SINGLE unit. Never split them.
  ✅ "fed up", "break up", "look forward to", "run out of"
  ❌ "fed" + "up" separately

WORD TYPE DETECTION:
  - "word"         → single vocabulary word (e.g. "ephemeral")
  - "phrasal_verb" → verb + particle (e.g. "give up", "break up")
  - "idiom"        → fixed expression (e.g. "once in a blue moon")
  - "collocation"  → common word pair (e.g. "make a decision")

OUTPUT — strictly valid JSON, no markdown:
{
  "items": [
    {
      "word": "break up",
      "type": "phrasal_verb",
      "context": "They decided to break up after years together."
    }
  ]
}
''';
}

// ─────────────────────────────────────────────
// Main Service
// ─────────────────────────────────────────────

class AIService {
  final FirestoreService _dbService = FirestoreService();
  final String _apiKey;

  AIService() : _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '' {
    if (_apiKey.isEmpty) {
      throw const AIAuthException();
    }
    OpenAI.apiKey = _apiKey;
  }

  // ── Public API ──────────────────────────────

  Future<Map<String, dynamic>> generateSmartWord(
    String inputWord,
    String? userDefinition,
    String collectionId, {
    String contextType = 'Academy',
    String wordType = 'word',
  }) async {
    final word = inputWord.trim();
    if (word.isEmpty) throw const AIGenerationException('Kelime boş olamaz.');

    final mode = ContextModeX.fromString(contextType);
    final type = WordType.fromString(wordType);

    final parsed = userDefinition != null && userDefinition.trim().isNotEmpty
        ? _parseUserInput(userDefinition)
        : <String, String?>{
            'definition': null,
            'translation': null,
            'contextual_info': null,
          };

    final aiData = await _fetchWordDetails(
      word,
      mode: mode,
      wordType: type,
      existingDefinition: parsed['definition'],
      existingTranslation: parsed['translation'],
      existingContextualInfo: parsed['contextual_info'],
      context: userDefinition,
    );

    return {
      'collection_id': collectionId,
      'word': aiData['word'],
      'definition': aiData['definition'],
      'translation': aiData['translation'],
      'contextual_info': aiData['contextual_info'],
    };
  }

  Future<List<Map<String, String>>> extractWordsFromImage(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final payload = {
      'model': 'gpt-4o',
      'messages': [
        {
          'role': 'system',
          'content': _PromptBuilder.imageExtractionSystem(),
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': 'Extract ALL marked vocabulary items. Keep phrasal verbs and multi-word expressions as single units.',
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$base64Image',
                'detail': 'high',
              },
            },
          ],
        },
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.1,
      'max_tokens': 1000,
    };

    final response = await _post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      payload,
    );

    final content = response['choices'][0]['message']['content'] as String?;
    if (content == null || content.trim().isEmpty) throw const AIEmptyResponseException();

    final decoded = _decodeJson(content);
    final items = decoded['items'];
    if (items is! List) throw AIParseException('Beklenen "items" listesi bulunamadı.');

    return items
        .map<Map<String, String>>((e) {
          final word    = e['word']?.toString().trim() ?? '';
          final type    = e['type']?.toString().trim() ?? 'word';
          final context = e['context']?.toString().trim() ?? '';
          final enrichedContext = type != 'word' ? '[$type] $context' : context;
          return {'word': word, 'context': enrichedContext, 'type': type};
        })
        .where((e) => e['word']!.isNotEmpty)
        .toList();
  }

  // ── Private: Fetch word details ─────────────

  Future<Map<String, dynamic>> _fetchWordDetails(
    String word, {
    required ContextMode mode,
    required WordType wordType,
    String? existingDefinition,
    String? existingTranslation,
    String? existingContextualInfo,
    String? context,
  }) async {
    final inputIsSentence = _isSentence(word);

    // Treat bare sentence input as context if no explicit context given
    final resolvedContext = (inputIsSentence && !wordType.isMultiWord && (context == null || context.trim().isEmpty))
        ? word
        : context;

    final systemPrompt = _PromptBuilder.wordDefinitionSystem(
      word: word,
      mode: mode,
      wordType: wordType,
      existingDefinition: existingDefinition,
      existingTranslation: existingTranslation,
      existingContextualInfo: existingContextualInfo,
      context: resolvedContext,
      inputIsSentence: inputIsSentence,
    );

    final userContent = _buildUserMessage(word, resolvedContext, wordType);

    try {
      // ── Step 1: Generate ──────────────────────
      final chatCompletion = await OpenAI.instance.chat.create(
        model: 'gpt-4o-mini',
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(systemPrompt)],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(userContent)],
          ),
        ],
        temperature: 0.4,
        responseFormat: {'type': 'json_object'},
      );

      final raw = chatCompletion.choices.firstOrNull?.message.content?.first.text;
      if (raw == null || raw.trim().isEmpty) throw const AIEmptyResponseException();

      final generated = _sanitizeWordData(_decodeJson(raw));

      // ── Step 2: Validate & fix ────────────────
      final result = await _validateAndFix(
        generated: generated,
        word: word,
        mode: mode,
        wordType: wordType,
        context: resolvedContext, // ← context artık validator'a da gidiyor
      );

      return result;
    } on AIException {
      rethrow;
    } on http.ClientException {
      throw const AINetworkException();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401')) throw const AIAuthException();
      if (msg.contains('429')) throw const AIRateLimitException();
      throw AIGenerationException(msg);
    }
  }

  // ── Private: Validate & fix ─────────────────

  Future<Map<String, dynamic>> _validateAndFix({
    required Map<String, dynamic> generated,
    required String word,
    required ContextMode mode,
    required WordType wordType,
    String? context, // ← yeni parametre
  }) async {
    try {
      final validationPrompt = _PromptBuilder.validationSystem(
        word: word,
        mode: mode,
        wordType: wordType,
        context: context, // ← prompt'a aktarılıyor
      );

      final cardJson = jsonEncode(generated);

      final completion = await OpenAI.instance.chat.create(
        model: 'gpt-4o-mini',
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(validationPrompt)],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(
              'Review and fix this word card:\n$cardJson',
            )],
          ),
        ],
        temperature: 0.2,
        responseFormat: {'type': 'json_object'},
      );

      final raw = completion.choices.firstOrNull?.message.content?.first.text;
      if (raw == null || raw.trim().isEmpty) {
        _logValidationFailure(word, 'Empty validator response');
        return generated;
      }

      final decoded = _decodeJson(raw);
      final validationResult = ValidationResult(
        valid: decoded['valid'] as bool? ?? true,
        issues: (decoded['issues'] as List?)?.cast<String>() ?? [],
        fixed: (decoded['fixed'] as Map?)?.cast<String, dynamic>() ?? generated,
      );

      if (!validationResult.valid) {
        _logValidationFailure(word, validationResult.issues.join(' | '));
      }

      return _sanitizeWordData(validationResult.fixed);
    } catch (e) {
      _logValidationFailure(word, e.toString());
      return generated;
    }
  }

  void _logValidationFailure(String word, String reason) {
    // ignore: avoid_print
    print('[AIService] Validation issue for "$word": $reason');
  }

  // ── Private: Input parsing ──────────────────

  Map<String, String?> _parseUserInput(String input) {
    final trimmed = input.trim();

    final result = <String, String?>{
      'word': null,
      'definition': null,
      'translation': null,
      'contextual_info': null,
    };

    // "word: definition" or "word - translation"
    final colonMatch = RegExp(r'^([a-zA-Z\s-]+)[:|-]\s*(.+)$').firstMatch(trimmed);
    if (colonMatch != null) {
      final rest = colonMatch.group(2)!.trim();
      result['word'] = colonMatch.group(1)!.trim();
      final hasTurkish = RegExp(r'[çğıöşüÇĞİÖŞÜ]').hasMatch(rest);
      if (hasTurkish || rest.split(' ').length <= 3) {
        result['translation'] = rest;
      } else {
        result['definition'] = rest;
      }
      return result;
    }

    // "word (translation)"
    final parenMatch = RegExp(r'^([a-zA-Z\s-]+)\s*[\(\[](.+?)[\)\]]').firstMatch(trimmed);
    if (parenMatch != null) {
      result['word'] = parenMatch.group(1)!.trim();
      result['translation'] = parenMatch.group(2)!.trim();
      return result;
    }

    // Named prefixes
    if (trimmed.startsWith('translation:')) {
      result['translation'] = trimmed.substring(12).trim();
      return result;
    }
    if (trimmed.startsWith('contextual_info:')) {
      result['contextual_info'] = trimmed.substring(16).trim();
      return result;
    }

    // Sentence vs single word
    if (_isSentence(trimmed)) {
      result['contextual_info'] = trimmed;
    } else {
      result['word'] = trimmed;
    }

    return result;
  }

  // ── Private: Helpers ────────────────────────

  bool _isSentence(String text) {
    final words = text.trim().split(' ');
    return words.length > 3 || RegExp(r'[.!?,]').hasMatch(text);
  }

  String _buildUserMessage(String word, String? context, WordType wordType) {
    final parts = ['Word: $word'];
    if (context != null && context.trim().isNotEmpty) {
      parts.add('Context: $context');
    }
    if (wordType.isMultiWord) {
      parts.add('Type: ${wordType.description} — treat as a single unit.');
    }
    return parts.join('\n');
  }

  /// Flatten any non-string contextual_info and trim overly long translations.
  Map<String, dynamic> _sanitizeWordData(Map<String, dynamic> data) {
    final rawInfo = data['contextual_info'];
    if (rawInfo != null && rawInfo is! String) {
      data['contextual_info'] = _flattenToString(rawInfo);
    }

    final rawTranslation = data['translation'];
    if (rawTranslation is String) {
      data['translation'] = _trimTranslation(rawTranslation);
    }

    return data;
  }

  String _flattenToString(dynamic value) {
    if (value is String) return value;
    if (value is Map)  return value.entries.map((e) => '${e.key}: ${_flattenToString(e.value)}').join(' | ');
    if (value is List) return value.map(_flattenToString).join(', ');
    return value.toString();
  }

  String _trimTranslation(String translation) {
    final trimmed = translation.split(RegExp(r'[,;.(]')).first.trim();
    final words = trimmed.split(' ');
    return words.length > 4 ? words.take(4).join(' ') : trimmed;
  }

  Map<String, dynamic> _decodeJson(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'^```json|```$', multiLine: true), '').trim();
    try {
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (e) {
      throw AIParseException(e.toString());
    }
  }

  Future<Map<String, dynamic>> _post(Uri url, Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(payload),
      );

      return switch (response.statusCode) {
        200   => jsonDecode(response.body) as Map<String, dynamic>,
        401   => throw const AIAuthException(),
        429   => throw const AIRateLimitException(),
        _     => throw AIGenerationException('HTTP ${response.statusCode}: ${response.body}'),
      };
    } on AIException {
      rethrow;
    } on http.ClientException {
      throw const AINetworkException();
    }
  }
}