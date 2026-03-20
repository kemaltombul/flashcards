import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../models/word.dart';
import '../widgets/collection_selector.dart';

class ScanDialog extends StatefulWidget {
  final String? preselectedCollectionId;

  const ScanDialog({super.key, this.preselectedCollectionId});

  @override
  State<ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<ScanDialog> {
  final AIService _aiService = AIService();
  final FirestoreService _dbService = FirestoreService();

  File? _image;
  bool _isAnalyzing = false;
  bool _isProcessing = false;

  List<Map<String, String>> _detectedWords = [];
  final Set<int> _selectedIndices = {};

  String _globalContextType = 'Academy';
  String? _selectedCollectionId;

  final ImagePicker _picker = ImagePicker();

  final Color _backgroundColor = const Color(0xFF1E1E1E);
  final Color _cardColor = const Color(0xFF2C2C2C);
  final Color _accentColor = const Color(0xFFBB86FC);

  static const _modes = [
    {'id': 'Academy',   'icon': Icons.school_outlined,    'label': 'Academy'},
    {'id': 'Cinema',    'icon': Icons.movie_outlined,      'label': 'Cinema'},
    {'id': 'Practical', 'icon': Icons.chat_bubble_outline, 'label': 'Practical'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCollectionId = widget.preselectedCollectionId;
  }

  // ── Image ───────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _detectedWords = [];
          _selectedIndices.clear();
          _isAnalyzing = true;
        });
        await _analyzeImage(pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error picking image: $e")));
      }
    }
  }

  Future<void> _analyzeImage(XFile imageFile) async {
    try {
      final words = await _aiService.extractWordsFromImage(imageFile);
      if (mounted) {
        if (words.isEmpty) {
          setState(() => _isAnalyzing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No underlined or highlighted words found."),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          setState(() {
            _detectedWords = words;
            _selectedIndices.addAll(Iterable.generate(words.length));
            _isAnalyzing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("AI Analysis failed: $e")));
      }
    }
  }

  // ── Processing ──────────────────────────────

  Future<void> _processWords() async {
    if (_selectedIndices.isEmpty || _selectedCollectionId == null) return;
    setState(() => _isProcessing = true);

    int success = 0;
    int failed = 0;

    for (final index in _selectedIndices) {
      if (!mounted) break;
      final wordData    = _detectedWords[index];
      final wordText    = wordData['word'] ?? '';
      final contextText = wordData['context'] ?? '';
      final wordType    = wordData['type'] ?? 'word';

      if (wordText.isEmpty) continue;

      try {
        final aiData = await _aiService.generateSmartWord(
          wordText,
          contextText.isNotEmpty ? contextText : null,
          _selectedCollectionId!,
          contextType: _globalContextType,
          wordType: wordType,
        );

        await _dbService.insertWord(Word(
          collectionId: _selectedCollectionId!,
          word: aiData['word'],
          definition: aiData['definition'],
          translation: aiData['translation'],
          contextualInfo: aiData['contextual_info'],
        ));
        success++;
      } catch (e) {
        failed++;
        debugPrint("Failed to add $wordText: $e");
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Added $success words${failed > 0 ? ', $failed failed' : ''}."),
          backgroundColor: success > 0 ? Colors.green : Colors.red,
        ),
      );
      if (success > 0) Navigator.pop(context);
    }
  }

  // ── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selected   = _detectedWords.asMap().entries
        .where((e) => _selectedIndices.contains(e.key)).toList();
    final unselected = _detectedWords.asMap().entries
        .where((e) => !_selectedIndices.contains(e.key)).toList();

    return Dialog(
      backgroundColor: _backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 10, 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Scan from Image",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  // Collection Selector
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CollectionSelector(
                      selectedId: _selectedCollectionId,
                      label: "Target Collection",
                      onChanged: (val) =>
                          setState(() => _selectedCollectionId = val),
                    ),
                  ),

                  // Image Preview
                  if (_image != null)
                    Container(
                      height: 300,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: FileImage(_image!),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isAnalyzing
                          ? Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text("Analyzing...",
                                    style: TextStyle(color: Colors.white)),
                              ),
                            )
                          : null,
                    )
                  else
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Container(
                        height: 200,
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined,
                                  size: 50, color: Colors.white24),
                              SizedBox(height: 10),
                              Text("Tap to take photo",
                                  style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Camera / Gallery Buttons
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Camera"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 20),
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text("Gallery"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accentColor,
                          side: BorderSide(color: _accentColor),
                        ),
                      ),
                    ],
                  ),

                  // ── Detected Words Section ──────────────
                  if (_detectedWords.isNotEmpty) ...[
                    const Divider(color: Colors.white24, height: 40),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Detected Words (${_selectedIndices.length})",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _accentColor),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Global Mode Switcher
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Mode",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 11,
                                letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          _buildModeSwitcher(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Seçili kelimeler
                    if (selected.isNotEmpty) ...[
                      _buildGroupLabel("Selected", Colors.white70),
                      ...selected.map((e) => _buildWordCard(e.key)),
                    ],

                    // Seçilmeyenler
                    if (unselected.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildGroupLabel("Not selected", Colors.white30),
                      ...unselected.map((e) => _buildWordCard(e.key)),
                    ],

                    // Add Button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processWords,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text("Add Selected Words",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Group Label ──────────────────────────────

  Widget _buildGroupLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── Word Card ────────────────────────────────

  Widget _buildWordCard(int index) {
    final wordData    = _detectedWords[index];
    final wordText    = wordData['word'] ?? '';
    final contextText = wordData['context'] ?? '';
    final isSelected  = _selectedIndices.contains(index);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? _accentColor.withOpacity(0.4)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      child: CheckboxListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(wordText,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold)),
        subtitle: contextText.isNotEmpty
            ? Text(
                contextText,
                style: TextStyle(
                    color: isSelected
                        ? Colors.white.withOpacity(0.45)
                        : Colors.white.withOpacity(0.2),
                    fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        value: isSelected,
        activeColor: _accentColor,
        checkColor: Colors.black,
        onChanged: (val) => setState(() {
          if (val == true) {
            _selectedIndices.add(index);
          } else {
            _selectedIndices.remove(index);
          }
        }),
      ),
    );
  }

  // ── Global Mode Switcher ─────────────────────

  Widget _buildModeSwitcher() {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: _modes.map((mode) {
          final bool isActive = _globalContextType == mode['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _globalContextType = mode['id']! as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.amber.withOpacity(0.9)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(mode['icon'] as IconData,
                        size: 14,
                        color: isActive ? Colors.black : Colors.white54),
                    const SizedBox(width: 5),
                    Text(
                      mode['label']! as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.black : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}