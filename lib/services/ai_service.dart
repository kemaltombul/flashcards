import 'dart:convert';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'database_service.dart';

class AIService {
  final DatabaseService _dbService = DatabaseService();

  // OpenAI API Configuration
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? ""; 

  AIService() {
    // Initialize OpenAI
    OpenAI.apiKey = _apiKey;
    // Optional: Organization ID if needed
    // OpenAI.organization = "YOUR_ORGANIZATION_ID";
  }

  /// Generates a word with details using AI but DOES NOT save it.
  /// Returns the word data as a Map.
  Future<Map<String, dynamic>> generateSmartWord(String inputWord, String? userDefinition, int collectionId) async {
    try {
      // 1. Input Validation
      if (inputWord.trim().isEmpty) {
        throw Exception("Input word cannot be empty.");
      }

      String normalizedWord = inputWord.trim();

      // 2. Database Validation (Uniqueness Check)
      // If user provides a context/meaning, we check if THAT specific meaning exists.
      if (userDefinition != null && userDefinition.isNotEmpty) {
         bool specificExists = await _dbService.wordAndMeaningExists(normalizedWord, userDefinition);
         if (specificExists) {
           throw Exception("Word '$normalizedWord' with meaning '$userDefinition' already exists.");
         }
      } else {
        // Fallback: If no context provided, block if word exists at all to be safe
        bool exists = await _dbService.wordExists(normalizedWord);
        if (exists) {
           throw Exception("Word '$normalizedWord' already exists. Add a specific meaning to add a new definition.");
        }
      }

      // 3. API Request (Enrichment)
      final Map<String, dynamic> aiData = await _fetchWordDetailsFromAI(normalizedWord, context: userDefinition);

      // 4. Return Data (instead of saving)
      return {
        'collection_id': collectionId,
        'word': aiData['word'], 
        'definition': aiData['definition'],
        'meaning_tr': aiData['meaning_tr'],
        'example': aiData['example']
      };

    } catch (e) {
      rethrow; 
    }
  }

  /// Private helper to call the OpenAI API.
  Future<Map<String, dynamic>> _fetchWordDetailsFromAI(String word, {String? context}) async {
    
    // Detect if the "word" itself is actually a sentence (heuristic: > 2 words or contains punctuation?)
    // If so, we treat the input string as the context, and ask the AI to extract the word.
    bool inputIsSentence = word.trim().contains(' ') && (word.trim().split(' ').length > 2);
    
    if (inputIsSentence && (context == null || context.trim().isEmpty)) {
      context = word; 
      // We don't clear 'word' here to let the prompt know what the user typed, 
      // but we add a specific instruction below.
    }

    String contextInstruction = "";
    if (context != null && context.trim().isNotEmpty) {
      contextInstruction = """
\nCONTEXT INSTRUCTION (CRITICAL):
The user provided this specific context/sentence: "$context".
1. **Grammar Analysis (CRITICAL)**: First, determine the grammatical role (Part of Speech) of the word "$word" IN THIS SPECIFIC SENTENCE.
   - Is it a Verb, Noun, Adjective, etc.?
   - IGNORE semantic bias from other words (e.g. ignore "cola" if "can" is used as a verb).
   - Example: "Can you open the cola?" -> "Can" is a Modal Verb here. Do NOT define it as "Kutu" just because "cola" is present.
2. **Meaning**: Provide the GENERAL dictionary meaning that matches that grammatical role.
   - If it's a verb, give the verb meaning. If it's a noun, give the noun meaning.
3. **Usage**: Use this context sentence as the "example" field if it is suitable (A1 level).
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

    // Construct the prompt
    final String prompt = """
Role: Dictionary assistant for A1 (Beginner) English learners.
Input Word/Sentence: "$word".
$contextInstruction
$extractionInstruction

Rules:
1. Definition: Must be **CEFR A1 Level**. Use ONLY basic, high-frequency words. Max 12 words. Simple and clear.
2. Accuracy: Provide the correct Turkish meaning (matching the context if given) and a correct, simple example sentence (A1).
3. Output: JSON only.

Returns: {"word": "...", "definition": "...", "meaning_tr": "...", "example": "..."}
    """;

    try {
      final systemMessage = OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
            prompt,
          ),
        ],
        role: OpenAIChatMessageRole.system,
      );

      String userContent = "Word: $word";
      if (context != null && context.trim().isNotEmpty) {
        userContent += "\nSpecific Context/Meaning: $context (Focus ONLY on this meaning)";
      }

      final userMessage = OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
            userContent,
          ),
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
        final content = chatCompletion.choices.first.message.content?.first.text;
        
        if (content != null) {
          // Clean potential markdown just in case
          String cleanJson = content.trim();
          if (cleanJson.startsWith('```json')) {
            cleanJson = cleanJson.replaceAll('```json', '').replaceAll('```', '');
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
}

