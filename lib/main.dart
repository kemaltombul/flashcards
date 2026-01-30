import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:english_flashcards/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_flashcards/services/auth_service.dart';
import 'screens/main_page.dart';
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
        // Theme colors
        primaryColor: const Color(0xFF121212),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, // Dark mode
        ),
        useMaterial3: true,
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
            return const MainPage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}