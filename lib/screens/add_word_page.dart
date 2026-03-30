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

class UploadTask {
  String wordText;
  String contextText;
  String collectionId;
  String globalContextType;
  String wordType;

  Word? generatedWord;
  String status; // 'processing', 'ready', 'saved', 'error'
  bool isExpanded;
  bool isSelected;

  UploadTask({
    required this.wordText,
    required this.contextText,
    required this.collectionId,
    required this.globalContextType,
    required this.wordType,
    this.status = 'processing',
    this.generatedWord,
    this.isExpanded = false,
    this.isSelected = true,
  });
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
  PartOfSpeech _selectedPartOfSpeech = PartOfSpeech.unknown;

  // Background Upload State
  final List<UploadTask> _uploadQueue = [];
  bool get _hasActiveUploads => _uploadQueue.isNotEmpty;
  int get _bgTotalWords => _uploadQueue.length;
  int get _bgProcessedWords =>
      _uploadQueue.where((t) => t.status != 'processing').length;
  int get _bgReadyWords =>
      _uploadQueue.where((t) => t.status == 'ready').length;

  final ValueNotifier<int> _queueUpdater = ValueNotifier(0);

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
    _queueUpdater.dispose();
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
      final word = await _aiService.generateSmartWord(
        _wordController.text,
        _contextController.text,
        _selectedCollectionId!,
        contextType: _selectedContextType,
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
        _selectedPartOfSpeech = word.partOfSpeech;
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
      SnackbarHelper.showWarning(context, "Fill in at least Word and Meaning.");
      return;
    }
    if (_selectedCollectionId == null) {
      SnackbarHelper.showWarning(context, "Please select a collection first!");
      return;
    }

    setState(() => _isLoading = true);

    // Koleksiyonun DB'de gerçekten var olduğunu doğrula
    try {
      final collections =
          await _dbService.getEditableCollectionsStream().first;
      final exists = collections.any((c) => c.id == _selectedCollectionId);
      if (!exists) {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            "The selected collection no longer exists. Please choose another.",
          );
          setState(() {
            _isLoading = false;
            _selectedCollectionId = null;
          });
        }
        return;
      }
    } catch (_) {
      // Koleksiyon listesi alınamazsa yine de devam et;
      // insertWord zaten kendi doğrulamasını yapar.
    }

    try {
      await _dbService.insertWord(
        Word(
          collectionId: _selectedCollectionId!,
          word: _wordController.text.trim(),
          definition: _defController.text.trim(),
          translation: _trController.text.trim(),
          contextualInfo: _exController.text.trim(),
          partOfSpeech: _selectedPartOfSpeech,
        ),
      );

      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          "Word Added! Keep the streak alive! 🔥",
        );
        _clearForm();
      }
    } on ArgumentError {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          "Couldn't save the word. The collection may have been deleted.",
        );
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, "Error: $e");
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
      _selectedPartOfSpeech = PartOfSpeech.unknown;
      _wordFocus.requestFocus();
    });
  }

  void _startBackgroundUpload(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) return;

    final newTasks = tasks
        .map(
          (t) => UploadTask(
            wordText: t['wordText'] ?? '',
            contextText: t['contextText'] ?? '',
            collectionId: t['collectionId'] ?? '',
            globalContextType: t['globalContextType'] ?? 'Academy',
            wordType: t['wordType'] ?? 'word',
          ),
        )
        .toList();

    setState(() {
      _uploadQueue.addAll(newTasks);
    });
    _queueUpdater.value++;

    for (var task in newTasks) {
      _processSingleUploadTask(task);
    }
  }

  Future<void> _processSingleUploadTask(UploadTask task) async {
    try {
      task.generatedWord = await _aiService.generateSmartWord(
        task.wordText,
        task.contextText.isNotEmpty ? task.contextText : null,
        task.collectionId,
        contextType: task.globalContextType,
        providedPartOfSpeech: task.wordType,
      );

      task.status = 'ready';
    } catch (e) {
      task.status = 'error';
    }

    if (mounted) {
      setState(() {});
      _queueUpdater.value++;
    }
  }

  void _regenerateTask(UploadTask task) {
    if (task.status == 'processing') return;
    task.status = 'processing';
    _queueUpdater.value++;
    _processSingleUploadTask(task);
  }

  Future<void> _saveSelectedReadyWords() async {
    final readySelectedTasks = _uploadQueue
        .where((t) => t.status == 'ready' && t.isSelected)
        .toList();
    if (readySelectedTasks.isEmpty) return;

    int success = 0;
    int failed = 0;
    for (var task in readySelectedTasks) {
      if (task.generatedWord != null) {
        try {
          await _dbService.insertWord(task.generatedWord!);
          task.status = 'saved';
          success++;
        } on ArgumentError catch (e) {
          task.status = 'error';
          failed++;
          debugPrint('[saveWords] ArgumentError: $e');
        } catch (e) {
          task.status = 'error';
          failed++;
          debugPrint('[saveWords] Error: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _uploadQueue.removeWhere((t) => t.status != 'processing');
      });
      _queueUpdater.value++;
      if (success > 0) {
        SnackbarHelper.showSuccess(
          context,
          "Saved $success word${success > 1 ? 's' : ''} successfully!",
        );
      }
      if (failed > 0) {
        SnackbarHelper.showError(
          context,
          "$failed word${failed > 1 ? 's' : ''} couldn't be saved. Check that the collection exists.",
        );
      }
    }
  }

  void _showReviewBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ValueListenableBuilder<int>(
          valueListenable: _queueUpdater,
          builder: (context, val, child) {
            return _buildReviewSheetContent();
          },
        );
      },
    );
  }

  Widget _buildReviewSheetContent() {
    final readyList = _uploadQueue.where((t) => t.status == 'ready').toList();
    final loadingList = _uploadQueue
        .where((t) => t.status == 'processing')
        .toList();
    final errorList = _uploadQueue.where((t) => t.status == 'error').toList();

    final hasSelectedItems = _uploadQueue.any((t) => t.isSelected);
    final selectedReadyCount = readyList.where((t) => t.isSelected).length;
    final selectedToRegenerateCount = _uploadQueue
        .where((t) => t.isSelected && t.status != 'processing')
        .length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Review Generated Words",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12),

          if (_uploadQueue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          backgroundColor: const Color(0xFF252525),
                          title: const Text(
                            'Are you sure?',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            'Are you sure you want to delete all pending and generated words?',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _uploadQueue.removeWhere(
                                    (t) => t.status != 'processing',
                                  );
                                });
                                _queueUpdater.value++;
                                Navigator.pop(c); // close dialog
                                Navigator.pop(context); // close bottom sheet
                              },
                              child: const Text(
                                'Clear All',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text(
                      "Clear All Queue",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _uploadQueue.isEmpty
                ? const Center(
                    child: Text(
                      "Queue is empty.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (loadingList.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            "Processing...",
                            style: TextStyle(
                              color: Colors.white30,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ...loadingList.map((t) => _buildQueueItem(t)),
                      ],
                      if (errorList.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 16, bottom: 4),
                          child: Text(
                            "Errors",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ...errorList.map((t) => _buildQueueItem(t)),
                      ],
                      if (readyList.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 16, bottom: 4),
                          child: Text(
                            "Ready to Save",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ...readyList.map((t) => _buildQueueItem(t)),
                      ],
                    ],
                  ),
          ),

          if (_uploadQueue.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedReadyCount > 0
                                ? () {
                                    Navigator.pop(context);
                                    _saveSelectedReadyWords();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.grey.shade800,
                              disabledForegroundColor: Colors.white30,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Save Selected ($selectedReadyCount)",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQueueItem(UploadTask task) {
    bool isReady = task.status == 'ready';
    bool isError = task.status == 'error';

    return GestureDetector(
      onTap: () {
        if (isReady && task.generatedWord != null) {
          task.isExpanded = !task.isExpanded;
          _queueUpdater.value++;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError
                ? Colors.redAccent.withOpacity(0.3)
                : isReady
                ? Colors.green.withOpacity(0.3)
                : Colors.white10,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: task.isSelected,
                  activeColor: AppTheme.accentColor,
                  checkColor: Colors.black,
                  side: BorderSide(color: Colors.white.withOpacity(0.5)),
                  onChanged: (val) {
                    if (val != null) {
                      task.isSelected = val;
                      _queueUpdater.value++;
                    }
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              task.wordText,
                              style: TextStyle(
                                color: task.isSelected
                                    ? Colors.white
                                    : Colors.white38,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isReady) ...[
                            const SizedBox(width: 8),
                            Icon(
                              task.isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.white30,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      if (isReady && task.generatedWord != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.generatedWord!.translation,
                          style: TextStyle(
                            color: task.isSelected
                                ? Colors.white70
                                : Colors.white24,
                          ),
                        ),
                      ] else if (isError) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Generation failed.",
                          style: TextStyle(
                            color: Colors.redAccent.withOpacity(
                              task.isSelected ? 1.0 : 0.4,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (task.status == 'processing')
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.amber,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.amber),
                    tooltip: "Regenerate This",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 40,
                    ),
                    onPressed: () => _regenerateTask(task),
                  ),
              ],
            ),
            if (isReady && task.isExpanded && task.generatedWord != null) ...[
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Divider(color: Colors.white12, height: 1),
              ),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(
                      text: "Definition: ",
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: "${task.generatedWord!.definition}\n"),
                    const TextSpan(
                      text: "Context: ",
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: "${task.generatedWord!.contextualInfo}"),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundProgress() {
    double progress = _bgTotalWords > 0
        ? _bgProcessedWords / _bgTotalWords
        : 0.0;
    bool isDone = _bgProcessedWords >= _bgTotalWords && _bgTotalWords > 0;

    return GestureDetector(
      onTap: _showReviewBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? Colors.green.withOpacity(0.5)
                : AppTheme.accentColor.withOpacity(0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isDone
                        ? "$_bgReadyWords words ready to save! Tap here."
                        : "Generating AI... ($_bgProcessedWords/$_bgTotalWords)",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isDone)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentColor,
                    ),
                  )
                else
                  const Icon(Icons.touch_app, color: Colors.green, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDone ? Colors.green : AppTheme.accentColor,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
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
            child: Stack(
              children: [
                SingleChildScrollView(
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

                    

                      // --- Camera Button ---
                      Center(
                        child: TextButton.icon(
                          onPressed: () async {
                            final result = await showDialog(
                              context: context,
                              builder: (c) => ScanDialog(
                                preselectedCollectionId: _selectedCollectionId,
                              ),
                            );
                            if (result != null &&
                                result is List<Map<String, dynamic>>) {
                              _startBackgroundUpload(result);
                            }
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
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                        ),
                      ),
  // --- Collection Selector ---
                        const SizedBox(height: 15),


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
                              color: Colors.white.withOpacity(0.2),
                            ),
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
                      // BURA

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
                              FocusScope.of(
                                context,
                              ).requestFocus(_contextFocus);
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
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white30,
                                        size: 20,
                                      ),
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
                                  constraints: const BoxConstraints(
                                    maxWidth: 400,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children:
                                        [
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
                                              _selectedContextType ==
                                              mode['id'];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 2,
                                            ),
                                            child: GestureDetector(
                                              onTap: () => setState(
                                                () => _selectedContextType =
                                                    mode['id'] as String,
                                              ),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Colors.amber
                                                            .withOpacity(0.9)
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  boxShadow: isSelected
                                                      ? [
                                                          BoxShadow(
                                                            color: Colors.amber
                                                                .withOpacity(
                                                                  0.2,
                                                                ),
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
                                                        mode['icon']
                                                            as IconData,
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
                                                              : FontWeight
                                                                    .normal,
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
                                      : const Icon(
                                          Icons.auto_awesome,
                                          color: Colors.amber,
                                        ),
                                  label: Text(
                                    _isLoading
                                        ? "Thinking..."
                                        : (_lastGenWord ==
                                                  _wordController.text &&
                                              _lastGenContext ==
                                                  _contextController.text)
                                        ? "Generate with AI again"
                                        : "Generate with AI",
                                    style: TextStyle(
                                      color: Colors.amber.shade200,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.amber.withOpacity(
                                      0.1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
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
                if (_hasActiveUploads)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20 - MediaQuery.of(context).viewInsets.bottom,
                    child: _buildBackgroundProgress(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
