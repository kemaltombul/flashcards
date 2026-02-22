import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';
import '../models/word.dart';
import '../widgets/collection_selector.dart';
import '../widgets/zen_input_field.dart';
import '../widgets/expandable_section.dart';
import '../dialogs/scan_dialog.dart';
import '../constants/app_theme.dart';
import '../utils/snackbar_helper.dart';

class AddWordPage extends StatefulWidget {
  final String? collectionId;
  const AddWordPage({super.key, this.collectionId});

  @override
  State<AddWordPage> createState() => _AddWordPageState();
}

class _AddWordPageState extends State<AddWordPage>
    with AutomaticKeepAliveClientMixin {
  // Logic
  final FirestoreService _dbService = FirestoreService();
  final AIService _aiService = AIService();

  final _wordController = TextEditingController();
  final _contextController = TextEditingController(); // New context input
  final _defController = TextEditingController();
  final _trController = TextEditingController();
  final _exController = TextEditingController();

  final _wordFocus = FocusNode();
  final _contextFocus = FocusNode(); // Focus for context input
  final _defFocus = FocusNode();

  String? _selectedCollectionId;
  bool _isLoading = false;
  bool _showSecondaryFields = false;
  bool _showOptionalFields = false;

  // Mock Data

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    if (widget.collectionId != null) {
      _selectedCollectionId = widget.collectionId;
    }

    // Auto-show secondary fields if word is typed (simple heuristic)
    _wordController.addListener(() {
      if (_wordController.text.isNotEmpty && !_showSecondaryFields) {
        setState(() => _showSecondaryFields = true);
      }
    });
  }

  @override
  void dispose() {
    _wordController.dispose();
    _contextController.dispose();
    _defController.dispose();
    _trController.dispose();
    _exController.dispose();
    _wordFocus.dispose();
    _contextFocus.dispose();
    _defFocus.dispose();
    super.dispose();
  }

  void _generateAI() async {
    if (_wordController.text.trim().isEmpty) return;
    if (_selectedCollectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Select a collection first!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = await _aiService.generateSmartWord(
        _wordController.text,
        _contextController.text, // Use dedicated context input
        _selectedCollectionId!,
      );
      final word = Word.fromMap(data);

      setState(() {
        _defController.text = word.definition;
        _trController.text = word.meaningTr;
        _exController.text = word.example;
        _showSecondaryFields = true;
      });
    } catch (e) {
      SnackbarHelper.showError(context, "AI Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveWord() async {
    if (_wordController.text.isEmpty || _trController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fill in at least Word and Meaning."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedCollectionId == null) {
      SnackbarHelper.showWarning(context, "Select a collection!");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _dbService.insertWord(
        Word(
          collectionId: _selectedCollectionId!,
          word: _wordController.text.trim(),
          definition: _defController.text.trim(),
          meaningTr: _trController.text.trim(),
          example: _exController.text.trim(),
        ),
      );

      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          "Word Added! Keep the streak alive! 🔥",
        );
        _clearForm();
      }
    } catch (e) {
      SnackbarHelper.showError(context, "Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    setState(() {
      _wordController.clear();
      _contextController.clear();
      _defController.clear();
      _trController.clear();
      _exController.clear();
      _showSecondaryFields = false;
      _wordFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    final accentColor = AppTheme.accentColor;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent background squish
      backgroundColor: Colors.transparent,
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 30,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // --- Collection Selector (Pill) ---
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.folder_open_rounded,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: CollectionSelector(
                            selectedId: _selectedCollectionId,
                            onChanged: (val) =>
                                setState(() => _selectedCollectionId = val),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // --- Camera Button ---
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (c) => ScanDialog(
                          preselectedCollectionId: _selectedCollectionId,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                    label: const Text(
                      "Scan from Camera",
                      style: TextStyle(color: Colors.white70),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      shape: const StadiumBorder(),
                      side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                // --- Hero Input ---
                Center(
                  child: Text(
                    "STEP 1: ENTER WORD",
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    TextField(
                      controller: _wordController,
                      focusNode: _wordFocus,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.next, // Move to next field
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: "Type a word...",
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 40,
                        ),
                      ),
                      onSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_contextFocus);
                      },
                    ),
                    if (_isLoading)
                      const Positioned(
                        right: 0,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_wordController.text.isNotEmpty && !_showSecondaryFields)
                      Positioned(
                        right: 0,
                        child: IconButton(
                          icon: const Icon(
                            Icons.auto_awesome,
                            color: Colors.amber,
                          ),
                          onPressed: _generateAI,
                          tooltip: "AI Magic Fill",
                        ),
                      ),
                  ],
                ),


                const SizedBox(height: 40),

                // --- Fluid Secondary Fields ---
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _showSecondaryFields ? 1.0 : 0.0,
                  child: Column(
                    children: [
                      if (_showSecondaryFields) ...[
                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            "STEP 2: CONTEXT (OPTIONAL)",
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        ZenInputField(
                          controller: _contextController,
                          hint: "meaning, definition, or example sentence...",
                          icon: Icons.lightbulb_outline,
                          focusNode: _contextFocus,
                          onSubmitted: (_) => _generateAI(),
                        ),
                        const SizedBox(height: 15),
                        
                        // AI Button (Explicit)
                        Center(
                          child: TextButton.icon(
                            onPressed: _isLoading ? null : _generateAI,
                            icon: _isLoading 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                                : const Icon(Icons.auto_awesome, color: Colors.amber),
                            label: Text(_isLoading ? "Thinking..." : "Generate with AI", style: TextStyle(color: Colors.amber.shade200)),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.amber.withOpacity(0.1),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Optional Fields - Expandable Section
                        ExpandableSection(
                          isExpanded: _showOptionalFields,
                          title: "Word Details (Meaning, Def, Example)",
                          icon: Icons.edit_note,
                          onToggle: () => setState(
                            () => _showOptionalFields = !_showOptionalFields,
                          ),
                          child: Column(
                            children: [
                              ZenInputField(
                                controller: _trController,
                                hint: "Turkish Meaning",
                                icon: Icons.translate,
                              ),
                              const SizedBox(height: 15),
                              ZenInputField(
                                controller: _defController,
                                hint: "English Definition",
                                icon: Icons.menu_book,
                                focusNode: _defFocus,
                              ),
                              const SizedBox(height: 15),
                              ZenInputField(
                                controller: _exController,
                                hint: "Example Sentence",
                                icon: Icons.format_quote_rounded,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: _isLoading ? null : _saveWord,
                            child: const Text(
                              "Save Word",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ), // SizedBox
    ); // Scaffold
  }
}
