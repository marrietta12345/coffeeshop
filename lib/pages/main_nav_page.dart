import 'package:flutter/material.dart';
import '../utils/map_area_focus.dart';
import '../utils/tambay_check_service.dart';
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
  void initState() {
    super.initState();
    MapAreaFocus.current.addListener(_showMapForArea);
    TambayCheckService.start(); // live "how busy is it" reports
  }

  @override
  void dispose() {
    MapAreaFocus.current.removeListener(_showMapForArea);
    super.dispose();
  }

  /// A place picked in Explore search opens the Map tab on that place.
  void _showMapForArea() {
    if (MapAreaFocus.current.value != null && _navIndex != 0) setState(() => _navIndex = 0);
  }

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