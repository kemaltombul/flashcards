import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math';

import '../services/firestore_service.dart';
import '../services/scoring_service.dart';
import '../models/word.dart';

class FlashcardPage extends StatefulWidget {
  final String collectionId;
  final String collectionName;

  const FlashcardPage({
    super.key,
    required this.collectionId,
    required this.collectionName,
  });

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
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
    'assets/images/bg11.jpg',
    'assets/images/bg12.jpg',
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

  final ScoringService _scoringService = ScoringService();
  late DateTime _cardShownTime;
  DateTime? _popupOpenTime;
  int _popupDurationMs = 0;
  bool _popupOpened = false;
  int _sessionStep = 0;
  late String _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _cardShownTime = DateTime.now();

    if (_backgroundImages.isNotEmpty) {
      _currentBackground =
          _backgroundImages[Random().nextInt(_backgroundImages.length)];
    }
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    precacheImage(AssetImage(_currentBackground), context)
        .then((_) {
          if (mounted) setState(() => _isImageLoaded = true);
        })
        .catchError((error) {
          if (mounted) setState(() => _isImageLoaded = true);
        });

    for (var img in _backgroundImages) {
      if (img != _currentBackground) {
        precacheImage(AssetImage(img), context).catchError((_) {});
      }
    }
  }

  void _pickRandomBackground() {
    if (_backgroundImages.isNotEmpty) {
      setState(() {
        String newBg;
        if (_backgroundImages.length > 1) {
          do {
            newBg =
                _backgroundImages[Random().nextInt(_backgroundImages.length)];
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

  Future<void> _initializeData() async {
    try {
      _words = await _dbService.getWordsByCollection(widget.collectionId);
      _words.shuffle(); // Kelimeleri karıştır
      _isLoading = false;

      if (mounted) {
        setState(() {});
        if (_words.isNotEmpty) {
          _startTimer();
          _dbService.updateUserStreak();
        }
      }
    } catch (e) {
      _isLoading = false;
      _error = "Error: ${e.toString()}";
      if (mounted) setState(() {});
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _showMeaning = false;
    });
    _timer = Timer(const Duration(seconds: 15), () {
      if (mounted)
        setState(() {
          _showMeaning = true;
        });
    });
  }

  Future<void> _logCardData(String actionType, {int? userRating}) async {
    if (_words.isEmpty) return;

    final word = _words[_currentIndex];
    final now = DateTime.now();
    int durationMs = now.difference(_cardShownTime).inMilliseconds;
    if (durationMs > 45000) durationMs = 45000;

    if (_popupOpened && _popupOpenTime != null) {
      _popupDurationMs = now.difference(_popupOpenTime!).inMilliseconds;
    }

    if (userRating != null) {
      _dbService.addRatingToWord(word.id!, word.collectionId, userRating);
    }

    _dbService.updateWordStats(
      word.id!,
      word.collectionId,
      durationMs: durationMs,
    );

    // Reset metrics
    _cardShownTime = DateTime.now();
    _popupOpened = false;
    _popupDurationMs = 0;
  }

  Future<int?> _showRatingDialog() async {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      const Expanded(
                        child: Text(
                          "How well do you know this?",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white60,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      int rating = index + 1;
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, rating),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.deepPurpleAccent.withValues(
                              alpha: 0.15 + (index * 0.1),
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            "$rating",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Struggling",
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      Text(
                        "Mastered",
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _nextCard() async {
    int? userRating;

    if (Random().nextDouble() < 0.15) {
      userRating = await _showRatingDialog();
      if (!mounted) return;
    }

    await _logCardData('next', userRating: userRating);

    setState(() {
      _showMeaning = false;
      _currentIndex = _currentIndex < _words.length - 1 ? _currentIndex + 1 : 0;
      _pickRandomBackground();
      _startTimer();
    });
  }

  Future<void> _prevCard() async {
    if (_currentIndex <= 0) return;

    await _logCardData('prev');

    setState(() {
      _showMeaning = false;
      _currentIndex--;
      _pickRandomBackground();
      _startTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    if (!_isImageLoaded || _isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
        ),
      );
    }

    if (_error != null)
      return Scaffold(
        body: Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Text(
                        widget.collectionName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                Expanded(
                  child: _words.isEmpty
                      ? const Center(
                          child: Text(
                            "No words found.",
                            style: TextStyle(color: Colors.white),
                          ),
                        )
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
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
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
                            color: _currentIndex > 0
                                ? Colors.white24
                                : Colors.white10,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: _currentIndex > 0 ? _prevCard : null,
                            tooltip: "Previous",
                          ),
                        ),

                        const SizedBox(width: 20),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 10,
                          ),
                          onPressed: _nextCard,
                          icon: const Icon(Icons.arrow_forward, size: 22),
                          label: Text(
                            _currentIndex < _words.length - 1
                                ? "Next"
                                : "Restart",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),
                    Text(
                      "${_currentIndex + 1} / ${_words.length}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
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

  Widget _buildGlassCard(Word word) {
    return GestureDetector(
      onTap: () {
        if (!_showMeaning) {
          _timer?.cancel();
          _popupOpened = true;
          _popupOpenTime = DateTime.now();
          setState(() => _showMeaning = true);
          _popupDurationMs = 0;
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 320,
            height: 480,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (word.partOfSpeech != PartOfSpeech.unknown) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber, // Daha dikkat çekici, parlak sarı
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      word.partOfSpeech.label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ] else
                  const SizedBox(height: 32),
                const SizedBox(height: 5),
                Text(
                  word.word,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 15),
                const Divider(color: Colors.white30, thickness: 1),
                const SizedBox(height: 15),
                const Text(
                  "DEFINITION",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(height: 5),
                Text(
                  word.definition,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: _showMeaning ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurpleAccent.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            word.translation,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _showMeaning ? 0.0 : 1.0,
                        child: const Text(
                          "Tap to reveal / Waiting...",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    "“${word.contextualInfo}”",
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
