import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:english_flashcards/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_flashcards/services/auth_service.dart';
import 'screens/collections_page.dart';
import 'screens/login_page.dart';

void main() async {
  // Initialize Flutter engine
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Enable OFFLINE persistence
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  // Lock screen orientation to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const VocabularyApp());
}

class VocabularyApp extends StatelessWidget {
  const VocabularyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flash Cards',
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
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const CollectionsPage(); // Direct to Collections
          }
          return const LoginPage();
        },
      ),
    );
  }
}