import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/word.dart';
import '../models/collection.dart';
import '../services/ai_service.dart';


enum AddMode { manual, smart, json }

/// Page for adding a new word to a specific collection.
class AddWordPage extends StatefulWidget {
  final int? collectionId;
  const AddWordPage({super.key, this.collectionId});

  @override
  State<AddWordPage> createState() => _AddWordPageState();
}

class _AddWordPageState extends State<AddWordPage> {
  AddMode _currentMode = AddMode.smart;
  bool _isLoading = false;
  List<Collection> _collections = [];
  int? _selectedCollectionId;
  
  // Auto-Save Logic
  Timer? _autoSaveTimer;
  double _autoSaveProgress = 0.0;
  bool _isAutoSaving = false;
  
  final _formKey = GlobalKey<FormState>();
  
  final _wordController = TextEditingController();
  final _defController = TextEditingController();
  final _trController = TextEditingController();
  final _exController = TextEditingController();
  final _jsonController = TextEditingController(); 
  
  // Focus Nodes
  final _wordFocus = FocusNode();
  final _defFocus = FocusNode();
  final _trFocus = FocusNode();
  final _exFocus = FocusNode();
  
  final DatabaseService _dbService = DatabaseService();
  final AIService _aiService = AIService();

  @override
  void initState() {
    super.initState();
    if (widget.collectionId != null) {
      _selectedCollectionId = widget.collectionId!;
    }
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final cols = await _dbService.getCollections();
    setState(() {
      _collections = cols;
      if (_collections.isNotEmpty) {
        // If no ID passed, or passed ID not in list, default to first
        bool idExists = widget.collectionId != null && _collections.any((c) => c.id == widget.collectionId);
        _selectedCollectionId = idExists ? widget.collectionId! : _collections.first.id!;
      }
    });
  }

  @override
  void dispose() {
    _wordController.dispose();
    _defController.dispose();
    _trController.dispose();
    _exController.dispose();
    _jsonController.dispose();
    _wordFocus.dispose();
    _defFocus.dispose();
    _trFocus.dispose();
    _exFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if Mobile or Web
    bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    Widget content = Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Row(
                children: [
                  if (widget.collectionId != null) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 22, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 15),
                  ],
                  const Text("Add Word", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
            const Text(
              "Learn a new word!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
            ),
            const SizedBox(height: 5),
            const Text("Choose input method below.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // Mode Selector
            _buildModeSelector(),
            const SizedBox(height: 30),

            // Content Switching
            if (_currentMode == AddMode.manual) _buildManualMode(),
            if (_currentMode == AddMode.smart) _buildSmartMode(),
            if (_currentMode == AddMode.json) _buildJsonMode(),
          ],
        ),
      ),
    ),
    );

    // Constrain layout for Web/Desktop
    return content;
  }

  // --- Widgets ---

  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildModeButton(AddMode.smart, "Smart AI", Icons.auto_awesome),
          const SizedBox(width: 5),
          _buildModeButton(AddMode.json, "JSON", Icons.data_object),
          const SizedBox(width: 5),
          _buildModeButton(AddMode.manual, "Manual", Icons.edit_note),
        ],
      ),
    );
  }

  Widget _buildModeButton(AddMode mode, String label, IconData icon) {
    bool isSelected = _currentMode == mode;
    return Expanded(
      flex: isSelected ? 3 : 1, // Expand selected
      child: GestureDetector(
        onTap: () => setState(() => _currentMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualMode() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildModernTextField(
            controller: _wordController,
            label: "English Word",
            icon: Icons.translate,
            focusNode: _wordFocus,
            nextFocus: _defFocus,
            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a word' : null,
          ),
          const SizedBox(height: 15),
          _buildModernTextField(
            controller: _defController,
            label: "English Definition",
            icon: Icons.menu_book,
            focusNode: _defFocus,
            nextFocus: _trFocus,
            capitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 15),
          _buildModernTextField(
            controller: _trController,
            label: "Turkish Meaning",
            icon: Icons.language,
            focusNode: _trFocus,
            nextFocus: _exFocus,
            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a meaning' : null,
            capitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 15),
          _buildModernTextField(
            controller: _exController,
            label: "Example Sentence",
            icon: Icons.format_quote_rounded,
            maxLines: 2,
            focusNode: _exFocus,
            isLast: true,
            capitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _saveWord(),
          ),
          const SizedBox(height: 20),
          _buildCollectionSelector(),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 4,
              ),
              onPressed: _isLoading ? null : _saveWord,
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("SAVE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartMode() {
    return Column(
      children: [
        const Text(
          "Let AI do the work!",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
        ),
        const SizedBox(height: 5),
        const Text(
          "Enter a word, and we'll fill in the definition, meaning, and example.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 25),
        _buildModernTextField(
          controller: _wordController,
          label: "English Word",
          icon: Icons.auto_awesome,
          focusNode: _wordFocus,
          nextFocus: _defFocus,
          validator: (v) => v == null || v.trim().isEmpty ? 'Enter a word for AI' : null,
        ),
        const SizedBox(height: 15),
        _buildModernTextField(
          controller: _defController,
          label: "Optional Context/Definition",
          icon: Icons.lightbulb_outline,
          maxLines: 2,
          focusNode: _defFocus,
          isLast: true,
          capitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _smartAddWord(),
        ),
         const SizedBox(height: 20),
        _buildCollectionSelector(),
         const SizedBox(height: 30),

        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
              foregroundColor: Colors.amber, 
              side: const BorderSide(color: Colors.amber),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: _isLoading ? null : _smartAddWord,
            icon: _isLoading 
              ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2), child: const CircularProgressIndicator(color: Colors.amber, strokeWidth: 2)) 
              : const Icon(Icons.auto_awesome),
            label: Text(_isLoading ? "GENERATING..." : "SMART ADD", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  void _showPreviewBottomSheet(Word word) {
    ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
    Timer? localTimer;
    bool isCancelled = false;

    // Start Timer
    const duration = Duration(milliseconds: 50);
    const totalSteps = 160; // 8 seconds / 50ms
    int currentStep = 0;

    localTimer = Timer.periodic(duration, (timer) {
      if (isCancelled) {
        timer.cancel();
        return;
      }
      currentStep++;
      progressNotifier.value = currentStep / totalSteps;

      if (currentStep >= totalSteps) {
        timer.cancel();
        Navigator.pop(context); // Close sheet
        _savePreview(word);     // Save
      }
    });

    void cancelAutoSave() {
      if (!isCancelled) {
        isCancelled = true;
        localTimer?.cancel();
        progressNotifier.value = -1.0; // Signal cancellation
      }
    }

    // Controller for programmatic expansion
    final DraggableScrollableController sheetController = DraggableScrollableController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
               cancelAutoSave();
            }
            return false;
          },
          child: DraggableScrollableSheet(
            controller: sheetController,
            initialChildSize: 0.25, 
            minChildSize: 0.25,
            maxChildSize: 0.7,
            snap: true, // Snap between min and max
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                   borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 50, height: 5,
                          margin: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10)),
                        )
                      ),

                      // Animated Progress Bar
                      ValueListenableBuilder<double>(
                        valueListenable: progressNotifier,
                        builder: (context, value, child) {
                          if (value < 0) {
                             return const Padding(
                              padding: EdgeInsets.only(bottom: 15),
                              child: Center(child: Text("Auto-save cancelled", style: TextStyle(color: Colors.grey, fontSize: 11))),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: LinearProgressIndicator(
                              value: value,
                              backgroundColor: Colors.white10,
                              color: Colors.amber,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        },
                      ),

                      // Always Visible Part
                      Text(word.word, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 5),
                      Text(word.meaningTr, style: const TextStyle(fontSize: 22, color: Colors.deepPurpleAccent, fontStyle: FontStyle.italic)),
                      
                      const SizedBox(height: 25),
                      const Divider(color: Colors.white12),
                      
                      // Tap to Expand Area
                      GestureDetector(
                        onTap: () {
                          cancelAutoSave();
                          sheetController.animateTo(
                            0.7, 
                            duration: const Duration(milliseconds: 300), 
                            curve: Curves.easeOut
                          );
                        },
                        behavior: HitTestBehavior.opaque, // Catch taps
                        child: ValueListenableBuilder<double>(
                          valueListenable: progressNotifier,
                          builder: (c, v, _) {
                              final remaining = (8 - (v * 8)).ceil();
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Center(
                                    child: Text(v >= 0 ? "Saving in ${remaining}s... Tap to Expand" : "Swipe or Tap for details", 
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
                                ),
                              );
                          }
                        ),
                      ),
                      
                      const SizedBox(height: 10),

                      // Hidden/Expandable Part
                      _buildPreviewRow(Icons.menu_book, "Definition", word.definition),
                      const SizedBox(height: 20),
                      _buildPreviewRow(Icons.format_quote_rounded, "Example", word.example),
                      
                      const SizedBox(height: 35),
                      
                       Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                cancelAutoSave();
                                Navigator.pop(context); 
                                _editPreview(word);
                              },
                              icon: const Icon(Icons.edit, size: 20),
                              label: const Text("EDIT"),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                 cancelAutoSave();
                                 Navigator.pop(context);
                                 await _savePreview(word);
                              },
                              icon: const Icon(Icons.check_circle, size: 22),
                              label: const Text("SAVE NOW"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      cancelAutoSave();
    });
  }

  Widget _buildPreviewRow(IconData icon, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 5), Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600))]),
        const SizedBox(height: 6),
        Text(content, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4)),
      ],
    );
  }



  Widget _buildJsonMode() {
    return Column(
      children: [
        const Text(
          "Bulk Import (JSON)",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
        ),
        const SizedBox(height: 10),
        const Text(
          "Paste a JSON array of words below.",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 10),
        _buildModernTextField(
          controller: _jsonController, 
          label: "Paste JSON Here", 
          icon: Icons.data_array, 
          minLines: 3,
          maxLines: 10,
        ),
        const SizedBox(height: 20),
        _buildCollectionSelector(),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.deepPurple),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: _importJson,
            icon: const Icon(Icons.download),
            label: const Text("IMPORT JSON", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    int? minLines,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    bool isLast = false,
    String? Function(String?)? validator,
    TextCapitalization capitalization = TextCapitalization.none,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      minLines: minLines,
      style: const TextStyle(color: Colors.white),
      textCapitalization: capitalization,
      textInputAction: isLast ? TextInputAction.done : (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
      validator: validator,
      onFieldSubmitted: (val) {
        if (onSubmitted != null) {
          onSubmitted(val);
        } else if (nextFocus != null) {
          FocusScope.of(context).requestFocus(nextFocus);
        }
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: Colors.deepPurpleAccent),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
      ),
    );
  }

  Widget _buildCollectionSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // adjusted vertical to account for internal button height
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: _collections.isEmpty 
          ? const Center(child: Text("No collections. Please create one.", style: TextStyle(color: Colors.redAccent)))
          : DropdownButton<int>(
          value: _selectedCollectionId,
          hint: const Text("Select Collection", style: TextStyle(color: Colors.white54)),
          isExpanded: true,
          dropdownColor: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: _collections.map((col) {
            return DropdownMenuItem<int>(
              value: col.id,
              child: Row(
                children: [
                   Icon(
                    col.isGame ? Icons.videogame_asset : Icons.book, 
                    size: 18, 
                    color: Colors.grey
                  ),
                  const SizedBox(width: 10),
                  Text(col.name ?? "Unknown"),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedCollectionId = val);
            }
          },
        ),
      ),
    );
  }

  // --- Mode Actions ---

  Future<void> _saveWord() async {
    if (_selectedCollectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a collection!"), backgroundColor: Colors.orange));
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true); // Visualize loading
      try {
        await _dbService.insertWord(Word(
          collectionId: _selectedCollectionId!,
          word: _wordController.text.trim(),
          definition: _defController.text.trim(),
          meaningTr: _trController.text.trim(),
          example: _exController.text.trim().isEmpty ? "" : _exController.text.trim(),
        ));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Successfully Added!"), backgroundColor: Colors.green));
          _clearFields();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _smartAddWord() async {
    if (_wordController.text.trim().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a word first!"), backgroundColor: Colors.orange));
       return;
    }

    if (_selectedCollectionId == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a collection!"), backgroundColor: Colors.orange));
       return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus(); 

    try {
      final Map<String, dynamic> aiData = await _aiService.generateSmartWord(
        _wordController.text, 
        _defController.text.isNotEmpty ? _defController.text : null,
        _selectedCollectionId!
      );

      if (mounted) {
        Word previewWord = Word.fromMap(aiData);
        _showPreviewBottomSheet(previewWord);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreview(Word word) async {
    try {
      await _dbService.insertWord(word);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Successfully Added!"), backgroundColor: Colors.green));
        _clearFields();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error Saving: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _editPreview(Word word) {
    // Switch to Manual Mode and populate fields
    setState(() {
      _wordController.text = word.word;
      _defController.text = word.definition;
      _trController.text = word.meaningTr;
      _exController.text = word.example;
      _currentMode = AddMode.manual;
    });
  }

  Future<void> _importJson() async {
    String jsonString = _jsonController.text.trim();
    if (jsonString.isEmpty) return;
    
    if (_selectedCollectionId == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a collection!"), backgroundColor: Colors.orange));
       return;
    }

    try {
      if (!jsonString.startsWith('[') && !jsonString.endsWith(']')) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid JSON: Must be a list [...]"), backgroundColor: Colors.red),
        );
        return;
      }

      List<dynamic> data = jsonDecode(jsonString);
      
      var stats = await _dbService.importWordsWithDeduplication(_selectedCollectionId!, data);
      
      int imported = stats['inserted'] ?? 0;
      int skipped = stats['skipped'] ?? 0;

      if (mounted) {
        String message = "Imported $imported words.";
        if (skipped > 0) {
          message += " $skipped duplicates skipped.";
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message), 
            backgroundColor: imported > 0 ? Colors.green : Colors.orange
          ),
        );

        if (imported > 0) {
          _jsonController.clear();
        }
      }

    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("JSON Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _clearFields() {
    _wordController.clear();
    _defController.clear();
    _trController.clear();
    _exController.clear();
  }
}