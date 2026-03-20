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
  final FirestoreService _dbService = FirestoreService();
  final AIService _aiService = AIService();

  final _wordController = TextEditingController();
  final _contextController = TextEditingController();
  final _defController = TextEditingController();
  final _trController = TextEditingController();
  final _exController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _step2Key = GlobalKey();


  final _wordFocus = FocusNode();
  final _contextFocus = FocusNode();
  final _defFocus = FocusNode();

  String? _selectedCollectionId;
  String _selectedContextType = 'Academy';
  bool _isLoading = false;
  bool _showSecondaryFields = false;
  bool _showOptionalFields = false;

  // Track inputs at last generation to toggle "Again" text
  String? _lastGenWord;
  String? _lastGenContext;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    if (widget.collectionId != null) {
      _selectedCollectionId = widget.collectionId;
    }

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
    _scrollController.dispose();
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
        _contextController.text,
        _selectedCollectionId!,
        contextType: _selectedContextType,
      );
      final word = Word(
        collectionId: data['collection_id'],
        word: data['word'] ?? '',
        definition: data['definition'] ?? '',
        translation: data['translation'] ?? '',
        contextualInfo: data['contextual_info'] ?? '',
      );

      setState(() {
        _defController.text = word.definition;
        _trController.text = word.translation;
        _exController.text = word.contextualInfo;
        _showSecondaryFields = true;
        _showOptionalFields = true;
        
        // Save current state as "last generated"
        _lastGenWord = _wordController.text;
        _lastGenContext = _contextController.text;
      });
    } catch (e) {
      SnackbarHelper.showError(context, "AI Error: $e");
    } finally {
      setState(() => _isLoading = false);
      // Auto-scroll to show Step 2 (Modes and Details)
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_step2Key.currentContext != null) {
          Scrollable.ensureVisible(
            _step2Key.currentContext!,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            alignment: 0.0, // Scroll to the very top
          );
        }
      });
    }
  }

  void _onCollectionChanged(String? val) async {
    if (val == null) return;
    setState(() => _selectedCollectionId = val);

    final collections = await _dbService.getEditableCollectionsStream().first;
    final selected = collections.where((c) => c.id == val).firstOrNull;
    if (selected != null) {
      setState(() => _selectedContextType = selected.contextType);
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
          translation: _trController.text.trim(),
          contextualInfo: _exController.text.trim(),
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
      _showOptionalFields = false;
      _wordFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentColor;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // ✅ Klavye kapanır
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),

                  // --- Collection Selector ---
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
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2)),
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
                              onChanged: _onCollectionChanged,
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
                        side: BorderSide(
                            color: Colors.white.withOpacity(0.15)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // --- Step 1 ---
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
                        textInputAction: TextInputAction.next,
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
                        onChanged: (val) => setState(() {}),
                        onSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_contextFocus);
                        },
                      ),
                      if (_wordController.text.isNotEmpty || _isLoading)
                        Positioned(
                          right: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_wordController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white30, size: 20),
                                  onPressed: () {
                                    _wordController.clear();
                                    setState(() {});
                                  },
                                  tooltip: "Clear",
                                ),
                              if (_wordController.text.isNotEmpty &&
                                  !_showSecondaryFields)
                                IconButton(
                                  icon: const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.amber,
                                  ),
                                  onPressed: _generateAI,
                                  tooltip: "AI Magic Fill",
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --- Secondary Fields ---
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
                            hint:
                                "meaning, definition, or example sentence...",
                            icon: Icons.lightbulb_outline,
                            focusNode: _contextFocus,
                            onSubmitted: (_) => _generateAI(),
                          ),
                          const SizedBox(height: 20),

                          // --- AI Mode Switcher ---
                          Center(
                            key: _step2Key,
                            child: Container(
                              height: 44,
                              constraints:
                                  const BoxConstraints(maxWidth: 400),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  {
                                    'id': 'Academy',
                                    'icon': Icons.school_outlined,
                                    'label': 'Academy',
                                  },
                                  {
                                    'id': 'Cinema',
                                    'icon': Icons.movie_outlined,
                                    'label': 'Cinema',
                                  },
                                  {
                                    'id': 'Practical',
                                    'icon': Icons.chat_bubble_outline,
                                    'label': 'Practical',
                                  },
                                ].map((mode) {
                                  final bool isSelected =
                                      _selectedContextType == mode['id'];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    child: GestureDetector(
                                      onTap: () => setState(() =>
                                          _selectedContextType =
                                              mode['id'] as String),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.amber.withOpacity(0.9)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.amber
                                                        .withOpacity(0.2),
                                                    blurRadius: 10,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        alignment: Alignment.center,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            children: [
                                              Icon(
                                                mode['icon'] as IconData,
                                                size: 14,
                                                color: isSelected
                                                    ? Colors.black
                                                    : Colors.white60,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                mode['label'] as String,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? Colors.black
                                                      : Colors.white60,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // --- AI Button ---
                          Center(
                            child: TextButton.icon(
                              onPressed: _isLoading ? null : _generateAI,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.amber,
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome,
                                      color: Colors.amber),
                              label: Text(
                                _isLoading
                                    ? "Thinking..."
                                    : (_lastGenWord == _wordController.text &&
                                            _lastGenContext ==
                                                _contextController.text)
                                        ? "Generate with AI again"
                                        : "Generate with AI",
                                style: TextStyle(
                                    color: Colors.amber.shade200),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor:
                                    Colors.amber.withOpacity(0.1),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // --- Optional Fields ---
                          ExpandableSection(
                            isExpanded: _showOptionalFields,
                            title: "Word Details (Meaning, Def, Example)",
                            icon: Icons.edit_note,
                            onToggle: () => setState(
                              () => _showOptionalFields =
                                  !_showOptionalFields,
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

                          // --- Save Button ---
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
        ),
      ),
    );
  }
}