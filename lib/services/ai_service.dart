import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:image_picker/image_picker.dart';
import 'firestore_service.dart';

class AIService {
  final FirestoreService _dbService = FirestoreService();

  // OpenAI API Configuration
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? "";

  AIService() {
    // Initialize OpenAI
    OpenAI.apiKey = _apiKey;
    // Optional: Organization ID if needed
    // OpenAI.organization = "YOUR_ORGANIZATION_ID";
  }

  /// Parses user input to extract word, meaning, definition, and example.
  /// Supports multiple formats:
  /// - "word" -> word only
  /// - "word: meaning" -> word + Turkish meaning
  /// - "word: definition" -> word + English definition
  /// - "example sentence" -> extract word from sentence
  /// - "word (meaning) - definition" -> mixed format
  Map<String, String?> _parseUserInput(String input) {
    String trimmed = input.trim();
    
    // Initialize result
    Map<String, String?> result = {
      'word': null,
      'definition': null,
      'translation': null,
      'contextual_info': null,
    };

    // Pattern 1: "word: meaning" or "word - meaning" (Turkish meaning)
    // Detect Turkish characters to identify meaning vs definition
    RegExp colonPattern = RegExp(r'^([a-zA-Z\s-]+)[:|-]\s*(.+)$');
    Match? colonMatch = colonPattern.firstMatch(trimmed);
    
    if (colonMatch != null) {
      String word = colonMatch.group(1)!.trim();
      String rest = colonMatch.group(2)!.trim();
      
      // Check if rest contains Turkish characters (ç, ğ, ı, ö, ş, ü)
      bool hasTurkish = RegExp(r'[çğıöşüÇĞİÖŞÜ]').hasMatch(rest);
      
      result['word'] = word;
      if (hasTurkish || rest.split(' ').length <= 3) {
        // Likely Turkish meaning
        result['translation'] = rest;
      } else {
        // Likely English definition
        result['definition'] = rest;
      }
      return result;
    }

    // Pattern 2: "word (meaning)" or "word [meaning]"
    RegExp parenPattern = RegExp(r'^([a-zA-Z\s-]+)\s*[\(\[](.+?)[\)\]]');
    Match? parenMatch = parenPattern.firstMatch(trimmed);
    
    if (parenMatch != null) {
      result['word'] = parenMatch.group(1)!.trim();
      result['translation'] = parenMatch.group(2)!.trim();
      return result;
    }

    // Pattern 3: Sentence (contains multiple words and looks like a sentence)
    bool isSentence = trimmed.contains(' ') && 
                      (trimmed.split(' ').length > 3 || 
                       RegExp(r'[.!?,]').hasMatch(trimmed));
    
    if (isSentence) {
      result['contextual_info'] = trimmed;
      // Word will be extracted by AI
      return result;
    }

    // Pattern 4: Specific prefixes for direct assignment
    if (trimmed.startsWith('translation:')) {
      result['translation'] = trimmed.substring(12).trim();
      return result;
    }
    if (trimmed.startsWith('contextual_info:')) {
      result['contextual_info'] = trimmed.substring(16).trim();
      return result;
    }

    // Pattern 5: Single word or phrase
    result['word'] = trimmed;
    return result;
  }

  /// Generates a word with details using AI but DOES NOT save it.
  /// Returns the word data as a Map.
  Future<Map<String, dynamic>> generateSmartWord(
    String inputWord,
    String? userDefinition,
    String collectionId,
  ) async {
    try {
      // 1. Input Validation
      if (inputWord.trim().isEmpty) {
        throw Exception("Input word cannot be empty.");
      }

      String normalizedWord = inputWord.trim();

      // 3. Parse Context Input (Step 2) to extract available data
      Map<String, String?> parsedContext = {
        'definition': null,
        'translation': null,
        'contextual_info': null,
      };
      
      if (userDefinition != null && userDefinition.trim().isNotEmpty) {
        parsedContext = _parseUserInput(userDefinition);
      }
      
      // 4. API Request (Enrichment) - pass parsed context to AI
      final Map<String, dynamic> aiData = await _fetchWordDetailsFromAI(
        normalizedWord,
        existingDefinition: parsedContext['definition'],
        existingTranslation: parsedContext['translation'],
        existingContextualInfo: parsedContext['contextual_info'],
        context: userDefinition,
      );

      // 4. Return Data (instead of saving)
      return {
        'collection_id': collectionId,
        'word': aiData['word'],
        'definition': aiData['definition'],
        'translation': aiData['translation'],
        'contextual_info': aiData['contextual_info'],
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Private helper to call the OpenAI API.
  Future<Map<String, dynamic>> _fetchWordDetailsFromAI(
    String word, {
    String? existingDefinition,
    String? existingTranslation,
    String? existingContextualInfo,
    String? context,
  }) async {
    // Detect if the "word" itself is actually a sentence (heuristic: > 2 words or contains punctuation?)
    // If so, we treat the input string as the context, and ask the AI to extract the word.
    bool inputIsSentence =
        word.trim().contains(' ') && (word.trim().split(' ').length > 2);

    if (inputIsSentence && (context == null || context.trim().isEmpty)) {
      context = word;
      // We don't clear 'word' here to let the prompt know what the user typed,
      // but we add a specific instruction below.
    }

    String contextInstruction = "";
    if (context != null && context.trim().isNotEmpty) {
      contextInstruction =
          """
\nCONTEXT / HINT (CRITICAL):
The user provided this context or hint: "$context".
1. **Meaning Disambiguation**: Use this hint to figure out which specific meaning of "$word" they want. It could be a full sentence, a Turkish translation, or a grammatical hint (e.g., "verb").
2. **Strict Match**: The definition and Turkish meaning you generate MUST match the intent of this context.
""";
    }

    String extractionInstruction = "";
    if (inputIsSentence) {
      extractionInstruction = """
\nEXTRACTION INSTRUCTION:
The user input under "Word" appears to be a full sentence. 
1. Identify the **most difficult or key vocabulary word** (A1/A2 level) from this sentence.
2. Use THAT extracted word as the "word" value in your JSON extraction.
3. Define that word and provide its meaning based on the sentence.
""";
    }

    // Build existing data instruction
    String existingDataInstruction = "";
    if (existingTranslation != null || existingDefinition != null || existingContextualInfo != null) {
      existingDataInstruction = "\n\nEXISTING DATA PROVIDED BY USER:";
      if (existingTranslation != null) {
        existingDataInstruction += "\n- Translation: \"$existingTranslation\" (Use this if accurate, or correct it if wrong)";
      }
      if (existingDefinition != null) {
        existingDataInstruction += "\n- Definition: \"$existingDefinition\" (Use this if accurate, or improve it to A1 level)";
      }
      if (existingContextualInfo != null) {
        existingDataInstruction += "\n- Contextual Info: \"$existingContextualInfo\" (Extract the word from this sentence if needed)";
      }
      existingDataInstruction += "\n\nIMPORTANT: Fill ONLY the missing fields. Keep user-provided data if it's accurate.";
    }

    // Construct the prompt
    final String prompt =
        """
Role: Dictionary assistant for A1 (Beginner) English learners.
Input Word/Sentence: "$word".
$contextInstruction
$extractionInstruction
$existingDataInstruction

Rules:
1. Definition: Must be **CEFR A1 Level**. Use ONLY basic, high-frequency words. Max 12 words. Simple and clear.
2. Accuracy: Provide the correct translation in the appropriate language (e.g. Turkish) (matching the context if given) and a specific contextual sentence or synonym string (A1).
3. JSON Format: The response must be STRICTLY valid JSON like this, with NO markdown formatting, NO backticks, and NO other text before or after:
{"word": "...", "definition": "...", "translation": "...", "contextual_info": "..."}
    """;

    try {
      final systemMessage = OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
        ],
        role: OpenAIChatMessageRole.system,
      );

      String userContent = "Word: $word";
      if (context != null && context.trim().isNotEmpty) {
        userContent +=
            "\nSpecific Context/Meaning: $context (Focus ONLY on this meaning)";
      }

      final userMessage = OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(userContent),
        ],
        role: OpenAIChatMessageRole.user,
      );

      final chatCompletion = await OpenAI.instance.chat.create(
        model: "gpt-3.5-turbo",
        messages: [systemMessage, userMessage],
        temperature: 0.3,
        responseFormat: {"type": "json_object"}, // Force JSON mode
      );

      if (chatCompletion.choices.isNotEmpty) {
        final content =
            chatCompletion.choices.first.message.content?.first.text;

        if (content != null) {
          // Clean potential markdown just in case
          String cleanJson = content.trim();
          if (cleanJson.startsWith('```json')) {
            cleanJson = cleanJson
                .replaceAll('```json', '')
                .replaceAll('```', '');
          } else if (cleanJson.startsWith('```')) {
            cleanJson = cleanJson.replaceAll('```', '');
          }

          return jsonDecode(cleanJson);
        }
      }

      throw Exception("Empty response from OpenAI.");
    } catch (e) {
      throw Exception("Failed to fetch data from AI: $e");
    }
  }

  /// Extracts underlined/highlighted words and exactly their surrounding sentences from an image.
  /// Uses raw HTTP to avoid dart_openai serialization issues with image URLs.
  Future<List<Map<String, String>>> extractWordsFromImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse('https://api.openai.com/v1/chat/completions');

      final payload = {
        "model": "gpt-4o",
        "messages": [
          {
            "role": "system",
            "content":
                "You are a helpful assistant that identifies specific vocabulary in images.",
          },
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": """
                Identify ALL English words in this image that have been EXPLICITLY MARKED by the user. 
                A word is "marked" if it is:
                1. **Underlined** (a line drawn underneath it).
                2. **Highlighted** (colored over with a marker).
                3. **Encircled / Circled / Boxed** (a pen or pencil line drawn around the word, forming a circle, oval, or box).
                
                CRITICAL RULES:
                - Do NOT miss any words that have a circle, oval, or box drawn around them! Scan the entire image carefully.
                - Ignore general text, page titles, or instructions. Focus ONLY on the marked vocabulary.
                - For each identified word, also extract the full sentence it appears in as "context".
                - Return a STRICT JSON object with a single key "items" containing a list of objects.
                - Each object must have "word" and "context" string keys.
                Example: {"items": [{"word": "mitigate", "context": "We need to mitigate the risks."}, {"word": "ephemeral", "context": "The beauty of the flower is ephemeral."}]}
                """,
              },
              {
                "type": "image_url",
                "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
              },
            ],
          },
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.2,
      };

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_apiKey",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        if (content != null) {
          dynamic decoded = jsonDecode(content);

          if (decoded is Map<String, dynamic> && decoded.containsKey('items')) {
            List items = decoded['items'];
            return items.map((e) => {
              "word": e["word"]?.toString() ?? "",
              "context": e["context"]?.toString() ?? ""
            }).toList();
          } else {
            throw Exception("Unexpected JSON format from AI: $content");
          }
        }
      } else {
        throw Exception(
          "OpenAI API Error: ${response.statusCode} - ${response.body}",
        );
      }

      throw Exception("Empty response from AI");
    } catch (e) {
      print("OpenAI Vision Error: $e");
      rethrow;
    }
  }
}
