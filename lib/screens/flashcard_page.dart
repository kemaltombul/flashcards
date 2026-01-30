import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math';

import '../services/firestore_service.dart';
import '../services/scoring_service.dart';
import '../models/word.dart';
import '../models/telemetry_data.dart';

/// Displays flashcards for a collection, supporting both study and game modes.
class FlashcardPage extends StatefulWidget {
  final String collectionId;
  final String collectionName;
  final bool isGame;

  const FlashcardPage({
    super.key,
    required this.collectionId,
    required this.collectionName,
    required this.isGame,
  });

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  // Background Images
  final List<String> _backgroundImages = [
    'assets/images/bg1.jpg',
    'assets/images/bg2.jpg',
    'assets/images/bg3.jpg',
    'assets/images/bg4.jpg',
    'assets/images/bg5.jpg',
    'assets/images/bg6.jpg',
    'assets/images/bg7.jpg',
    'assets/images/bg8.jpg',
    'assets/images/bg9.jpg',
    'assets/images/bg10.jpg',
  ];
  
  String _currentBackground = 'assets/images/bg1.jpg';
  bool _isImageLoaded = false;

  final FirestoreService _dbService = FirestoreService();
  
  int _currentIndex = 0;
  List<Word> _words = [];
  bool _isLoading = true;
  String? _error;

  Timer? _timer;
  bool _showMeaning = false;

  // Telemetry Tracking
  final ScoringService _scoringService = ScoringService();
  late DateTime _cardShownTime;
  DateTime? _popupOpenTime;
  int _popupDurationMs = 0;
  bool _popupOpened = false;
  int _sessionStep = 0; // Incremented per card view
  late String _sessionId; // Random session ID to group logs

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString(); // Unique session ID
    _cardShownTime = DateTime.now(); // Start tracking first card
    
    if (_backgroundImages.isNotEmpty) {
      _currentBackground = _backgroundImages[Random().nextInt(_backgroundImages.length)];
    }
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    precacheImage(AssetImage(_currentBackground), context).then((_) {
      if (mounted) setState(() => _isImageLoaded = true);
    }).catchError((error) {
      if (mounted) setState(() => _isImageLoaded = true);
    });

    for (var img in _backgroundImages) {
      if (img != _currentBackground) {
        precacheImage(AssetImage(img), context).catchError((_) {});
      }
    }
  }

  /// Selects a random background image different from the current one.
  void _pickRandomBackground() {
    if (_backgroundImages.isNotEmpty) {
      setState(() {
        String newBg;
        if (_backgroundImages.length > 1) {
          do {
            newBg = _backgroundImages[Random().nextInt(_backgroundImages.length)];
          } while (newBg == _currentBackground);
          _currentBackground = newBg;
        } else {
          _currentBackground = _backgroundImages[0];
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Loads words for the collection from the database.
  Future<void> _initializeData() async {
    try {
      _words = await _dbService.getWordsByCollection(widget.collectionId);
      _isLoading = false;
      if (mounted) {
        setState(() {});
        if (_words.isNotEmpty && !widget.isGame) {
           _startTimer();
        }
      }
    } catch (e) {
      _isLoading = false;
      _error = "Error: ${e.toString()}";
      if (mounted) setState(() {});
    }
  }

  /// Starts a 15-second timer to reveal the meaning (Study Mode only).
  void _startTimer() {
    if (widget.isGame) return;

    _timer?.cancel();
    setState(() { _showMeaning = false; });
    _timer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() { _showMeaning = true; });
    });
  }

  /// Logs telemetry data for the current card before switching.
  Future<void> _logCardData(String actionType) async {
    if (_words.isEmpty) return;

    final word = _words[_currentIndex];
    final now = DateTime.now();
    int durationMs = now.difference(_cardShownTime).inMilliseconds;

    // Cap duration at 45 seconds (45000 ms)
    if (durationMs > 45000) {
      durationMs = 45000;
    }

    // Calculate popup duration if it was opened
    if (_popupOpened && _popupOpenTime != null) {
      _popupDurationMs = now.difference(_popupOpenTime!).inMilliseconds;
    }

    // Calculate score
    final score = _scoringService.calculateLearningScore(
      durationMs / 1000.0, 
      _popupOpened
    );


    // Context metrics
    final hoursSinceView = word.lastReviewedAt != null 
        ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(word.lastReviewedAt!)).inHours 
        : null;

    int? userRating;
    
    // ~15% chance to ask for user rating (ground truth)
    // Only if action is 'next' (meaning they likely 'answered' it) and not just browsing back
    if (actionType == 'next' && Random().nextDouble() < 0.15) {
       userRating = await _showRatingDialog();
    }

    final log = TelemetryData(
      wordId: word.id!,
      sessionId: _sessionId,
      timestamp: now.millisecondsSinceEpoch,
      durationMs: durationMs,
      popupOpened: _popupOpened,
      popupDurationMs: _popupDurationMs,
      // actionType: actionType, // Removed from model
      wordLength: word.word.length,
      sessionStepIndex: ++_sessionStep,
      totalViewCount: word.viewCount,
      hoursSinceLastView: hoursSinceView,
      currentAlgoScore: score,
      userRating: userRating,
    );

    // Fire and forget logging (don't block UI)
    final logId = await _dbService.logTelemetry(log);
    
    // If user provided a rating and we have a valid log ID, save it to the Word document
    if (userRating != null && logId != null) {
      _dbService.addRatingToWord(word.id!, userRating, logId);
    }

    _dbService.updateWordStats(word.id!);

    // Reset metrics for next card
    _cardShownTime = DateTime.now();
    _popupOpened = false;
    _popupDurationMs = 0;
  }

  /// Shows a quick rating dialog for ground truth collection.
  Future<int?> _showRatingDialog() async {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("How well do you know this?", style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            int rating = index + 1;
            return GestureDetector(
              onTap: () => Navigator.pop(context, rating),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.2 + (index * 0.1)), // Darker for higher ratings
                  shape: BoxShape.circle,
                ),
                child: Text("$rating", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Advances to the next card in the list.
  void _nextCard() async {
    await _logCardData('next');
    
    setState(() {
      _showMeaning = false;
      
      if (_currentIndex < _words.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
      }
      
      _pickRandomBackground();
      
      if (!widget.isGame) _startTimer();
    });
  }

  /// Returns to the previous card.
  void _prevCard() async {
    await _logCardData('prev');

    if (_currentIndex > 0) {
      setState(() {
        _showMeaning = false;
        _currentIndex--;
        _pickRandomBackground();
        if (!widget.isGame) _startTimer();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    if (!_isImageLoaded || _isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    if (_error != null) return Scaffold(body: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))));

    Widget content = Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1500),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Container(
                key: ValueKey<String>(_currentBackground),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(_currentBackground),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.7)),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Text(
                        widget.collectionName,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                Expanded(
                  child: _words.isEmpty 
                    ? const Center(child: Text("No words found.", style: TextStyle(color: Colors.white)))
                    : Center(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildGlassCard(_words[_currentIndex]),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                ),
              ],
            ),
          ),

          if (_words.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(bottom: 40, top: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: _currentIndex > 0 ? Colors.white24 : Colors.white10,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: _currentIndex > 0 ? _prevCard : null,
                            tooltip: "Previous",
                          ),
                        ),

                        const SizedBox(width: 20),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 10,
                          ),
                          onPressed: _nextCard,
                          icon: const Icon(Icons.arrow_forward, size: 22),
                          label: Text(
                            _currentIndex < _words.length - 1 ? "Next" : "Restart", 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 15),
                    Text(
                      "${_currentIndex + 1} / ${_words.length}", 
                      style: const TextStyle(color: Colors.white70, fontSize: 14)
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (isMobile) {
      return content;
    } else {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 800),
            margin: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(34)),
              child: content,
            ),
          ),
        ),
      );
    }
  }

  /// Builds the glassmorphism card displaying the word.
  Widget _buildGlassCard(Word word) {
    return GestureDetector(
      onTap: () {
        if (!widget.isGame && !_showMeaning) {
          _timer?.cancel();
          // Telemetry: Track popup open
          _popupOpened = true;
          _popupOpenTime = DateTime.now();
          
          setState(() {
            _showMeaning = true;
          });
          
          // Since meaning is now shown until card change, we can approximate duration 
          // as "until next card" (calculated in _logCardData) or we can just say 
          // looking at definition counts as usage time. 
          // For now, let's assume they look at it until they leave the card.
          _popupDurationMs = 0; // Will be calculated on exit
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("WORD", style: TextStyle(fontSize: 12, color: Colors.white70, letterSpacing: 2)),
                const SizedBox(height: 5),
                Text(word.word, textAlign: TextAlign.center, style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                const Divider(color: Colors.white30, thickness: 1),
                const SizedBox(height: 15),
                const Text("DEFINITION", style: TextStyle(fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 5),
                Text(word.definition, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.9))),
                const SizedBox(height: 20),
  
                if (!widget.isGame) ...[
                  AnimatedOpacity(
                    duration: _showMeaning ? const Duration(milliseconds: 500) : Duration.zero,
                    opacity: _showMeaning ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.deepPurpleAccent.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.5))),
                      child: Text(word.meaningTr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _showMeaning ? 0.0 : 1.0,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 6.0),
                      child: Text(
                        "Tap to reveal / Waiting...",
                        style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                ],
  
                const SizedBox(height: 20),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(15)), child: Text("“${word.example}”", textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85), fontStyle: FontStyle.italic))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}