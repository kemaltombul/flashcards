import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:english_flashcards/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_flashcards/services/auth_service.dart';
import 'screens/collections_page.dart';
import 'screens/main_page.dart';
import 'screens/login_page.dart';

void main() async {
  // Initialize Flutter engine
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Enable OFFLINE persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Lock screen orientation to portrait
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const VocabularyApp());
}

class VocabularyApp extends StatelessWidget {
  const VocabularyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'True Vocab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Zen Theme Colors
        primaryColor: const Color(0xFF0F0F0F), // Soft Black
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF), // Soft Lavender
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
          background: const Color(0xFF0F0F0F),
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
        ),
      ),
      // Auth Gate
      home: StreamBuilder(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black, // Match native splash exactly
              body: SizedBox.shrink(), // No spinner
            );
          }
          if (snapshot.hasData) {
            return const AppPreparationGate(); // Prepares and then shows MainPage
          }
          return const LoginPage();
        },
      ),
    );
  }
}

/// A gate to smoothly transition from the native splash screen.
/// Precaches *only* the single required background image to avoid
/// the image "popping in" while keeping disk I/O minimal.
class AppPreparationGate extends StatefulWidget {
  const AppPreparationGate({super.key});

  @override
  State<AppPreparationGate> createState() => _AppPreparationGateState();
}

class _AppPreparationGateState extends State<AppPreparationGate> {
  bool _isReady = false;
  late String _initialBgImage;

  @override
  void initState() {
    super.initState();
    _initialBgImage =
        'assets/images/bg${(DateTime.now().millisecond % 10) + 1}.jpg';
    _prepareApp();
  }

  Future<void> _prepareApp() async {
    try {
      // 1. Precache only the specific background being used. (Fast)
      await precacheImage(AssetImage(_initialBgImage), context);
    } catch (_) {}

    // 2. Add an unnoticeable delay to ensure the framework renders the transition
    await Future.delayed(const Duration(milliseconds: 100));

    // 3. Mount MainPage precisely when rendering is guaranteed to be fully painted
    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      // Maintain the illusion that the Android splash screen is still present
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      );
    }

    // Smoothly present the fully rendered MainPage
    return MainPage(initialBgImage: _initialBgImage);
  }
}
