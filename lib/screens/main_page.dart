import 'package:flutter/material.dart';
import 'dart:ui';
import 'collections_page.dart';
import 'add_word_page.dart';
import '../constants/app_theme.dart';

class MainPage extends StatefulWidget {
  final String? initialBgImage;
  const MainPage({super.key, this.initialBgImage});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentIndex = 0;
  late String _bgImage;

  final List<Widget> _pages = [const CollectionsPage(), const AddWordPage()];

  @override
  void initState() {
    super.initState();
    _bgImage = widget.initialBgImage ??
        'assets/images/bg${(DateTime.now().millisecond % 12) + 1}.jpg';
  }

  void _onItemTapped(int index) {
    FocusManager.instance.primaryFocus?.unfocus(); // ✅ Alt bar ile geçişte de kapanır
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    FocusManager.instance.primaryFocus?.unfocus(); // ✅ Kaydırarak geçişte kapanır
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final navBarColor = Colors.black.withOpacity(0.3);
    final selectedItemColor = const Color(0xFFD0BCFF);
    final unselectedItemColor = Colors.white54;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Parallax Background
          Positioned(
            left: -50,
            right: -50,
            top: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                double pageOffset = 0.0;
                if (_pageController.hasClients &&
                    _pageController.position.haveDimensions) {
                  pageOffset = _pageController.page ?? 0.0;
                }
                return Transform.translate(
                  offset: Offset(-pageOffset * 40, 0),
                  child: child,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(_bgImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          // Dark Overlay
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),
          // Page Content
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            children: _pages,
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          color: Colors.transparent,
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                indicatorColor: selectedItemColor.withOpacity(0.2),
                labelTextStyle: MaterialStateProperty.all(
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                iconTheme: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return IconThemeData(color: selectedItemColor);
                  }
                  return IconThemeData(color: unselectedItemColor);
                }),
              ),
              child: NavigationBar(
                height: 70,
                backgroundColor: navBarColor,
                selectedIndex: _currentIndex,
                onDestinationSelected: _onItemTapped,
                animationDuration: const Duration(milliseconds: 500),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: 'Collections',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.add_circle_outline_rounded),
                    selectedIcon: Icon(Icons.add_circle_rounded),
                    label: 'Add Word',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}