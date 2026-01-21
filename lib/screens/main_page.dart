import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'add_word_page.dart';
import 'search_page.dart';
import 'collections_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final PageController _pageController = PageController(initialPage: 1); // Start at Center (Add Word)
  int _currentIndex = 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onBottomNavTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if Mobile or Web
    bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    Widget content = Scaffold(
      backgroundColor: Colors.black,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: const [
          SearchPage(),
          AddWordPage(),
          CollectionsPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: Colors.deepPurpleAccent.withOpacity(0.2),
            labelTextStyle: MaterialStateProperty.all(
              const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            iconTheme: MaterialStateProperty.resolveWith((states) {
               if (states.contains(MaterialState.selected)) {
                 return const IconThemeData(color: Colors.deepPurpleAccent);
               }
               return const IconThemeData(color: Colors.grey);
            }),
          ),
          child: NavigationBar(
            height: 70,
            backgroundColor: const Color(0xFF141414),
            selectedIndex: _currentIndex,
            onDestinationSelected: _onBottomNavTapped,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: 'Add Word',
              ),
              NavigationDestination(
                icon: Icon(Icons.collections_bookmark_outlined),
                selectedIcon: Icon(Icons.collections_bookmark),
                label: 'Collections',
              ),
            ],
          ),
        ),
      ),
    );

    if (isMobile) {
      return content;
    } else {
      return Scaffold(
        backgroundColor: const Color(0xFF121212), // Background outside the phone frame
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 850),
            margin: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0xFF333333), width: 8), // Phone bezel
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, spreadRadius: 5),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: content,
            ),
          ),
        ),
      );
    }
  }
}
