import 'package:flutter/material.dart';

import 'deepfake/deepfake_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'reports/reports_list_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens = const [
    HomeScreen(),
    ReportsListScreen(),
    DeepfakeScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.report_gmailerrorred_outlined), selectedIcon: Icon(Icons.report_gmailerrorred), label: 'البلاغات'),
            NavigationDestination(icon: Icon(Icons.image_search_outlined), selectedIcon: Icon(Icons.image_search), label: 'Deepfake'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
          ],
        ),
      ),
    );
  }
}
