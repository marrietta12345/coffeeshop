import 'package:flutter/material.dart';
import '../widgets/custom_bottom_nav.dart';
import 'home_page.dart';
import 'explore_page.dart';
import 'you_page.dart';

/// Owns the Map/Explore/Profile tab state and the single shared bottom
/// nav bar. Each tab is a plain content widget (no Scaffold of their
/// own) so switching tabs never loses this navigation shell.
class MainNavPage extends StatefulWidget {
  const MainNavPage({super.key});

  @override
  State<MainNavPage> createState() => _MainNavPageState();
}

class _MainNavPageState extends State<MainNavPage> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: const [
          HomePage(),
          ExplorePage(),
          YouPage(),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _navIndex,
        onTabSelected: (index) => setState(() => _navIndex = index),
      ),
    );
  }
}